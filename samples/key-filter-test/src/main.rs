#![no_std]
#![no_main]

// Import the Rex kernel interface wrappers
extern crate rex;
use core::ffi::c_uint;

use rex::tracepoint::*;
use rex::{rex_printk, rex_tracepoint, Result};
use rex_kernel::prelude::*;

// Standard Linux EV_KEY constant
const EV_KEY: c_uint = 1;

// Attach to the kernel's input tracepoint
#[rex_tracepoint]
pub fn hid_keyboard_filter(ctx: TracepointContext) -> Result {
    // Rex provides safe wrappers to read memory from the kernel context
    let event_type: c_uint = ctx.read_arg("type")?;

    // Filter out mouse movement, touchscreens, etc.
    if event_type == EV_KEY {
        let event_code: c_uint = ctx.read_arg("code")?;
        let event_value: i32 = ctx.read_arg("value")?;

        // Value mappings: 1 = pressed, 0 = released, 2 = held
        rex_kernel::log::info!(
            "Rex Filter | Key Code: {}, State: {}",
            event_code,
            event_value
        );

        // Custom filtering or modification logic goes here
    }

    Ok(0)
}

#[rex_tracepoint]
fn rex_prog1(
    obj: &tracepoint<SyscallsEnterDupCtx>,
    _: &'static SyscallsEnterDupCtx,
) -> Result {
    let option_task = obj.bpf_get_current_task();
    if let Some(task) = option_task {
        let cpu = obj.bpf_get_smp_processor_id();
        let pid = task.get_pid();
        rex_printk!("Rust triggered from PID {} on CPU {}.\n", pid, cpu)?;
    }
    Ok(0)
}
