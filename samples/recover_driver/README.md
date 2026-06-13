# recover_driver — 路線 A:driver 邏輯放進 Rex 保護邊界

專題大目標的第一個端到端 demo:**driver file operation 的邏輯 panic 時,
userspace 收到一個普通的 errno,kernel 不死**。

做法是把保護邊界反過來用:Rex 的 exception handling 只接得住
「跑在 `rex_dispatcher_func` / Rex stack 上的程式」的 panic,所以乾脆把
*會 panic 的 driver 邏輯*整個搬進 Rex extension,留在 kernel 裡的 driver
只是一個不會 panic 的 thin shim。

```text
write(2) ─► /dev/rex_recover (thin shim, driver/)
              │
              ▼
            rex_recover_dispatch(op, count, offset)
              │ kprobe 進入點 ─► extension(src/main.rs)= 真正的邏輯
              │    INFLIGHT[pid]=1 … 邏輯 … RESULT[pid]=val (commit)
              │    ↑ panic 發生在 commit 之前,被 Rex landingpad 接住
              ▼
            dispatch body(C shim)consume 兩張 map,三態判斷:
              有 RESULT          → 邏輯完成,用它當回傳值
              只有 INFLIGHT      → 邏輯 panic 了 → -EIO ← recovery!
              兩者皆無           → 沒掛 extension → -ENXIO
              │
              ▼
            write(2) 把負回傳值轉成 errno 給 userspace
```

## 組成

| 檔案 | 角色 |
|---|---|
| `src/main.rs` | **driver 邏輯本體**(Rex kprobe 程式),蓄意留一個 bounds bug:write ≥ 32 bytes 觸發 Rust panic |
| `driver/rex_recover_main.rs` | thin shim(Rust kernel module,`/dev/rex_recover`),提供 `rex_recover_dispatch` hook point |
| `driver/rex_recover_shim.c` | 同 module 的 C shim,負責讀/consume INFLIGHT/RESULT map(RfL 沒有 BPF map 綁定;比照 in-tree `rust_print` 的 .rs + .c 同 module 做法) |
| `loader.c` | 載入並掛上邏輯、用 ioctl 把兩張 map 的 fd 註冊給 driver |
| `event-trigger.c` | 走正常 → panic → 復原的完整劇本,逐項 PASS/FAIL |

## 協議設計重點

1. **Commit semantics**:`RESULT[pid]` 的寫入是成功路徑的*最後一步*。
   panic 一定發生在 commit 之前,所以「INFLIGHT 在、RESULT 不在」是
   panic 的可靠訊號,不需要 kernel 告訴我們發生過 panic。
2. **不用 `bpf_override_return`**:優化過的 kprobe(optprobe)會默默
   忽略它的 `regs->ip` 改寫。改用 kernel pull —— dispatch 自己的回傳值
   承載決定,與 kprobe 優化完全無關。
3. **狀態一致性**:extension 的內部狀態(`TOTAL` map)更新排在
   會 panic 的運算之後、commit 之前;panic 時本次累計不會發生,
   狀態不會半套。
4. **每次 consume**:dispatch body 讀完即刪兩張 map entry,殘留狀態
   不可能影響下一次操作。
5. **loader 必須接住 SIGSYS**:Rex 的 `rex_landingpad` 在接住 panic 後
   會對 loader process 發 SIGSYS(fail-stop 預設:loader 沒處理就會
   被殺,bpf link 隨之關閉、extension 自動 detach,之後的操作全變
   -ENXIO)。本 sample 要的是「panic 後繼續服務」,所以 loader 裝了
   一個真的 signal handler(注意 SIG_IGN 沒用:kernel 走 `force_sig`,
   ignore 會被重設成 SIG_DFL 照樣死;裝 handler 才會被尊重)。
   這也是未來 kernel 端可以做成 per-program policy 的點。

## 執行(VM 內)

```sh
cd ../samples/recover_driver

# 0. 編 driver module(第一次;在 driver/ 內 make,
#    等同 make LLVM=1 -C ../../../linux M=$PWD)
make -C driver

# 1. 載入 thin shim(提供 kprobe 目標符號,必須先做)
insmod driver/rex_recover.ko

# 2. 載入並掛上 driver 邏輯
./loader &

# 3. 跑劇本
./event-trigger
```

預期輸出:

```text
[trigger] write 5 bytes   -> ret=5  PASS
[trigger] write 17 bytes  -> ret=17  PASS
[trigger] write 40 bytes  -> errno=5 (Input/output error)  PASS
[trigger] write 9 bytes   -> ret=9  PASS
[trigger] read 16 bytes   -> ret=0  PASS
[trigger] ALL CHECKS PASSED — panic was contained, kernel survived
```

40-byte write 那次,dmesg 會看到 Rex landingpad 的 panic 報告
(`rex: Panic from Rex prog: index out of bounds …`)和 shim 的
`rex_recover: logic panicked mid-operation; recovered, returning -EIO`,
然後系統照常運作 —— 同樣的 bug 若寫在 driver 本體,就是一次
kernel `BUG()`。

沒跑 `./loader` 時,每個 read/write 都回 `-ENXIO`(「沒有邏輯」),
是保守的 fail-closed 行為。

## 已知限制(也是後續路線 B 的動機)

- 這不是「救回既有 driver」:邏輯必須改寫成 Rex extension,受限於
  Rex 的 API(不能碰任意 kernel 資源、不能 sleep),適合邏輯型 driver
  (協議處理、狀態機、policy),不適合直接操作硬體的 driver。
- `INFLIGHT` 的寫入本身若失敗(map 滿),panic 會被誤判成
  「沒掛 extension」(-ENXIO 而非 -EIO);對 demo 而言可接受。
- read 路徑尚未真的搬資料(需要 `bpf_probe_write_user`),目前一律
  EOF。
