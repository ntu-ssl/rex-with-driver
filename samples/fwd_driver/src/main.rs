#![no_std]
#![no_main]

extern crate rex;

use rex::kprobe::kprobe;
use rex::map::{RexArrayMap, RexHashMap};
use rex::pt_regs::PtRegs;
use rex::{rex_kprobe, rex_map, rex_printk, Result};

// ── op codes ──────────────────────────────────────────────────────────────────
// Must stay in sync with driver/rex_fwd.rs.
const OP_READ: u64 = 1;
const OP_WRITE: u64 = 2;
const OP_OPEN: u64 = 3;
const OP_RELEASE: u64 = 4;

// ── shared data structures ────────────────────────────────────────────────────

/// One forwarded file-operation event written into EVENTS[seq % 64].
/// All fields are plain integers so no unsafe is needed to read/write the map.
///
/// kind: 1=read  2=write  3=open  4=release
#[repr(C)]
#[derive(Copy, Clone)]
pub struct FwdEvent {
    pub op: u32,
    pub pid: u32,
    pub timestamp_ns: u64,
    /// Byte count for read/write; 0 for open/release.
    pub count: u64,
    /// File offset for read/write; 0 for open/release.
    pub offset: u64,
    /// Value injected via bpf_override_return; 0 for open/release.
    pub retval: i64,
}

// ── maps ──────────────────────────────────────────────────────────────────────

/// PIDs that currently have /dev/rex_fwd open (value always 1).
#[rex_map]
static OPEN_PIDS: RexHashMap<u32, u8> = RexHashMap::new(1024, 0);

/// Circular buffer of the last 64 forwarded events.
#[rex_map]
static EVENTS: RexArrayMap<FwdEvent> = RexArrayMap::new(64, 0);

/// Monotonically increasing event counter stored at index 0.
/// Userspace can read this to detect new events without polling every slot.
#[rex_map]
static EVENT_SEQ: RexArrayMap<u64> = RexArrayMap::new(1, 0);

// ── helper ────────────────────────────────────────────────────────────────────

fn record_event(ev: &FwdEvent) {
    let idx: u32 = 0;
    let seq = match EVENT_SEQ.get_mut(&idx) {
        Some(s) => {
            let cur = *s;
            *s = cur + 1;
            cur
        }
        None => return,
    };
    let slot = (seq % 64) as u32;
    let _ = EVENTS.insert(&slot, ev);
}

// ── hook: rex_fwd_dispatch kprobe ─────────────────────────────────────────────
//
// Fired on every call to rex_fwd_dispatch() in the driver module.
//
// x86-64 System V calling convention at kprobe entry:
//   rdi = op     (OP_* constant)
//   rsi = count  (byte count for read/write; 0 for open/release)
//   rdx = offset (file offset for read/write; 0 for open/release)
//
// For read/write we call bpf_override_return() so the driver gets the value
// we decide rather than the default -ENOSYS stub return.  For open we also
// override with 0 (success).  Release return value is ignored by the driver.

#[rex_kprobe(function = "rex_fwd_dispatch")]
fn fwd_dispatch(obj: &kprobe, regs: &mut PtRegs) -> Result {
    let op = regs.rdi();
    let count = regs.rsi();
    let offset = regs.rdx();

    let task = match obj.bpf_get_current_task() {
        Some(t) => t,
        None => return Ok(0),
    };
    let pid = task.get_pid() as u32;
    let now = obj.bpf_ktime_get_ns();

    let retval: i64 = match op {
        OP_OPEN => {
            let _ = OPEN_PIDS.insert(&pid, &1u8);
            // Override so driver sees 0 (success) instead of -ENOSYS.
            obj.bpf_override_return(regs, 0u64);
            rex_printk!("[rex_fwd] open  pid={}\n", pid)?;
            0
        }
        OP_RELEASE => {
            let _ = OPEN_PIDS.delete(&pid);
            rex_printk!("[rex_fwd] close pid={}\n", pid)?;
            // Driver ignores release return; no override needed.
            0
        }
        OP_READ => {
            // Only handle reads from processes that have the device open.
            if OPEN_PIDS.get_mut(&pid).is_none() {
                return Ok(0);
            }
            rex_printk!(
                "[rex_fwd] read  pid={} count={} off={}\n",
                pid,
                count,
                offset
            )?;
            // This demo has no data to return; override with 0 bytes read.
            // A real extension would copy data into the user buffer via
            // bpf_probe_write_user and then override with the byte count.
            obj.bpf_override_return(regs, 0u64);
            0
        }
        OP_WRITE => {
            if OPEN_PIDS.get_mut(&pid).is_none() {
                return Ok(0);
            }
            rex_printk!(
                "[rex_fwd] write pid={} count={} off={}\n",
                pid,
                count,
                offset
            )?;
            // Claim all bytes consumed so the caller does not retry.
            obj.bpf_override_return(regs, count);
            count as i64
        }
        _ => return Ok(0),
    };

    record_event(&FwdEvent {
        op: op as u32,
        pid,
        timestamp_ns: now,
        count,
        offset,
        retval,
    });

    Ok(0)
}
