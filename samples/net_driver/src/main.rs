#![no_std]
#![no_main]

extern crate rex;

use core::hint::black_box;

use rex::kprobe::kprobe;
use rex::map::RexArrayMap;
use rex::pt_regs::PtRegs;
use rex::{rex_kprobe, rex_map, rex_printk, Result};

// ── op codes (must match driver/rex_net_main.rs) ──────────────────────────────
const OP_XMIT: u64 = 1;

// ── EtherTypes (host byte order, as the driver passes them) ───────────────────
const ETH_P_IP: u64 = 0x0800;
const ETH_P_ARP: u64 = 0x0806;

// ── verdicts written back via bpf_override_return ─────────────────────────────
// The driver treats a negative value (other than -ENOSYS) as DROP and a
// non-negative value as PASS.
const VERDICT_PASS: u64 = 0;
const VERDICT_DROP: u64 = (-1i64) as u64;

/// A packet whose total length equals this value triggers a deliberate
/// out-of-bounds access below, to exercise Rex's in-kernel exception handling
/// on the network datapath (the kernel must survive and keep forwarding).
/// Reachable with `ping -s 958` (14 eth + 20 IP + 8 ICMP + 958 = 1000).
const PANIC_TRIGGER_LEN: u64 = 1000;

// ── stats map ─────────────────────────────────────────────────────────────────
// One RexArrayMap<u64> used as a fixed set of counters. Userspace reads these
// by index after the run.
const STAT_TOTAL: u32 = 0; // packets seen
const STAT_BYTES: u32 = 1; // total bytes seen
const STAT_PASSED: u32 = 2; // packets allowed through
const STAT_DROPPED: u32 = 3; // packets dropped by the filter
const STAT_ARP: u32 = 4; // ARP packets seen
const STAT_IPV4: u32 = 5; // IPv4 packets seen
const CFG_QUIET: u32 = 6; // nonzero -> skip per-packet rex_printk (benchmark mode)
const STAT_SLOTS: u32 = 8;

#[rex_map]
static STATS: RexArrayMap<u64> = RexArrayMap::new(STAT_SLOTS, 0);

#[inline(always)]
fn bump(idx: u32, by: u64) {
    if let Some(slot) = STATS.get_mut(&idx) {
        *slot += by;
    }
}

// ── hook: rex_net_dispatch kprobe ─────────────────────────────────────────────
//
// Fired on every packet the rex_net driver transmits.
//
// x86-64 System V calling convention at kprobe entry:
//   rdi = op     (OP_XMIT)
//   rsi = len    (skb->len, bytes)
//   rdx = proto  (EtherType in host byte order)
//
// Policy demonstrated:
//   * monitor : count every packet, its bytes, and a per-protocol tally
//   * control : DROP ARP packets, PASS everything else, via bpf_override_return
//   * safety  : a packet of length PANIC_TRIGGER_LEN drives a Rust bounds-check
//               panic that Rex catches, proving the datapath is recoverable
#[rex_kprobe(function = "rex_net_dispatch")]
fn net_filter(obj: &kprobe, regs: &mut PtRegs) -> Result {
    let op = regs.rdi();
    if op != OP_XMIT {
        return Ok(0);
    }
    let len = regs.rsi();
    let proto = regs.rdx();

    bump(STAT_TOTAL, 1);
    bump(STAT_BYTES, len);
    match proto {
        ETH_P_ARP => bump(STAT_ARP, 1),
        ETH_P_IP => bump(STAT_IPV4, 1),
        _ => {}
    }

    // ── safety demonstration ──────────────────────────────────────────────
    // A specially sized packet triggers an out-of-bounds index. The bounds
    // check panics; Rex's handler unwinds this program safely and the kernel
    // keeps running (the packet falls through to the driver's default PASS).
    if len == PANIC_TRIGGER_LEN {
        let table: [u64; 4] = [10, 20, 30, 40];
        let val = table[black_box(len as usize)];
        bump(STAT_BYTES, black_box(val)); // never reached
        return Ok(0);
    }

    // Benchmark mode: the loader sets CFG_QUIET to suppress the per-packet
    // trace log, so measurements capture monitor+control cost, not formatting.
    let quiet = STATS.get_mut(&CFG_QUIET).is_some_and(|v| *v != 0);

    // ── control: per-protocol filtering ───────────────────────────────────
    if proto == ETH_P_ARP {
        bump(STAT_DROPPED, 1);
        obj.bpf_override_return(regs, VERDICT_DROP);
        if !quiet {
            rex_printk!("[rex_net] DROP arp  len={}\n", len)?;
        }
    } else {
        bump(STAT_PASSED, 1);
        obj.bpf_override_return(regs, VERDICT_PASS);
        if !quiet {
            rex_printk!("[rex_net] PASS proto={:#x} len={}\n", proto, len)?;
        }
    }

    Ok(0)
}
