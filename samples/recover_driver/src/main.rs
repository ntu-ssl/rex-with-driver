#![no_std]
#![no_main]

extern crate rex;

use core::hint::black_box;

use rex::kprobe::kprobe;
use rex::map::{RexArrayMap, RexHashMap};
use rex::pt_regs::PtRegs;
use rex::{Result, rex_kprobe, rex_map, rex_printk};

// ─── eBPF program which is co-working with the driver ───
//
// The kernel module (/dev/rex_recover) is only a thin shim:
// each file operation calls
//
//   rex_recover_dispatch(op: u64, count: u64, offset: u64) -> i64
//     rdi = op     1=read 2=write
//     rsi = count  # of byte 
//     rdx = offset 
//
// This function uses kprobe to hook at the entry point of "rex_recover_dispatch"
// and run before the execution of the function.
//
// The return value ( Use kernel pull. Don't use bpf_override_return since
// optprobe will ignore the modification of regs->ip ):
//
//   1. Enter: write INFLIGHT[pid] = 1
//   2. Success: in the end, write RESULT[pid] = return value (commit point) 
//   3. dispatch body read the return value and consume two maps:
//        with RESULT          -> Completed. Use it as the return value of the file operation.
//        INFLIGHT only        -> panic occured in the middle and was handled by Rex EH -> -EIO
//        Others               -> doesn't hook this program -> -ENXIO
//
// Remark:Writing RESULT should be the last step of a successfull execution.
// panic must happen before commit, so "no RESULT" = "there's a panic"

const OP_READ: u64 = 1;
const OP_WRITE: u64 = 2;

const EINVAL: i64 = 22;

//
//   count <  32 → valid
//   count >= 32 → out of bound → Rust panic → Rex landingpad
//                → RESULT with no commit → driver returns -EIO to the userspace
//
const CLASS_WEIGHT: [u64; 8] = [1, 1, 2, 2, 4, 4, 8, 8];

// ── maps ──────────────────────────────────────────────────────────────────────

/// pid → 1,「這次 dispatch 的邏輯開始執行了」。進場時寫入,
/// dispatch body 讀完即刪。panic 偵測的關鍵:INFLIGHT 在而 RESULT
/// 不在,代表邏輯中途被 landingpad 終止。
#[rex_map]
static INFLIGHT: RexHashMap<u32, u64> = RexHashMap::new(1024, 0);

/// pid → 本次 file operation 的回傳值(commit channel)。
/// 只在邏輯成功跑完時、作為最後一步寫入。
#[rex_map]
static RESULT: RexHashMap<u32, i64> = RexHashMap::new(1024, 0);

/// index 0 → 加權累計的 write byte 數(本「driver」唯一的內部狀態)。
#[rex_map]
static TOTAL: RexArrayMap<u64> = RexArrayMap::new(1, 0);

// ─── helpers ───

/// Commit:宣告本次操作成功、回傳值為 `val`。
/// 必須是成功路徑的最後一個動作(panic 永遠發生在它之前)。
fn commit(pid: u32, val: i64) {
    let _ = RESULT.insert(&pid, &val);
}

// ─── driver 邏輯本體 ───

#[rex_kprobe(function = "rex_recover_dispatch")]
fn recover_logic(obj: &kprobe, regs: &mut PtRegs) -> Result {
    let op = regs.rdi();
    let count = regs.rsi();
    let offset = regs.rdx();

    let pid =
        obj.bpf_get_current_task().map(|t| t.get_pid()).unwrap_or(0) as u32;

    // 進場:清掉殘留決定(防禦性)、標記 in-flight。
    let _ = RESULT.delete(&pid);
    let _ = INFLIGHT.insert(&pid, &1u64);

    match op {
        OP_READ => {
            let _ = rex_printk!("[recover] read  pid={}\n", pid);
            // 本 demo 沒有資料可回,一律 EOF。
            commit(pid, 0);
        }
        OP_WRITE => {
            let _ = rex_printk!(
                "[recover] write pid={} count={} off={}\n",
                pid,
                count,
                offset
            );

            // BUG(蓄意保留): count >= 32 時 class >= 8,越界 panic。
            // black_box 擋住常數傳播,確保 bounds check 留在 runtime。
            let class = (count / 4) as usize;
            let weight = CLASS_WEIGHT[black_box(class)];

            // 內部狀態更新。注意它在 commit 之前:panic 時本次的
            // TOTAL 累計不會發生(寫在越界讀之後),狀態保持一致。
            let idx = 0u32;
            if let Some(t) = TOTAL.get_mut(&idx) {
                *t += count * weight;
                let _ = rex_printk!(
                    "[recover] total={} (class={} w={})\n",
                    *t,
                    class,
                    weight
                );
            }

            // commit:宣告成功、消耗全部 count 個 bytes。
            commit(pid, count as i64);
        }
        _ => {
            // 不認得的 op:明確回 -EINVAL(這也是一種「完成」)。
            commit(pid, -EINVAL);
        }
    }

    Ok(0)
}
