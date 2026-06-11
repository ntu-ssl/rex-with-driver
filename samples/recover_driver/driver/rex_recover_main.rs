// SPDX-License-Identifier: GPL-2.0

//! Rex recoverable-driver shim.
//!
//! Route A of the crash-recovery project: the *driver logic* lives in a Rex
//! extension (../src/main.rs) where Rust panics are caught by Rex's
//! exception-handling framework; this in-kernel module is only a thin,
//! panic-free shim.  A panic in the logic surfaces to userspace as a plain
//! errno instead of a kernel BUG().
//!
//! Exposes `/dev/rex_recover` as a misc device.  read/write funnel into
//! `rex_recover_dispatch()` — a `#[no_mangle] #[inline(never)]` Rust
//! function the extension kprobes at entry.
//!
//! # Value flow (kernel pull, three-state; no bpf_override_return)
//!
//! ```text
//! write(2) ─► rex_recover_dispatch(op, count, offset)
//!               │ kprobe entry fires ─► extension logic runs:
//!               │   INFLIGHT[pid]=1 ... logic ... RESULT[pid]=val (commit)
//!               │   (a panic is caught by Rex EH before the commit)
//!               ▼
//!             dispatch body (C shim) consumes both maps:
//!               RESULT present        → return its value
//!               only INFLIGHT present → logic panicked → -EIO
//!               neither               → no extension  → -ENXIO
//!               │
//!               ▼
//!             write(2) surfaces a negative return as the errno
//! ```
//!
//! bpf_override_return is avoided on purpose: optimized kprobes (optprobe)
//! silently ignore its regs->ip rewrite.  The dispatch's own return value
//! carries the decision instead.
//!
//! BPF map access is delegated to rex_recover_shim.c because Rust-for-Linux
//! has no BPF map bindings (same `.rs` + `.c` single-module layout as the
//! in-tree `rust_print` sample).
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
//! insmod rex_recover.ko    # must come first: provides the kprobe symbol
//! ./loader &               # attaches the logic, registers the maps
//! ./event-trigger          # exercises normal / panic / recovery paths
//! ```

use core::hint::black_box;

use kernel::ioctl::_IOW;
use kernel::{
    c_str,
    error::code::ENOTTY,
    fs::{File, Kiocb},
    iov::{IovIterDest, IovIterSource},
    miscdevice::{MiscDevice, MiscDeviceOptions, MiscDeviceRegistration},
    prelude::*,
};

module! {
    type: RexRecoverModule,
    name: "rex_recover",
    authors: ["SSLab"],
    description: "Rex recoverable-driver shim (logic lives in a Rex extension)",
    license: "GPL",
}

// ── op codes ──────────────────────────────────────────────────────────────────
// Must stay in sync with ../src/main.rs.
const OP_READ: u64 = 1;
const OP_WRITE: u64 = 2;

// ── ioctl protocol ────────────────────────────────────────────────────────────
// Must stay in sync with rex_recover_shim.c and ../loader.c.
const REX_RECOVER_MAP_INFLIGHT: i32 = 1;
const REX_RECOVER_MAP_RESULT: i32 = 2;

const REX_RECOVER_SET_INFLIGHT_MAP: u32 = _IOW::<i32>('R' as u32, 1);
const REX_RECOVER_SET_RESULT_MAP: u32 = _IOW::<i32>('R' as u32, 2);

// ── C shim FFI (rex_recover_shim.c) ───────────────────────────────────────────

extern "C" {
    /// bpf_map_get(fd) into the INFLIGHT/RESULT slot; 0 or negative errno.
    fn rex_recover_register_map(which: i32, fd: i32) -> i32;
    /// bpf_map_put any registered maps.
    fn rex_recover_unregister_maps();
    /// Consume INFLIGHT[pid]/RESULT[pid] and fold them into a return value.
    fn rex_recover_collect() -> i64;
}

// ── dispatch hook point ───────────────────────────────────────────────────────
//
// The extension kprobes this function's entry, reads op/count/offset from
// rdi/rsi/rdx, runs the driver logic, and commits its return value into
// RESULT[pid] as its last step.  The body then collects the three-state
// outcome via the C shim.  `#[no_mangle]` keeps a kallsyms-resolvable
// symbol, `#[inline(never)]` keeps a real entry point, `extern "C"` puts
// the args where the extension reads them, and `black_box` keeps them
// observably live at entry.
/// kprobe target: returns whatever the extension logic committed into
/// RESULT\[pid\], or -EIO (panicked) / -ENXIO (not attached).
#[no_mangle]
#[inline(never)]
pub extern "C" fn rex_recover_dispatch(op: u64, count: u64, offset: u64) -> i64 {
    black_box((op, count, offset));
    // SAFETY: FFI call into this module's own C shim; no preconditions.
    unsafe { rex_recover_collect() }
}

// ── file operations ───────────────────────────────────────────────────────────

struct RexRecoverDev;

#[vtable]
impl MiscDevice for RexRecoverDev {
    // No per-open state.
    type Ptr = ();

    fn open(_file: &File, _misc: &MiscDeviceRegistration<Self>) -> Result<()> {
        Ok(())
    }

    fn read_iter(mut kiocb: Kiocb<'_, Self::Ptr>, iov: &mut IovIterDest<'_>) -> Result<usize> {
        let count = iov.len() as u64;
        let offset = kiocb.ki_pos() as u64;
        let ret = rex_recover_dispatch(OP_READ, count, offset);
        if ret < 0 {
            // -EIO: logic panicked (recovered); -ENXIO: no logic attached.
            return Err(Error::from_errno(ret as i32));
        }
        // The demo logic returns 0 (EOF); clamp defensively and do not
        // touch the user buffer (data delivery is future work).
        let n = (ret as u64).min(count) as usize;
        *kiocb.ki_pos_mut() += n as i64;
        Ok(n)
    }

    fn write_iter(mut kiocb: Kiocb<'_, Self::Ptr>, iov: &mut IovIterSource<'_>) -> Result<usize> {
        let count = iov.len() as u64;
        let offset = kiocb.ki_pos() as u64;
        let ret = rex_recover_dispatch(OP_WRITE, count, offset);
        if ret < 0 {
            return Err(Error::from_errno(ret as i32));
        }
        let n = (ret as u64).min(count) as usize;
        *kiocb.ki_pos_mut() += n as i64;
        Ok(n)
    }

    fn ioctl(_device: (), _file: &File, cmd: u32, arg: usize) -> Result<isize> {
        let which = match cmd {
            REX_RECOVER_SET_INFLIGHT_MAP => REX_RECOVER_MAP_INFLIGHT,
            REX_RECOVER_SET_RESULT_MAP => REX_RECOVER_MAP_RESULT,
            _ => return Err(ENOTTY),
        };
        // arg is the map fd, passed by value.
        // SAFETY: FFI call into this module's own C shim.
        let ret = unsafe { rex_recover_register_map(which, arg as i32) };
        if ret < 0 {
            return Err(Error::from_errno(ret));
        }
        pr_info!("map registered (which={} fd={})\n", which, arg as i32);
        Ok(0)
    }
}

// ── module init / exit ────────────────────────────────────────────────────────

#[pin_data(PinnedDrop)]
struct RexRecoverModule {
    #[pin]
    _dev: MiscDeviceRegistration<RexRecoverDev>,
}

impl kernel::InPlaceModule for RexRecoverModule {
    fn init(_module: &'static ThisModule) -> impl PinInit<Self, Error> {
        pr_info!("loading — /dev/rex_recover\n");
        try_pin_init!(Self {
            _dev <- MiscDeviceRegistration::register(MiscDeviceOptions {
                name: c_str!("rex_recover"),
            }),
        })
    }
}

#[pinned_drop]
impl PinnedDrop for RexRecoverModule {
    fn drop(self: Pin<&mut Self>) {
        // SAFETY: FFI call into this module's own C shim; drops map refs.
        unsafe { rex_recover_unregister_maps() };
        pr_info!("unloading\n");
    }
}
