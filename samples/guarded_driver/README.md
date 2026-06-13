# guarded_driver — 路線 B:bug 留在 driver 本體,由 kernel 救回

三部曲的第三段。bug **和 `baseline_driver` 一字不差地留在 driver 的
`write_iter` 本體裡**,但會 panic 的區段跑在 kernel 端新增的 recovery
trampoline 之下:panic 不再升級成 `BUG()`,而是 longjmp 回呼叫點、
讓 file operation 回傳 `-EIO`。**不需要 Rex extension、不需要 loader**
—— 復原由 kernel 自己完成。

| | baseline_driver | recover_driver(路線 A) | guarded_driver(路線 B) |
|---|---|---|---|
| bug 位置 | driver 本體 | Rex extension | **driver 本體** |
| 保護機制 | 無 | Rex EH(kprobe + maps) | **kernel trampoline** |
| write 40 bytes | 整機 kernel panic | errno=EIO | **errno=EIO** |
| 需要改寫 driver 邏輯 | — | 要(搬進 extension) | 只要包一層 closure |

## kernel 端機制(本 fork 對 linux/ 的新增)

```text
write_iter
  └─ kernel::rex_recover::protected_call(closure)   rust/kernel/rex_recover.rs
       └─ rex_driver_protected_call(shim, &slot)    arch/x86/net/rex.c
            ├─ 武裝 current->rex_recovery_ctx(per-task setjmp 點)
            └─ __rex_driver_protected_call           arch/x86/net/rex_64.S
                 ├─ 存 callee-saved regs + rsp 進 ctx
                 └─ call closure ──► panic!
                                       └─ RfL panic handler(rust/kernel/lib.rs)
                                            └─ rex_driver_try_recover()
                                                 ├─ guard 檢查(見下)
                                                 └─ rex_driver_recovery_landing
                                                      還原 regs/rsp,
                                                      以 -EIO「返回」呼叫點
```

與 Rex extension 的 `rex_dispatcher_func` 機制的差異:

- **不換 stack**:driver 跑在普通 kernel stack 的(可 sleep 的)
  process context,共用 per-CPU stack 不可行,所以 recovery 點掛在
  per-task 的 `current->rex_recovery_ctx`(`task_struct` 新欄位,
  fork 時清空)。
- **支援巢狀**:protected_call 進入時保存外層 ctx、離開時還原。

### Guard 檢查(拒絕不安全的復原)

`rex_driver_try_recover()` 在跳之前檢查,不過就 fall through 回原本的
`BUG()`:

1. 只在 task context 復原(irq/softirq/NMI 裡的 panic 不屬於
   protected call)。
2. `preempt_count` 或 irq 狀態和武裝時不一致 → 拒絕(代表 protected
   region 裡拿了鎖/關了中斷,longjmp 會把它們洩漏掉)。

### 目前的限制(= 後續工作)

- **沒有 cleanup**:panic 當下 protected region 內存活的物件不會跑
  destructor。所以 region 內**不可以取得資源**(鎖、配置、refcount),
  否則洩漏。把 cleanup ledger 接上 RfL 的 RAII 型別(`Guard`、`KBox`、
  `ARef` 在 protected region 內建構時登記 cleanup entry)是下一步。
- errno 固定 -EIO;之後可以接 `recovery_policy` 那支 policy 程式來
  決定 errno / poisoning。
- 只接 Rust panic(經 RfL panic handler);C 端的 oops 不在範圍內。

## 執行

```sh
# 自動(host 端,會自己編 .ko、開 QEMU 驗證):
meson test -C build guarded_driver_test

# 或在 VM 內手動:
cd ../samples/guarded_driver
insmod driver/rex_guarded.ko
./event-trigger
```

預期輸出:

```text
[trigger] write 5 bytes   -> ret=5  PASS
[trigger] write 17 bytes  -> ret=17  PASS
[trigger] write 40 bytes  -> errno=5 (Input/output error)  PASS
[trigger] write 9 bytes   -> ret=9  PASS
[trigger] read 16 bytes   -> ret=0  PASS
[trigger] ALL CHECKS PASSED — in-driver panic was contained, kernel survived
```

40-byte write 時 dmesg 會看到 RfL 的 panic 訊息(index out of bounds)
緊接著 `rex: recovered Rust driver panic in event-trigger[...]`,然後
系統照常運作 —— 對照 `baseline_driver` 同一筆 write 的
`Kernel panic - not syncing`。
