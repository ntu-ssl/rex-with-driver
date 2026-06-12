// SPDX-License-Identifier: GPL-2.0

//! Rex virtual network driver.
//!
//! Registers a virtual Ethernet interface (`rexnet0`) whose transmit path is
//! forwarded to `rex_net_dispatch()` — a `#[no_mangle] #[inline(never)]
//! extern "C"` Rust function — so a loaded Rex eBPF extension can intercept
//! every outgoing packet via a kprobe and decide its fate with
//! `bpf_override_return()`.
//!
//! This mirrors `samples/fwd_driver` (file-operation forwarding) but for the
//! network datapath: instead of read/write/open/release, the hookable unit is
//! a single packet transmit.
//!
//! # Layout
//!
//! The `ndo_*` callbacks stored in `net_device_ops` are invoked *indirectly* by
//! the networking core through C function pointers, which the kernel verifies
//! with kCFI. Those entry points therefore live in `rex_net_glue.c` (compiled
//! by clang, so they carry the correct kCFI type-ids); see that file for the
//! rationale. This Rust file owns everything else: device registration, the
//! transmit logic (`rex_net_xmit_rs`, called *directly* by the C trampoline),
//! the Rex hook point, and the driver-side counters.
//!
//! # Dispatch protocol
//!
//! ```text
//! rex_net_dispatch(op: u64, len: u64, proto: u64) -> i64
//!   rdi = op     1 = xmit
//!   rsi = len    packet length in bytes (skb->len)
//!   rdx = proto  EtherType, host byte order (ntohs(skb->protocol))
//! ```
//!
//! Return value, as interpreted by `rex_net_xmit_rs`:
//!
//! ```text
//!   DISPATCH_UNHANDLED (-38)  no extension loaded -> transmit (counted PASS)
//!   r >= 0                    Rex says PASS        -> transmit (counted PASS)
//!   r <  0 (and != -38)       Rex says DROP        -> packet dropped (counted DROP)
//! ```
//!
//! # Build / usage
//!
//! ```sh
//! make -C <linux-src> M=$(pwd) modules LLVM=1
//! insmod rex_net.ko
//! ip addr add 10.0.99.1/24 dev rexnet0
//! ip link set rexnet0 up
//! # (load the Rex extension with ./loader)
//! ping -c4 10.0.99.2     # ARP/ICMP leaves via rexnet0 -> rex_net_dispatch
//! rmmod rex_net          # prints "rex_net: tx_pass=.. tx_drop=.."
//! ```

use core::ffi::c_int;
use core::sync::atomic::{AtomicU64, Ordering};

use kernel::prelude::*;
use kernel::{bindings, c_str};

module! {
    type: RexNetModule,
    name: "rex_net",
    authors: ["SSLab"],
    description: "Rex virtual network driver",
    license: "GPL",
}

// ── op codes (must match samples/net_driver/src/main.rs) ───────────────────────
const OP_XMIT: u64 = 1;

/// Sentinel returned by `rex_net_dispatch` when no Rex extension is loaded.
/// Equals `-ENOSYS` (-38).
const DISPATCH_UNHANDLED: i64 = -38;

/// `NETDEV_TX_OK` — the skb was consumed by the driver.
const NETDEV_TX_OK: c_int = 0;

// Driver-side packet counters, updated from the transmit path.
static TX_PASS: AtomicU64 = AtomicU64::new(0);
static TX_DROP: AtomicU64 = AtomicU64::new(0);

// Provided by rex_net_glue.c; passed to alloc_netdev_mqs as the setup callback.
extern "C" {
    fn rex_net_setup(dev: *mut bindings::net_device);
}

// ── dispatch hook point ───────────────────────────────────────────────────────
//
// A Rex eBPF extension attaches a kprobe to `rex_net_dispatch` and decides the
// outcome of every transmitted packet via `bpf_override_return()`. The function
// must:
//   * have a stable, unmangled symbol so the kprobe resolves it by name
//     (`#[no_mangle]`),
//   * never be inlined, so a real call site and entry point exist
//     (`#[inline(never)]`),
//   * use the C ABI so `op`/`len`/`proto` arrive in `rdi`/`rsi`/`rdx`
//     (`extern "C"`),
//   * be opaque to the optimizer (`black_box`), so the caller always reads the
//     possibly-overridden return value in `rax` instead of const-propagating
//     the default `-ENOSYS`.
//
// It is called *directly* from `rex_net_xmit_rs`, so it is not kCFI-checked.
#[no_mangle]
#[inline(never)]
pub extern "C" fn rex_net_dispatch(op: u64, len: u64, proto: u64) -> i64 {
    core::hint::black_box((op, len, proto));
    core::hint::black_box(DISPATCH_UNHANDLED)
}

#[inline(always)]
fn dispatch(op: u64, len: u64, proto: u64) -> i64 {
    rex_net_dispatch(op, len, proto)
}

// ── transmit logic ────────────────────────────────────────────────────────────

/// Called *directly* by the `ndo_start_xmit` trampoline in rex_net_glue.c.
/// Forwards the packet's length and protocol to `rex_net_dispatch`, counts the
/// verdict, consumes the skb, and returns `NETDEV_TX_OK`.
///
/// # Safety
///
/// `skb` is the packet being transmitted and is owned by this function (it must
/// be freed exactly once here); `_dev` is the valid transmitting device. Both
/// invariants are guaranteed by the `ndo_start_xmit` contract.
#[no_mangle]
pub unsafe extern "C" fn rex_net_xmit_rs(
    skb: *mut bindings::sk_buff,
    _dev: *mut bindings::net_device,
) -> c_int {
    // SAFETY: `skb` is a valid packet owned by this call.
    let len = unsafe { (*skb).len } as u64;
    // skb->protocol is __be16 (big-endian on the wire) and lives inside an
    // anonymous union, so read it through a helper; convert to host order so the
    // Rex extension can match EtherTypes in their natural form.
    let proto = u16::from_be(unsafe { bindings::skb_protocol(skb) }) as u64;

    let verdict = dispatch(OP_XMIT, len, proto);

    if verdict < 0 && verdict != DISPATCH_UNHANDLED {
        TX_DROP.fetch_add(1, Ordering::Relaxed);
    } else {
        TX_PASS.fetch_add(1, Ordering::Relaxed);
    }

    // Virtual device: there is no wire, so we consume the skb either way.
    // SAFETY: we own `skb` and are done with it.
    unsafe {
        bindings::consume_skb(skb);
    }

    NETDEV_TX_OK
}

// ── module init / exit ────────────────────────────────────────────────────────

/// Owns the registered `net_device` for the module's lifetime.
struct RexNetModule {
    dev: *mut bindings::net_device,
}

// SAFETY: the module owns the device exclusively; the raw pointer is only used
// from init/exit (single-threaded module load/unload).
unsafe impl Send for RexNetModule {}
unsafe impl Sync for RexNetModule {}

impl kernel::Module for RexNetModule {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("rex_net: loading — interface rexnet0\n");

        // alloc_netdev_mqs(sizeof_priv, name, name_assign_type, setup, txqs, rxqs)
        // is what the alloc_etherdev() macro expands to. We keep no private
        // area, so sizeof_priv = 0. `rex_net_setup` (C) installs the ops and a
        // random MAC.
        // SAFETY: valid name template and a valid setup callback; the call
        // allocates and partially initialises the device.
        let dev = unsafe {
            bindings::alloc_netdev_mqs(
                0,
                c_str!("rexnet%d").as_char_ptr(),
                bindings::NET_NAME_UNKNOWN as u8,
                Some(rex_net_setup),
                1,
                1,
            )
        };
        if dev.is_null() {
            pr_err!("rex_net: alloc_netdev failed\n");
            return Err(ENOMEM);
        }

        // SAFETY: `dev` is a valid, set-up net_device ready for registration.
        let ret = unsafe { bindings::register_netdev(dev) };
        if ret != 0 {
            // SAFETY: registration failed, so we still own `dev` and must free it.
            unsafe { bindings::free_netdev(dev) };
            pr_err!("rex_net: register_netdev failed: {}\n", ret);
            return Err(Error::from_errno(ret));
        }

        pr_info!("rex_net: registered rexnet0\n");
        Ok(RexNetModule { dev })
    }
}

impl Drop for RexNetModule {
    fn drop(&mut self) {
        let pass = TX_PASS.load(Ordering::Relaxed);
        let drop = TX_DROP.load(Ordering::Relaxed);
        pr_info!("rex_net: unloading — tx_pass={} tx_drop={}\n", pass, drop);
        // SAFETY: `self.dev` was returned by a successful register_netdev and
        // has not been freed; unregister then free exactly once.
        unsafe {
            bindings::unregister_netdev(self.dev);
            bindings::free_netdev(self.dev);
        }
    }
}
