// SPDX-License-Identifier: GPL-2.0

//! Route B demo: the bug stays in the driver body, the *kernel* recovers.
//!
//! Same driver as `samples/baseline_driver` — the identical latent bounds
//! bug lives directly in `write_iter` — but the buggy logic runs under
//! `kernel::rex_recover::protected_call`, the Rex driver-side recovery
//! trampoline:
//!
//!   count <  32 → normal path, identical behaviour
//!   count >= 32 → out-of-bounds panic *in the driver body*
//!               → RfL panic handler → rex_driver_try_recover()
//!               → longjmp back to the protected-call site
//!               → write(2) returns -EIO; the kernel survives
//!
//! Contrast:
//!   baseline_driver  same bug, unprotected  → BUG() → kernel panic
//!   recover_driver   bug moved into a Rex extension (route A)
//!   this sample      bug stays in the driver, kernel-side trampoline
//!                    recovers it (route B)
//!
//! The protected region must not acquire resources (locks, allocations,
//! refcounts): recovery skips destructors.  Here it only does arithmetic,
//! an atomic add and a pr_info.
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
//! insmod rex_guarded.ko
//! ./event-trigger     # 40-byte write returns EIO, machine survives
//! ```

use core::hint::black_box;
use core::sync::atomic::{AtomicU64, Ordering};

use kernel::{
    c_str,
    fs::{File, Kiocb},
    iov::{IovIterDest, IovIterSource},
    miscdevice::{MiscDevice, MiscDeviceOptions, MiscDeviceRegistration},
    prelude::*,
    rex_recover,
};

module! {
    type: RexGuardedModule,
    name: "rex_guarded",
    authors: ["SSLab"],
    description: "Crash-recovery route B: buggy driver body guarded by the kernel trampoline",
    license: "GPL",
}

// Identical to baseline_driver / the recover_driver extension.
// BUG (on purpose): only 8 classes; count >= 32 indexes out of bounds.
const CLASS_WEIGHT: [u64; 8] = [1, 1, 2, 2, 4, 4, 8, 8];

/// Weighted byte total — the driver's only internal state.
static TOTAL: AtomicU64 = AtomicU64::new(0);

struct RexGuardedDev;

#[vtable]
impl MiscDevice for RexGuardedDev {
    // No per-open state.
    type Ptr = ();

    fn open(_file: &File, _misc: &MiscDeviceRegistration<Self>) -> Result<()> {
        Ok(())
    }

    fn read_iter(mut kiocb: Kiocb<'_, Self::Ptr>, _iov: &mut IovIterDest<'_>) -> Result<usize> {
        // Nothing to read; mirror the other variants' EOF behaviour.
        *kiocb.ki_pos_mut() += 0;
        Ok(0)
    }

    fn write_iter(mut kiocb: Kiocb<'_, Self::Ptr>, iov: &mut IovIterSource<'_>) -> Result<usize> {
        let count = iov.len() as u64;

        // The buggy logic, byte-for-byte the same as baseline_driver,
        // but run under the recovery trampoline: a panic inside the
        // closure comes back here as -EIO instead of BUG().
        let ret = rex_recover::protected_call(|| {
            // BUG (on purpose): count >= 32 panics on the indexing.
            let class = (count / 4) as usize;
            let weight = CLASS_WEIGHT[black_box(class)];

            let total = TOTAL.fetch_add(count * weight, Ordering::Relaxed) +
                count * weight;
            pr_info!(
                "write count={} class={} weight={} total={}\n",
                count,
                class,
                weight,
                total
            );
            count as i64
        });

        if ret < 0 {
            return Err(Error::from_errno(ret as i32));
        }
        let n = (ret as u64).min(count) as usize;
        *kiocb.ki_pos_mut() += n as i64;
        Ok(n)
    }
}

#[pin_data]
struct RexGuardedModule {
    #[pin]
    _dev: MiscDeviceRegistration<RexGuardedDev>,
}

impl kernel::InPlaceModule for RexGuardedModule {
    fn init(_module: &'static ThisModule) -> impl PinInit<Self, Error> {
        pr_info!("loading — /dev/rex_guarded (bug in driver body, trampoline armed)\n");
        try_pin_init!(Self {
            _dev <- MiscDeviceRegistration::register(MiscDeviceOptions {
                name: c_str!("rex_guarded"),
            }),
        })
    }
}
