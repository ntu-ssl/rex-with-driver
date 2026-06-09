#![no_std]
#![no_main]

extern crate rex;

use core::hint::black_box;

use rex::kprobe::kprobe;
use rex::pt_regs::PtRegs;
use rex::{Result, rex_kprobe, rex_printk};

/// 固定長度 4 的查找表。
/// 用 arg 當索引去讀它：index < 4 是正常路徑，index >= 4 會觸發
/// bounds-check panic，藉此測試 Rex 的 in-kernel exception handling。
const TABLE: [u64; 4] = [10, 20, 30, 40];

#[rex_kprobe(function = "kprobe_target_func")]
fn rex_panic_test(_obj: &kprobe, ctx: &mut PtRegs) -> Result {
    // arg 來自 event-trigger 的 ioctl(fd, 1313, arg)，
    // 在 kprobe 進入點透過第一參數暫存器 (rdi) 傳入。
    let idx = ctx.rdi() as usize;

    // panic 前先印一行，方便在 trace / dmesg 觀察「panic 前確實執行到這」。
    rex_printk!("[panic_test] before index, idx={}\n", idx)?;

    // black_box 擋住編譯器的常數傳播 / 死碼消除，確保索引是 runtime 行為：
    //   idx <  4 → 正常路徑，讀到表中的值
    //   idx >= 4 → 陣列越界 → panic → 由 Rex 的 panic handler 接住並安全終止本程式
    let val = TABLE[black_box(idx)];

    // 只有正常路徑 (idx < 4) 才會走到這裡；越界時這行不會被印出。
    rex_printk!("[panic_test] after index, val={}\n", val)?;

    Ok(0)
}
