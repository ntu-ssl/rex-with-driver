#![no_std]
#![no_main]

extern crate rex;

use rex::kprobe::kprobe;
use rex::pt_regs::PtRegs;
use rex::{rex_kprobe, rex_printk, Result};

const TARGET_MAJOR: u32 = 1;
const TARGET_MINOR: u32 = 5;

const MINORBITS: u32 = 20;
const MINORMASK: u32 = (1u32 << MINORBITS) - 1;

const S_IFMT: u16 = 0o170000;
const S_IFCHR: u16 = 0o020000;

// Verify on the kernel:
//   pahole -C file  /sys/kernel/btf/vmlinux | grep f_inode
//   pahole -C inode /sys/kernel/btf/vmlinux | grep -E '\bi_mode\b|\bi_rdev\b'
const F_INODE_OFFSET: usize = 0x20;
const I_MODE_OFFSET: usize = 0x00;
const I_RDEV_OFFSET: usize = 0x4C;

const PATH_DENTRY_OFFSET: usize = 8;
const DENTRY_INODE_OFFSET: usize = 0x30;

fn check_inode(obj: &kprobe, inode_ptr: usize) -> Option<()> {
    if inode_ptr == 0 {
        return None;
    }

    let mut i_mode: u16 = 0;
    obj.bpf_probe_read_kernel(
        &mut i_mode,
        (inode_ptr + I_MODE_OFFSET) as *const (),
    )
    .ok()?;
    if (i_mode & S_IFMT) != S_IFCHR {
        return None;
    }

    let mut i_rdev: u32 = 0;
    obj.bpf_probe_read_kernel(
        &mut i_rdev,
        (inode_ptr + I_RDEV_OFFSET) as *const (),
    )
    .ok()?;

    let major = i_rdev >> MINORBITS;
    let minor = i_rdev & MINORMASK;

    if major == TARGET_MAJOR && minor == TARGET_MINOR {
        Some(())
    } else {
        None
    }
}

#[rex_kprobe(function = "vfs_open")]
pub fn rex_sensor_open(obj: &kprobe, ctx: &mut PtRegs) -> Result {
    let path_ptr = ctx.rdi() as usize;
    if path_ptr == 0 {
        return Ok(0);
    }

    let mut dentry_ptr: usize = 0;
    if obj
        .bpf_probe_read_kernel(
            &mut dentry_ptr,
            (path_ptr + PATH_DENTRY_OFFSET) as *const (),
        )
        .is_err()
    {
        return Ok(0);
    }
    if dentry_ptr == 0 {
        return Ok(0);
    }

    let mut inode_ptr: usize = 0;
    if obj
        .bpf_probe_read_kernel(
            &mut inode_ptr,
            (dentry_ptr + DENTRY_INODE_OFFSET) as *const (),
        )
        .is_err()
    {
        return Ok(0);
    }

    if check_inode(obj, inode_ptr).is_none() {
        return Ok(0);
    }

    let pid = obj.bpf_get_current_task().map(|t| t.get_pid()).unwrap_or(0);
    rex_printk!("open on target device, pid={}\n", pid)?;

    Ok(0)
}

#[rex_kprobe(function = "vfs_read")]
pub fn rex_sensor_read(obj: &kprobe, ctx: &mut PtRegs) -> Result {
    let file_ptr = ctx.rdi() as usize;
    if file_ptr == 0 {
        return Ok(0);
    }

    let mut inode_ptr: usize = 0;
    if obj
        .bpf_probe_read_kernel(
            &mut inode_ptr,
            (file_ptr + F_INODE_OFFSET) as *const (),
        )
        .is_err()
    {
        return Ok(0);
    }

    if check_inode(obj, inode_ptr).is_none() {
        return Ok(0);
    }

    let pid = obj.bpf_get_current_task().map(|t| t.get_pid()).unwrap_or(0);
    rex_printk!("vfs_read on target device, pid={}\n", pid)?;

    Ok(0)
}

#[rex_kprobe(function = "vfs_write")]
pub fn rex_sensor_write(obj: &kprobe, ctx: &mut PtRegs) -> Result {
    let file_ptr = ctx.rdi() as usize;
    if file_ptr == 0 {
        return Ok(0);
    }

    let mut inode_ptr: usize = 0;
    if obj
        .bpf_probe_read_kernel(
            &mut inode_ptr,
            (file_ptr + F_INODE_OFFSET) as *const (),
        )
        .is_err()
    {
        return Ok(0);
    }

    if check_inode(obj, inode_ptr).is_none() {
        return Ok(0);
    }

    let pid = obj.bpf_get_current_task().map(|t| t.get_pid()).unwrap_or(0);
    rex_printk!("vfs_write on target device, pid={}\n", pid)?;

    Ok(0)
}
