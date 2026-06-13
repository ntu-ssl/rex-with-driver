// SPDX-License-Identifier: GPL-2.0

//! Rex virtual network driver.
//!
//! Registers a cross-connected pair of virtual Ethernet interfaces
//! (`rexnet0` ⟷ `rexnet1`, veth-style): a packet transmitted on one side is
//! delivered to the peer's receive path, so real protocols (ARP, TCP, HTTP…)
//! work across the pair. Every transmit is first forwarded to
//! `rex_net_dispatch()` — a `#[no_mangle] #[inline(never)] extern "C"` Rust
//! function — so a loaded Rex eBPF extension can intercept every outgoing
//! packet via a kprobe and decide its fate with `bpf_override_return()`.
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
//!   DISPATCH_UNHANDLED (-38)  no extension loaded -> forward to peer (counted PASS)
//!   r >= 0                    Rex says PASS        -> forward to peer (counted PASS)
//!   r <  0 (and != -38)       Rex says DROP        -> packet dropped (counted DROP)
//! ```
//!
//! # Build / usage
//!
//! ```sh
//! make -C <linux-src> M=$(pwd) modules LLVM=1
//! insmod rex_net.ko
//! ip netns add peer
//! ip link set rexnet1 netns peer
//! ip addr add 10.0.99.1/24 dev rexnet0 && ip link set rexnet0 up
//! ip netns exec peer ip addr add 10.0.99.2/24 dev rexnet1
//! ip netns exec peer ip link set rexnet1 up
//! # (load the Rex extension with ./loader)
//! ping -c4 10.0.99.2     # real ARP/ICMP across the pair, via rex_net_dispatch
//! rmmod rex_net          # prints "rex_net: tx_pass=.. tx_drop=.."
//! ```

use core::ffi::c_int;
use core::ptr;
use core::sync::atomic::{AtomicPtr, AtomicU64, Ordering};

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

// The two cross-connected devices, readable from the transmit path. Cleared
// (in exit) before unregister_netdev so xmit never forwards into a peer that
// is being torn down.
static DEVS: [AtomicPtr<bindings::net_device>; 2] =
    [AtomicPtr::new(ptr::null_mut()), AtomicPtr::new(ptr::null_mut())];

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
/// verdict, and on PASS hands the skb to the peer device's receive path
/// (veth-style, via `dev_forward_skb`). Always returns `NETDEV_TX_OK`.
///
/// # Safety
///
/// `skb` is the packet being transmitted and is owned by this function (it must
/// be freed exactly once here); `dev` is the valid transmitting device. Both
/// invariants are guaranteed by the `ndo_start_xmit` contract.
#[no_mangle]
pub unsafe extern "C" fn rex_net_xmit_rs(
    skb: *mut bindings::sk_buff,
    dev: *mut bindings::net_device,
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
        // Dropped by policy. (Plain `kfree_skb` is a static inline the
        // bindings don't expose; consume_skb frees identically, it only
        // differs in drop-tracing.)
        // SAFETY: we own `skb` and are done with it.
        unsafe { bindings::consume_skb(skb) };
        return NETDEV_TX_OK;
    }

    TX_PASS.fetch_add(1, Ordering::Relaxed);

    let d0 = DEVS[0].load(Ordering::Acquire);
    let peer = if dev == d0 { DEVS[1].load(Ordering::Acquire) } else { d0 };

    if peer.is_null() {
        // Module is tearing down (or single-device fallback): no wire.
        // SAFETY: we own `skb` and are done with it.
        unsafe { bindings::consume_skb(skb) };
    } else {
        // SAFETY: `peer` is a registered device (cleared from DEVS before
        // unregistration) and `dev_forward_skb` takes ownership of `skb` on
        // every path — it delivers to `peer`'s RX or frees it (peer down,
        // MTU exceeded, …).
        unsafe { bindings::dev_forward_skb(peer, skb) };
    }

    NETDEV_TX_OK
}

// ── module init / exit ────────────────────────────────────────────────────────

/// Registers one `rexnet%d` device; returns it still owned by the caller's
/// module (freed only via `unregister_netdev` + `free_netdev`).
fn register_one() -> Result<*mut bindings::net_device> {
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
    Ok(dev)
}

/// Owns the registered, cross-connected `net_device` pair for the module's
/// lifetime.
struct RexNetModule {
    devs: [*mut bindings::net_device; 2],
}

// SAFETY: the module owns the devices exclusively; the raw pointers are only
// used from init/exit (single-threaded module load/unload).
unsafe impl Send for RexNetModule {}
unsafe impl Sync for RexNetModule {}

impl kernel::Module for RexNetModule {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("rex_net: loading — cross-connected pair rexnet0 ⟷ rexnet1\n");

        let dev0 = register_one()?;
        let dev1 = match register_one() {
            Ok(d) => d,
            Err(e) => {
                // SAFETY: `dev0` is registered and not yet published in DEVS.
                unsafe {
                    bindings::unregister_netdev(dev0);
                    bindings::free_netdev(dev0);
                }
                return Err(e);
            }
        };

        // Publish for the transmit path only once both ends exist.
        DEVS[0].store(dev0, Ordering::Release);
        DEVS[1].store(dev1, Ordering::Release);

        pr_info!("rex_net: registered rexnet0 ⟷ rexnet1\n");
        Ok(RexNetModule { devs: [dev0, dev1] })
    }
}

impl Drop for RexNetModule {
    fn drop(&mut self) {
        let pass = TX_PASS.load(Ordering::Relaxed);
        let drop = TX_DROP.load(Ordering::Relaxed);
        pr_info!("rex_net: unloading — tx_pass={} tx_drop={}\n", pass, drop);

        // Stop the transmit path from forwarding into a device that is about
        // to disappear; in-flight xmits then consume their skb instead.
        DEVS[0].store(ptr::null_mut(), Ordering::Release);
        DEVS[1].store(ptr::null_mut(), Ordering::Release);

        for dev in self.devs {
            // SAFETY: each `dev` came from a successful register_netdev and
            // has not been freed; unregister (which synchronizes with and
            // stops the datapath) then free exactly once.
            unsafe {
                bindings::unregister_netdev(dev);
                bindings::free_netdev(dev);
            }
        }
    }
}
