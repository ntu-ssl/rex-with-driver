# baseline_driver — 對照實驗:同一個 bug,放在 driver 本體

`samples/recover_driver` 的 control experiment。**完全相同的邏輯、完全
相同的 bounds bug**(8 級分級表、開發者假設單次 write < 32 bytes),
但這次直接寫在 driver 的 `write_iter` 本體裡,沒有 Rex 保護:

| | bug 在 Rex extension(`recover_driver`) | bug 在 driver 本體(本 sample) |
|---|---|---|
| write 5 / 17 bytes | ret=5 / ret=17 | ret=5 / ret=17(行為相同) |
| write 40 bytes | **errno=EIO,kernel 活著** | **`BUG()` → oops → 整機 kernel panic** |
| 之後的操作 | 照常服務 | 沒有「之後」 |

panic 路徑:陣列越界 → `panic_bounds_check` → Rust-for-Linux 的
panic handler(`rust/kernel/lib.rs`,印出 panic 訊息後呼叫 `BUG()`)
→ oops。本 repo 的 kernel config 是 `CONFIG_PANIC_ON_OOPS=y`、
q-script 又加了 `oops=panic`,所以 oops 直接升級成整機 panic。
即使在沒有這兩個設定的 kernel 上,結果也只是「好一點的災難」:
寫入的 process 被 SIGKILL(沒有 errno 語意)、kernel 被標記 tainted、
driver 持有的資源全部洩漏。

## 組成

| 檔案 | 角色 |
|---|---|
| `driver/rex_baseline_main.rs` | 帶 bug 的 driver(`/dev/rex_baseline`),邏輯與 recover_driver 的 extension 逐行對應 |
| `event-trigger.c` | 與 recover_driver 相同的 write 劇本;40-byte write 之後的輸出永遠不會出現 |
| `tests/runtest.py` | 手動 q-script 用的劇本(**不接 meson test**,因為預期結果就是 VM 死掉,harness 等不到 auto_grade.txt) |

## 執行

```sh
# host 端編 module
meson compile -C build samples/baseline_driver/baseline_driver-ko:custom

# 自動展示(VM 會死在 console 上,Ctrl-C 離開):
cd build/linux
../../scripts/q-script/sanity-test-q \
    -t ../samples/baseline_driver/tests/runtest.py
```

或在一般 VM 內手動:

```sh
cd ../samples/baseline_driver
insmod driver/rex_baseline.ko
./event-trigger
```

## 預期 console 結尾

```text
[baseline] write  5 bytes -> ret=5
[baseline] write 17 bytes -> ret=17
[baseline] now writing 40 bytes — the bug is in the DRIVER BODY, ...
rust_kernel: panicked at rex_baseline_main.rs:...: index out of bounds: ...
kernel BUG at rust/helpers/bug.c:7!
Oops: invalid opcode: 0000 [#1] SMP
...
Kernel panic - not syncing: Fatal exception
```

對照 `recover_driver` 同一筆 write 的結尾:`errno=5 (Input/output
error)`,然後系統繼續跑。這兩份輸出並排,就是專題的 motivating
result。
