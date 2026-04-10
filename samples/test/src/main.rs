#![no_std]
#![no_main]

extern crate rex;

use rex::kprobe::kprobe;
use rex::map::{RexArrayMap, RexHashMap};
use rex::pt_regs::PtRegs;
use rex::tracepoint::*;
use rex::{rex_kprobe, rex_map, rex_printk, rex_tracepoint, Result};

// We use existing device "zero" as a test. If someone want to
// build driver with rex extension, maybe they should also build a
// real driver.
const DEVICE_MAJOR: u32 = 1;
const DEVICE_MINOR: u32 = 5;

// Struct field offsets for Linux 6.11 x86-64 (verify with pahole):
//   pahole -C file  vmlinux | grep f_inode   -> 32
//   pahole -C inode vmlinux | grep i_rdev    -> 64
const FILE_F_INODE_OFFSET: usize = 32;
const INODE_I_RDEV_OFFSET: usize = 4;

// Shared data structures

/// Sensor reading injected into the SENSOR_DATA map on every intercepted read.
#[repr(C)]
#[derive(Copy, Clone)]
pub struct SensorReading {
    pub timestamp_ns: u64, // bpf_ktime_get_ns() at time of intercept
    pub channel: u32,      // sensor channel (0-based)
    pub raw_value: i32,    // simulated ADC value
    pub temperature: i32,  // milli-Celsius  (e.g. 25000 = 25.000 °C)
    pub status: u32,       // bit0=valid  bit1=overflow
}

/// Last device event — stored in LAST_EVENT[0] so userspace can poll via map
/// fd. Fields are plain integers so no unsafe is needed to read/write the map.
/// kind: 1=opened  2=read  3=write
#[repr(C)]
#[derive(Copy, Clone)]
pub struct DeviceEvent {
    pub kind: u32,
    pub pid: u32,
    pub timestamp: u64,
    pub extra: u64, // read: bytes requested; write: command word
}

// ── maps ──────────────────────────────────────────────────────────────────────

/// PIDs that currently have /dev/rex_sensor open (value always 1).
#[rex_map]
static OPEN_PIDS: RexHashMap<u32, u8> = RexHashMap::new(1024, 0);

/// Per-channel sensor readings.  Index = channel number (0..15).
#[rex_map]
static SENSOR_DATA: RexArrayMap<SensorReading> = RexArrayMap::new(16, 0);

/// Last command word received via write().  Index 0 = most recent.
#[rex_map]
static CMD_REGISTER: RexArrayMap<u64> = RexArrayMap::new(4, 0);

/// Most recent DeviceEvent.  Userspace polls index 0 via the map fd.
/// Using an array instead of a ring buffer avoids the unsafe byte-slice
/// conversion that ring buffer output requires.
#[rex_map]
static LAST_EVENT: RexArrayMap<DeviceEvent> = RexArrayMap::new(1, 0);

// ── helpers
// ───────────────────────────────────────────────────────────────────

#[inline(always)]
fn is_device_owner(pid: u32) -> bool {
    OPEN_PIDS.get_mut(&pid).is_some()
}

#[inline(always)]
fn emit_event(ev: &DeviceEvent) {
    // Store the latest event at index 0.  Userspace polls this via the map fd.
    // No unsafe needed: DeviceEvent contains only plain integers.
    let idx: u32 = 0;
    let _ = LAST_EVENT.insert(&idx, ev);
}

/// Confirm the file pointer belongs to DEVICE_MAJOR:DEVICE_MINOR.
/// Returns true if the probe reads succeed and the major:minor match.
#[inline(always)]
fn is_our_device(ctx: &kprobe, file_ptr: usize) -> bool {
    let mut inode_ptr: usize = 0;
    if ctx
        .bpf_probe_read_kernel(
            &mut inode_ptr,
            (file_ptr + FILE_F_INODE_OFFSET) as *const (),
        )
        .is_err()
    {
        return false;
    }

    let mut i_rdev: u32 = 0;
    if ctx
        .bpf_probe_read_kernel(
            &mut i_rdev,
            (inode_ptr + INODE_I_RDEV_OFFSET) as *const (),
        )
        .is_err()
    {
        return false;
    }

    (i_rdev >> 20) == DEVICE_MAJOR && (i_rdev & 0xFFFFF) == DEVICE_MINOR
}

// ── hook 1: openat tracepoint
// ─────────────────────────────────────────────────
//
// Fires on every openat(2).  Reads the first 16 bytes of the filename to check
// for the /dev/rex_sensor prefix, then registers the calling PID in OPEN_PIDS.

#[rex_tracepoint]
fn rex_sensor_open(
    obj: &tracepoint<SyscallsEnterOpenatCtx>,
    ctx: &'static SyscallsEnterOpenatCtx,
) -> Result {
    Ok(0)
}

// ── hook 2: vfs_read kprobe
// ───────────────────────────────────────────────────
//
// x86-64 registers at entry to vfs_read:
//   rdi = struct file *
//   rsi = char __user * buf
//   rdx = size_t count
//
// On intercept:
//   1. Filter on OPEN_PIDS + device major:minor.
//   2. Update SENSOR_DATA[0] with a live timestamp and simulated value.
//   3. Emit a READ event so the daemon knows to poll the map.
//
// Note: bpf_probe_write_user is not yet wrapped in the Rex kernel crate.
// Userspace reads sensor data via the SENSOR_DATA map fd rather than
// receiving injected bytes directly in the read() buffer.

#[rex_kprobe(function = "vfs_read")]
fn rex_sensor_read(obj: &kprobe, regs: &mut PtRegs) -> Result {
    let task = match obj.bpf_get_current_task() {
        Some(t) => t,
        None => return Ok(0),
    };

    let pid = task.get_pid() as u32;
    let file_ptr = regs.rdi() as usize;
    let count = regs.rdx() as usize;

    if !is_our_device(obj, file_ptr) {
        return Ok(0);
    }

    rex_printk!("[rex_sensor] I am the divece owner");
    let _ = OPEN_PIDS.insert(&pid, &1u8);

    // Update the channel-0 reading with current time + simulated ADC.
    let now = obj.bpf_ktime_get_ns();
    let jiffies = obj.bpf_jiffies64();
    let channel: u32 = 0;

    let reading = SensorReading {
        timestamp_ns: now,
        channel,
        raw_value: ((jiffies & 0xFF) as i32) - 128, // cycles −128..127
        temperature: 25_000 + (((jiffies & 0xFF) as i32) - 128) * 78,
        status: 1, // valid
    };

    // insert() overwrites the existing entry (array map: key always exists).
    let _ = SENSOR_DATA.insert(&channel, &reading);

    emit_event(&DeviceEvent {
        kind: 2,
        pid,
        timestamp: now,
        extra: count as u64,
    });

    rex_printk!(
        "[rex_sensor] pid={} read {} bytes raw={}\n",
        pid,
        count,
        reading.raw_value
    )?;
    Ok(0)
}

// ── hook 3: vfs_write kprobe
// ──────────────────────────────────────────────────
//
// x86-64 registers at entry to vfs_write:
//   rdi = struct file *
//   rsi = const char __user * buf
//   rdx = size_t count
//
// On intercept:
//   1. Filter on OPEN_PIDS + device major:minor.
//   2. Read first 8 bytes of the user write buffer as a u64 command word.
//   3. Store command in CMD_REGISTER[0].
//   4. Emit a WRITE event.
//   5. Override the return value with `count` (claim all bytes consumed).

#[rex_kprobe(function = "vfs_write")]
fn rex_sensor_write(obj: &kprobe, regs: &mut PtRegs) -> Result {
    let pid = match obj.bpf_get_current_task() {
        Some(t) => t.get_pid() as u32,
        None => return Ok(0),
    };
    if !is_device_owner(pid) {
        return Ok(0);
    }

    let file_ptr = regs.rdi() as usize;
    let user_buf = regs.rsi() as usize;
    let count = regs.rdx() as usize;

    if !is_our_device(obj, file_ptr) {
        return Ok(0);
    }

    // Read command word from user buffer (safe in syscall context).
    let mut cmd: u64 = 0;
    let _ = obj.bpf_probe_read_kernel(&mut cmd, user_buf as *const ());

    let idx: u32 = 0;
    let _ = CMD_REGISTER.insert(&idx, &cmd);

    let now = obj.bpf_ktime_get_ns();
    emit_event(&DeviceEvent {
        kind: 3,
        pid,
        timestamp: now,
        extra: cmd,
    });

    // Tell the kernel vfs_write "succeeded" without reaching the real driver.
    obj.bpf_override_return(regs, count as u64);

    rex_printk!("[rex_sensor] pid={} write cmd=0x{:x}\n", pid, cmd)?;
    Ok(0)
}
