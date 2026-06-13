// SPDX-License-Identifier: GPL-2.0

//! Rex file-operation forwarding driver.
//!
//! Exposes `/dev/rex_fwd` as a misc device.  Every file operation is
//! forwarded to `rex_fwd_dispatch()` — a `#[no_mangle] #[inline(never)]`
//! Rust function — so a loaded Rex eBPF extension can intercept it via kprobe
//! and control the outcome with `bpf_override_return()`.
//!
//! # Dispatch protocol
//!
//! ```text
//! rex_fwd_dispatch(op: u64, count: u64, offset: u64) -> i64
//!   rdi = op     1=read  2=write  3=open  4=release
//!   rsi = count  byte count (read/write); 0 otherwise
//!   rdx = offset file offset (read/write); 0 otherwise
//! ```
//!
//! Default return is `-ENOSYS` (`-38`), meaning "no Rex extension loaded".
//! The driver treats that as a safe fallback (open/read/write succeed with
//! zero bytes; release is a no-op).
//!
//! # Build
//!
//! ```sh
//! make -C <linux-src> M=$(pwd) modules LLVM=1
//! ```
//!
//! # Usage
//!
//! ```sh
//! insmod rex_fwd.ko
//! # (load the Rex extension with loader)
//! cat /dev/rex_fwd   # triggers a read dispatch
//! rmmod rex_fwd
//! ```

use kernel::{
    c_str,
    fs::{File, Kiocb},
    iov::{IovIterDest, IovIterSource},
    miscdevice::{MiscDevice, MiscDeviceOptions, MiscDeviceRegistration},
    prelude::*,
};

module! {
    type: RexFwdModule,
    name: "rex_fwd",
    authors: ["SSLab"],
    description: "Rex file-operation forwarding driver",
    license: "GPL",
}

// ── op codes ──────────────────────────────────────────────────────────────────
// Must stay in sync with samples/fwd-driver/src/main.rs.
const OP_READ: u64 = 1;
const OP_WRITE: u64 = 2;
const OP_OPEN: u64 = 3;
const OP_RELEASE: u64 = 4;

/// Sentinel returned by `rex_fwd_dispatch` when no Rex extension has been
/// loaded. Equals `-ENOSYS` (-38).
const DISPATCH_UNHANDLED: i64 = -38;

// ── dispatch hook point ───────────────────────────────────────────────────────
//
// A Rex eBPF extension attaches a kprobe to `rex_fwd_dispatch` and decides the
// outcome of every file operation via `bpf_override_return()`. kprobe-based
// override does NOT require ftrace/`__fentry__`: it works by rewriting the
// return value in `rax` at the function entry and is honored on a plain int3
// kprobe (the pre_handler changes `regs->ip` and returns non-zero). So the hook
// point can be a normal Rust function, as long as it:
//
//   * has a stable, unmangled symbol so the kprobe resolves it by name
//     (`#[no_mangle]`),
//   * is never inlined, so a real `call` site and entry point exist
//     (`#[inline(never)]`),
//   * uses the C ABI so `op`/`count`/`offset` arrive in `rdi`/`rsi`/`rdx`,
//     which is where the Rex program reads them (`extern "C"`),
//   * is opaque to the optimizer (`black_box`), so callers always read the
//     possibly-overridden return value in `rax` instead of const-propagating
//     the default `-ENOSYS`.
//
// When no extension is loaded it returns `DISPATCH_UNHANDLED` (`-ENOSYS`).
#[no_mangle]
#[inline(never)]
pub extern "C" fn rex_fwd_dispatch(op: u64, count: u64, offset: u64) -> i64 {
    // Keep the args observably live (in rdi/rsi/rdx at entry) and make the
    // return value opaque so the override is never optimized away.
    core::hint::black_box((op, count, offset));
    core::hint::black_box(DISPATCH_UNHANDLED)
}

#[inline(always)]
fn dispatch(op: u64, count: u64, offset: u64) -> i64 {
    rex_fwd_dispatch(op, count, offset)
}

// ── file operations ───────────────────────────────────────────────────────────

struct RexFwdDev;

#[vtable]
impl MiscDevice for RexFwdDev {
    // No per-open state: storing `()` in the file's private_data is free
    // (its `into_foreign` returns a dangling sentinel; nothing is allocated).
    type Ptr = ();

    fn open(_file: &File, _misc: &MiscDeviceRegistration<Self>) -> Result<()> {
        let ret = dispatch(OP_OPEN, 0, 0);
        // A negative return other than -ENOSYS means the extension rejected
        // the open (e.g., -EACCES = -13 to deny access).
        if ret < 0 && ret != DISPATCH_UNHANDLED {
            return Err(Error::from_errno(-ret as i32));
        }
        Ok(())
    }

    fn release(_device: (), _file: &File) {
        dispatch(OP_RELEASE, 0, 0);
    }

    fn read_iter(mut kiocb: Kiocb<'_, Self::Ptr>, iov: &mut IovIterDest<'_>) -> Result<usize> {
        let count = iov.len() as u64;
        let offset = kiocb.ki_pos() as u64;
        let ret = dispatch(OP_READ, count, offset);
        let n = match ret {
            // No extension loaded: nothing to read.
            DISPATCH_UNHANDLED => 0usize,
            // Extension returned an error.
            r if r < 0 => return Err(Error::from_errno(-r as i32)),
            // Extension reports `r` bytes available.
            // (Actual data delivery via bpf_probe_write_user is future work;
            // until then the userspace buffer is left untouched.)
            r => r as usize,
        };
        // The old `file::Operations::read` API let the kernel advance the
        // file position automatically from the return value. `read_iter` puts
        // that responsibility on the driver, so do it here to preserve the
        // original semantics.
        *kiocb.ki_pos_mut() += n as i64;
        Ok(n)
    }

    fn write_iter(mut kiocb: Kiocb<'_, Self::Ptr>, iov: &mut IovIterSource<'_>) -> Result<usize> {
        let count = iov.len() as u64;
        let offset = kiocb.ki_pos() as u64;
        let ret = dispatch(OP_WRITE, count, offset);
        let n = match ret {
            // No extension loaded: silently consume the bytes.
            DISPATCH_UNHANDLED => count as usize,
            r if r < 0 => return Err(Error::from_errno(-r as i32)),
            r => r as usize,
        };
        *kiocb.ki_pos_mut() += n as i64;
        Ok(n)
    }
}

// ── module init / exit ────────────────────────────────────────────────────────

#[pin_data(PinnedDrop)]
struct RexFwdModule {
    #[pin]
    _dev: MiscDeviceRegistration<RexFwdDev>,
}

impl kernel::InPlaceModule for RexFwdModule {
    fn init(_module: &'static ThisModule) -> impl PinInit<Self, Error> {
        pr_info!("rex_fwd: loading — /dev/rex_fwd\n");
        try_pin_init!(Self {
            _dev <- MiscDeviceRegistration::register(MiscDeviceOptions {
                name: c_str!("rex_fwd"),
            }),
        })
    }
}

#[pinned_drop]
impl PinnedDrop for RexFwdModule {
    fn drop(self: Pin<&mut Self>) {
        pr_info!("rex_fwd: unloading\n");
    }
}
