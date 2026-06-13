# net_driver TX-datapath benchmark

Measures the per-packet cost that the Rex hook-point driver model
([`samples/net_driver`](../../samples/net_driver)) adds to a network
transmit path, and the cost of attaching a Rex extension to it.

Raw data: [`net-driver-tx-raw-20260613.txt`](net-driver-tx-raw-20260613.txt)
(produced by `samples/net_driver/bench.sh`, summarized by
`samples/net_driver/bench_report.py`).

## Method

Traffic is generated with the in-kernel packet generator (**pktgen**,
`CONFIG_NET_PKTGEN=m`), which calls the driver's `ndo_start_xmit` directly
from a kernel thread — no syscalls, no copies, no socket layer — so the
measured time is the TX datapath itself. Each run transmits **50,000
packets** (`clone_skb 1000`, `delay 0`); every configuration is run for
**5 trials × 2 packet sizes (64B, 1500B)**. pktgen's own `Result: OK: <usec>`
timing is the measurement.

Four configurations, identical traffic:

| # | Configuration | What it isolates |
|---|---|---|
| 1 | `dummy0` | Stock kernel virtual device — the no-Rex baseline |
| 2 | `rexnet0`, no extension | The instrumented driver alone: direct call to `rex_net_dispatch` (returns `-ENOSYS`) + verdict counters |
| 3 | `rexnet0` + Rex extension, **int3 kprobe** | The full Rex path: kprobe → Rex program → map counters + `bpf_override_return` verdict. Logging disabled (`./loader --quiet`). `kprobes-optimization=0`, required for the override to take effect |
| 4 | `rexnet0` + Rex extension, **jump-optimized kprobe** | Same extension via an optimized (jmp-based) kprobe. Monitor-only: the override is silently ignored in this mode |

Correctness was verified in-band: the extension's map counters saw exactly
500,000 packets per attached configuration (5 × 2 × 50,000) and the driver
reported `tx_pass=1500008 tx_drop=0` across the three `rexnet0`
configurations (pktgen sends IPv4/UDP, which the extension PASSes; the 8
extra packets are stray interface traffic).

### Environment ⚠️

* Kernel `6.19.0-rex+` (Rex-modified), guest: QEMU 4 vCPU / 8 GB,
  booted via `scripts/q-script/nix-q-tcg`.
* **TCG emulation (no KVM)** — absolute numbers are inflated by software
  emulation and the *relative* comparisons are the meaningful result.
  int3 traps are also relatively cheaper under TCG than on real hardware,
  so configuration 3's overhead is, if anything, *understated*.
  Re-run with `scripts/q-script/nix-q` on a KVM-capable setup for
  publishable absolute numbers; the scripts need no changes.

> **Note (2026-06-13):** these numbers were measured when the driver consumed
> every TX packet (single `rexnet0`, no RX side). The driver has since become
> a cross-connected pair (`rexnet0` ⟷ `rexnet1`, see
> [net-driver-integration.md](net-driver-integration.md)); with the peer down
> — as in this benchmark setup — `dev_forward_skb` frees the packet almost as
> early as `consume_skb` did, so the comparison remains representative, but a
> re-run would include one extra branch + peer lookup per packet.

## Results (2026-06-13)

| Configuration | Pkt size | ns/packet (mean ± stdev) | kpps (mean) |
|---|---|---|---|
| `dummy0` (stock virtual device, no Rex) | 64B | 550 ± 70 | 1820 |
| `dummy0` (stock virtual device, no Rex) | 1500B | 467 ± 117 | 2142 |
| `rexnet0`, hook point, no extension | 64B | 688 ± 164 | 1453 |
| `rexnet0`, hook point, no extension | 1500B | 741 ± 142 | 1350 |
| `rexnet0` + Rex ext (int3 kprobe, override) | 64B | 1844 ± 139 | 542 |
| `rexnet0` + Rex ext (int3 kprobe, override) | 1500B | 1817 ± 60 | 550 |
| `rexnet0` + Rex ext (optimized kprobe, monitor) | 64B | 1168 ± 122 | 856 |
| `rexnet0` + Rex ext (optimized kprobe, monitor) | 1500B | 1187 ± 64 | 843 |

Packet size has no effect (the hook passes `len`/`proto` by value and never
touches payload), so averaging both sizes gives the per-packet cost
breakdown:

| Increment | Cost (ns/packet) | Relative throughput |
|---|---|---|
| Stock virtual device | ~510 | 1.00× |
| + hook point & verdict counters (no ext) | +~200 | 0.71× |
| + Rex extension, optimized kprobe (monitor only) | +~460 | 0.43× |
| + Rex extension, int3 kprobe (monitor + override) | +~1120 | 0.28× |

## Takeaways

1. **The hook point itself is cheap.** An unattached `rex_net_dispatch`
   (direct call returning `-ENOSYS`, plus two atomic counters) costs
   ~200 ns/packet under TCG; on real hardware this is a direct call +
   two relaxed atomics, i.e. a handful of cycles.
2. **The kprobe, not the Rex program, dominates attached cost.** The same
   extension costs ~2.4× more via int3 than via the optimized kprobe; the
   difference is purely the trap-based dispatch.
3. **Override requires the expensive probe.** `bpf_override_return` only
   takes effect on non-optimized (int3) kprobes, so today *control* costs
   ~1.1 µs/packet while *pure monitoring* costs ~0.5 µs/packet (TCG
   numbers). A dedicated callback/static-call hook instead of a kprobe
   would close this gap and is the natural next optimization.

## Reproducing

```sh
# one-time: pktgen module (needs an incremental kernel rebuild, since
# enabling NET_PKTGEN also exports a symbol from net/xfrm)
./linux/scripts/config --file build/linux/.config -m NET_PKTGEN
nix develop .#rex --command bash -c \
    'LLVM=1 make -C linux O=$PWD/build/linux olddefconfig &&
     LLVM=1 make -C linux O=$PWD/build/linux -j$(nproc)'

# build samples + driver module (inside `nix develop .#rex`)
meson compile -C build
LLVM=1 make -C linux M=$PWD/samples/net_driver/driver O=$PWD/build/linux modules

# run (TCG; use nix-q on a KVM-capable host)
cd build/linux
../../scripts/q-script/nix-q-tcg arch/x86/boot/bzImage \
    "bash $PWD/../../samples/net_driver/bench.sh"

# summarize (results land in build/linux/net-bench-results.txt)
python3 samples/net_driver/bench_report.py build/linux/net-bench-results.txt
```

`COUNT`, `TRIALS`, and `PKT_SIZES` are overridable via the environment of
`bench.sh`.
