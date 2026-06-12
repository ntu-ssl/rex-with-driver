# 路線 B:Driver 本體的 panic recovery(kernel trampoline)

本文件說明路線 B 的 kernel 端改動:讓 **Rust kernel driver 本體**的
panic 可以被安全接住,file operation 以一個普通的 errno 返回
userspace,而不是經 `BUG()` 升級成 oops / 整機 kernel panic。

對照整個專題的三部曲:

| Sample | bug 位置 | 保護機制 | write 40 bytes 的結果 |
|---|---|---|---|
| `samples/baseline_driver` | driver 本體 | 無 | `BUG()` → 整機 kernel panic |
| `samples/recover_driver`(路線 A) | Rex extension | Rex EH(`rex_dispatcher_func` + landingpad) | errno=EIO |
| `samples/guarded_driver`(**路線 B**) | **driver 本體** | **本文件的 kernel trampoline** | errno=EIO |

路線 A 的限制是邏輯必須改寫成 Rex extension(受 Rex API 約束)。
路線 B 把 Rex 的 exception-handling 想法推廣到 driver 本體:driver
只要把可能 panic 的區段包進一個 closure,kernel 就能在 panic 時
unwind 回呼叫點。

## 機制總覽

Rex 原本的 EH(見 `exception-handling.md`)只保護「經
`rex_dispatcher_func` 進入、跑在 per-CPU Rex stack 上」的 extension。
driver 跑在普通 kernel stack 的(可 sleep 的)process context,panic
會走 Rust-for-Linux 的 panic handler 直接 `BUG()`。

路線 B 新增一條 setjmp/longjmp 式的路徑:

```text
write_iter (Rust driver)
  └─ kernel::rex_recover::protected_call(closure)    rust/kernel/rex_recover.rs
       └─ rex_driver_protected_call(shim, &slot)     arch/x86/net/rex.c
            ├─ 記錄 preempt_count / irq 狀態
            ├─ 武裝 current->rex_recovery_ctx(per-task setjmp 點)
            └─ __rex_driver_protected_call            arch/x86/net/rex_64.S
                 ├─ setjmp:存 callee-saved regs + rsp 進 ctx
                 └─ call closure
                      │
                      ├─(正常)return 回傳值 ────────────────► 返回
                      │
                      └─(panic)
                        RfL panic handler                rust/kernel/lib.rs
                          └─ rex_driver_try_recover()    arch/x86/net/rex.c
                               ├─ guard 檢查(不過 → fall through 回 BUG())
                               └─ rex_driver_recovery_landing   rex_64.S
                                    longjmp:還原 regs/rsp,
                                    以 -EIO「返回」protected_call 呼叫點
```

與 `rex_dispatcher_func` 的兩個關鍵差異:

1. **不換 stack**。extension 的機制依賴 per-CPU Rex stack;driver
   context 可以 sleep、可以被 preempt 與遷移 CPU,共用 per-CPU stack
   不可行。所以 recovery 點是 per-task 的
   (`current->rex_recovery_ctx`),unwind 只是把 rsp 拉回同一條
   kernel stack 上的呼叫點。
2. **有安全 guard**。extension 的資源由 cleanup ledger 兜底;driver
   沒有,所以 `rex_driver_try_recover()` 在狀態不對時會**拒絕復原**,
   讓 panic 照原樣升級成 `BUG()`(寧可 panic 也不洩漏鎖)。

## 修改的檔案(`linux/` submodule)

### 新增

#### `include/linux/rex_driver_recover.h`

機制的 API 與資料結構:

```c
struct rex_driver_recovery_ctx {
        /* setjmp snapshot,由 asm 寫入,順序不可動 */
        u64 rsp, rbp, rbx, r12, r13, r14, r15;
        /* guard 用,由 C wrapper 寫入 */
        u32 preempt_cnt;
        u32 irqs_disabled;
};

s64  rex_driver_protected_call(s64 (*func)(void *arg), void *arg);
void rex_driver_try_recover(void);
```

檔頭註解完整記錄了設計與限制,是 kernel 端的主要文件。

#### `rust/kernel/rex_recover.rs`

給 Rust driver 用的安全包裝。`protected_call<F: FnOnce() -> i64>(f)`
把 closure 放進 stack 上的 `Option<F>` slot,經一個 `extern "C"` shim
傳給 `rex_driver_protected_call`。慣例:closure 回傳非負值代表成功、
負的 errno 代表失敗;被復原的 panic 回 `-EIO`,呼叫端只需要一個
負值檢查:

```rust
let ret = rex_recover::protected_call(|| { /* 可能 panic 的邏輯 */ 0 });
if ret < 0 {
    return Err(Error::from_errno(ret as i32));
}
```

### 修改

#### `arch/x86/net/rex_64.S`

新增兩個 asm 函式(接在原 `rex_landingpad_asm` 之後):

- `__rex_driver_protected_call(func, arg, ctx)` — **setjmp 半邊**。
  把 7 個 callee-saved 暫存器(含 `rsp`,此時指向自己的 return
  address)存進 `ctx`,然後 `CALL_NOSPEC` 呼叫 `func(arg)`。正常路徑
  原樣返回 `func` 的回傳值。
- `rex_driver_recovery_landing(ctx, retval)` — **longjmp 半邊**。
  從 panic context 進入,還原 `ctx` 裡的暫存器與 `rsp`(一口氣丟棄
  panic 點與呼叫點之間的所有 frame),把 `retval` 放進 `%rax` 後
  `RET` —— pop 出來的正是 setjmp 時存的 return address,效果等同
  「`func` 正常返回了 -EIO」。

兩者都標了 `STACK_FRAME_NON_STANDARD`(objtool 不分析這種非常規
控制流)。

#### `arch/x86/net/rex.c`

- `rex_driver_protected_call()` — C wrapper:記錄
  `preempt_count()` / `irqs_disabled()` 進 ctx、武裝
  `current->rex_recovery_ctx`、呼叫 asm、離開時還原外層 ctx
  (**支援巢狀** protected call)。`EXPORT_SYMBOL_GPL`,out-of-tree
  module 可用。
- `rex_driver_try_recover()` — panic 分流,由 RfL panic handler
  呼叫。依序檢查:
  1. `current->rex_recovery_ctx` 沒武裝 → return(照舊 `BUG()`);
  2. `!in_task()` → return。irq/softirq/NMI 裡的 panic 屬於被中斷的
     context,不屬於 protected call;
  3. `preempt_count()` 或 irq 狀態與武裝時不一致 → `pr_err` 後
     return。這代表 protected region 內拿了鎖 / 關了中斷,longjmp
     會把它們永久洩漏,寧可讓 panic 升級;
  4. 全過 → 解除武裝(one-shot)、`pr_warn` 記錄、跳
     `rex_driver_recovery_landing(ctx, -EIO)`,不再返回。

#### `include/linux/sched.h` / `kernel/fork.c`

`task_struct` 新增 `struct rex_driver_recovery_ctx *rex_recovery_ctx`
欄位(以及 forward declaration)。`copy_process()` 一律清成 NULL:
recovery 點指向**父行程的 stack frame**,child 絕對不能繼承。

#### `rust/kernel/lib.rs`

panic handler 在 `BUG()` 之前插入一次 `rex_driver_try_recover()`:

```rust
#[panic_handler]
fn panic(info: &core::panic::PanicInfo<'_>) -> ! {
    pr_emerg!("{}\n", info);
    // 有武裝 recovery 點 → longjmp 回呼叫點,不再回來;
    // 沒有(或 guard 拒絕)→ 返回,照舊升級成 BUG()。
    unsafe { bindings::rex_driver_try_recover() };
    unsafe { bindings::BUG() };
}
```

沒有武裝 recovery 點的 panic 行為**完全不變**。另外註冊
`pub mod rex_recover;`。

#### `rust/bindings/bindings_helper.h`

加入 `#include <linux/rex_driver_recover.h>`,讓 bindgen 產生
`rex_driver_protected_call` / `rex_driver_try_recover` 的 Rust
bindings。

#### `tools/objtool/noreturns.h`

登記 `NORETURN(rex_driver_recovery_landing)`(比照既有的
`rex_landingpad` / `rex_landingpad_asm`),避免 objtool 對 noreturn
呼叫之後的 unreachable code 誤報。

## Demo 與驗證

`samples/guarded_driver/`:driver 與 `baseline_driver` 帶著一字不差
的越界 bug(write ≥ 32 bytes panic),唯一差別是 buggy 區段包進
`protected_call`。已接 sanity test:

```sh
meson test -C build guarded_driver_test
```

QEMU 實測 console(2026-06-11):

```text
rex_guarded: write count=17 class=4 weight=4 total=73
rust_kernel: panicked at rex_guarded_main.rs:92:26:
rex: recovered Rust driver panic in event-trigger[152]; protected call returns -5
rex_guarded: write count=9 class=2 weight=2 total=91

[trigger] write 40 bytes  -> errno=5 (Input/output error)  PASS
[trigger] ALL CHECKS PASSED — in-driver panic was contained, kernel survived
```

同一筆 write 在 `baseline_driver` 的結尾是
`Kernel panic - not syncing: Fatal exception`。

## 已知限制(後續工作)

1. **沒有資源 cleanup(最重要)。** longjmp 直接丟棄 panic 點與
   呼叫點之間的所有 frame,期間存活的物件**不會跑 destructor**。
   因此 protected region 內不可以取得任何資源(鎖、heap 配置、
   refcount、register mapping),否則洩漏。guard 只能擋住「會改變
   preempt/irq 狀態」的那一類(spinlock);mutex、`KBox` 配置、
   `ARef` refcount 這些不改變 preempt count 的資源,guard 偵測
   不到。
   **後續工作**:仿照 Rex extension 的 `rex_cleanup_entries`,讓
   Rust-for-Linux 的 RAII 型別(`Guard`、`KBox`、`ARef`、…)在
   protected region 內建構時向 per-task ledger 登記
   `(cleanup_fn, arg)`、drop 時註銷;`rex_driver_try_recover()` 在
   longjmp 前逐一執行。這會把「region 內不可拿資源」的限制換成
   「資源必須來自有登記的 RAII 型別」,和 Rex extension 的信任模型
   一致。
2. **errno 寫死 -EIO。** `REX_DRIVER_RECOVER_ERRNO` 是常數。
   **後續工作**:在 landing 前詢問 policy(per-site errno、
   poisoning、telemetry)。先前 `recovery_policy` sample 的
   kernel-pull 設計(policy 把決定寫進 map,kernel 直接讀)可以
   原封不動接在這裡 —— landingpad 是 trusted kernel code,本來就
   能讀 map 並使用回傳值。
3. **沒有 poisoning / quarantine。** 救回一次之後 driver 內部狀態
   可能已不一致,目前下一筆操作會照常進入 driver。
   **後續工作**:per-site panic 計數,達閾值後在進入點直接拒絕
   (回 -EHWPOISON);或用 vfs 層的 Rex hook(`samples/test` 的
   做法)在 driver 外圍執法。
4. **只接 Rust panic。** 復原路徑掛在 RfL 的 panic handler 上;
   C 程式碼的 oops(野指標、`BUG_ON`)不經過這裡,行為不變。這是
   設計取捨:Rust 的 panic 是語言保證的受控路徑(bounds check、
   `unwrap`、顯式 `panic!`),從定義上不涉及記憶體損壞,救回才有
   意義。
5. **panic 訊息仍走 `pr_emerg`。** 被復原的 panic 也會先印
   emergency 等級的訊息(目前刻意保留,方便 demo 與除錯);未來可
   降級或併入 telemetry。
6. **x86-64 only。** asm 只有 x86-64 版本,與本 fork 的支援範圍
   一致。
7. **guard 與 `CONFIG_PREEMPT_COUNT` 的耦合。** preempt-count guard
   假設 spinlock 會增加 preempt count,但這只在
   `CONFIG_PREEMPT_COUNT=y` 時成立 —— 而**本 fork 目前的 config
   (`CONFIG_PREEMPT_NONE=y`,未選任何會 select PREEMPT_COUNT 的
   選項)其實是關的**。也就是說在現行組態下:
   - `irqs_disabled()` 檢查仍有效(`spin_lock_irqsave` / 關中斷
     會被抓到);
   - hardirq/softirq 巢狀仍由 `in_task()` 擋掉;
   - 但 region 內持有**普通 `spin_lock`** 不會被偵測,復原會把鎖
     洩漏。
   這讓「protected region 內不可拿資源」目前只能靠紀律遵守。
   **後續工作**:開 `CONFIG_PREEMPT_COUNT`(或 `DEBUG_ATOMIC_SLEEP`)
   讓 guard 完整生效,或整合 lockdep 在復原前檢查 held locks。
