// SPDX-License-Identifier: GPL-2.0

//! Baseline for the crash-recovery project: the same bug, *in the driver
//! body*.
//!
//! This module is the control experiment for `samples/recover_driver`.
//! It implements the identical "logic" (classify each write by size with
//! an 8-entry weight table, accumulate a weighted byte total) directly in
//! `write_iter`, including the identical latent bounds bug: the developer
//! assumed a single write is always < 32 bytes.
//!
//!   count <  32 → normal path
//!   count >= 32 → out-of-bounds index → Rust panic in *kernel driver
//!                 code* → Rust-for-Linux panic handler → BUG() → oops
//!
//! With `CONFIG_PANIC_ON_OOPS=y` (this repo's kernel config) and/or
//! `oops=panic` (added by the q-scripts) the oops is a full kernel panic:
//! the whole machine dies.  Even without those, the writing process is
//! killed without errno semantics, the kernel is tainted, and any state
//! the driver held (locks, refcounts) is leaked.
//!
//! Contrast with `recover_driver`, where the same bug lives inside a Rex
//! extension: the panic is caught by Rex's exception handling and
//! userspace just sees -EIO.
//!
//! # Build
//!
//! ```sh
//! make -C <linux-src> M=$(pwd) modules LLVM=1
//! ```
//!
//! # Usage (the machine will not survive)
//!
//! ```sh
//! insmod rex_baseline.ko
//! ./event-trigger     # third write (40 bytes) panics the kernel
//! ```

use core::hint::black_box;
use core::sync::atomic::{AtomicU64, Ordering};

use kernel::{
    c_str,
    fs::{File, Kiocb},
    iov::{IovIterDest, IovIterSource},
    miscdevice::{MiscDevice, MiscDeviceOptions, MiscDeviceRegistration},
    prelude::*,
};

module! {
    type: RexBaselineModule,
    name: "rex_baseline",
    authors: ["SSLab"],
    description: "Crash-recovery baseline: the bounds bug lives in the driver body",
    license: "GPL",
}

// Identical to the logic in ../../recover_driver/src/main.rs.
// BUG (on purpose): only 8 classes; count >= 32 indexes out of bounds.
const CLASS_WEIGHT: [u64; 8] = [1, 1, 2, 2, 4, 4, 8, 8];

/// Weighted byte total — the driver's only internal state, mirroring the
/// TOTAL map of the recover_driver extension.
static TOTAL: AtomicU64 = AtomicU64::new(0);

struct RexBaselineDev;

#[vtable]
impl MiscDevice for RexBaselineDev {
    // No per-open state.
    type Ptr = ();

    fn open(_file: &File, _misc: &MiscDeviceRegistration<Self>) -> Result<()> {
        Ok(())
    }

    fn read_iter(mut kiocb: Kiocb<'_, Self::Ptr>, _iov: &mut IovIterDest<'_>) -> Result<usize> {
        // Nothing to read; mirror recover_driver's EOF behaviour.
        *kiocb.ki_pos_mut() += 0;
        Ok(0)
    }

    fn write_iter(mut kiocb: Kiocb<'_, Self::Ptr>, iov: &mut IovIterSource<'_>) -> Result<usize> {
        let count = iov.len() as u64;

        // BUG (on purpose): count >= 32 makes class >= 8 and the indexing
        // below panics — but this time the panic runs on the normal kernel
        // stack with no landingpad: RfL's panic handler calls BUG().
        // black_box keeps the bounds check at runtime, as in the
        // protected variant.
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

        *kiocb.ki_pos_mut() += count as i64;
        Ok(count as usize)
    }
}

#[pin_data]
struct RexBaselineModule {
    #[pin]
    _dev: MiscDeviceRegistration<RexBaselineDev>,
}

impl kernel::InPlaceModule for RexBaselineModule {
    fn init(_module: &'static ThisModule) -> impl PinInit<Self, Error> {
        pr_info!("loading — /dev/rex_baseline (bug is in the driver body)\n");
        try_pin_init!(Self {
            _dev <- MiscDeviceRegistration::register(MiscDeviceOptions {
                name: c_str!("rex_baseline"),
            }),
        })
    }
}
