# net_driver integration test — Apache/HTTP over the rexnet pair

End-to-end test of the Rex hook-point driver model
([`samples/net_driver`](../../samples/net_driver)) under a real application
workload: Apache httpd served across the `rexnet0` ⟷ `rexnet1` pair, with a
Rex extension ruling on every transmitted packet.

Raw data: [`net-driver-integration-raw-20260613.txt`](net-driver-integration-raw-20260613.txt)
(produced by `samples/net_driver/integration_test.sh`).

Complements the synthetic TX microbenchmark in
[net-driver-tx.md](net-driver-tx.md): that one isolates per-packet hook cost
with pktgen; this one shows what that cost means for actual TCP/HTTP traffic.

## Setup

The driver registers a **cross-connected pair** of virtual Ethernet devices
(veth-style): a packet transmitted on one side passes through
`rex_net_dispatch()` (the Rex hook point) and, on a PASS verdict, is delivered
to the peer's receive path via `dev_forward_skb()`. Real protocols — ARP,
ICMP, TCP — work across the pair, and an attached extension sees *every*
packet of the conversation (both directions, since both devices share the
hook).

```
root netns                                netns "peer"
rexnet0 10.0.99.1/24  ⟷ (rex_net.ko) ⟷  rexnet1 10.0.99.2/24
curl / ab / iperf3 -c                     Apache httpd 2.4.68 :8080, iperf3 -s
```

The attached extension is the sample policy from
`samples/net_driver/src/main.rs`: **DROP ARP, PASS everything else**, attached
via an int3 kprobe with `bpf_override_return` (logging off, `./loader
--quiet`).

### Environment ⚠️

Kernel `6.19.0-rex+`, QEMU guest 4 vCPU / 8 GB via
`scripts/q-script/nix-q-tcg` — **TCG emulation (no KVM)**, so absolute
numbers are emulation-inflated; relative comparisons are the meaningful
result. Server: Apache httpd 2.4.68 (nixpkgs, event MPM); load: ApacheBench
2.4.68, iperf3 3.21.

## Functional results (2026-06-13)

| Check | Extension | Result |
|---|---|---|
| ARP resolution + ping across the pair | none | ✅ works |
| HTTP GET, content verified; 64 KiB body intact | none | ✅ works |
| ping after neighbor flush | attached | ✅ **fails as intended** — extension drops ARP (`STAT_arp=4`, matches driver `tx_drop=4`) |
| ping / HTTP GET with static neighbor entries | attached | ✅ works — IPv4 PASSes while the ARP policy stays active |

The extension's drop counter, the driver's `tx_drop` counter, and the
observed connectivity loss all agree — the verdict path
(kprobe → Rex program → `bpf_override_return` → driver drop) is exercised and
correct under real traffic, not just synthetic packets.

## Performance results (2026-06-13)

3 trials per configuration; identical ARP-free traffic (static neighbor
entries in both configs, so the attached extension is the only variable).

| Benchmark | No extension | Rex extension (int3, override) | Δ |
|---|---|---|---|
| ApacheBench, 10,000 req × 3, keepalive, concurrency 8 | 4839 ± 55 req/s | 4798 ± 17 req/s | **−0.9%** (within noise) |
| iperf3 bulk TCP, 10 s × 3 | 1.363 ± 0.014 Gbit/s | 1.160 ± 0.072 Gbit/s | **−15%** |

During the benchmark phase the extension ruled on **3.17 M packets**
(`STAT_total≈3,175,000`, all PASS, zero false drops); the driver moved 6.89 M
packets across the whole run.

## Takeaways

1. **Request/response workloads don't feel the hook.** An HTTP exchange is a
   handful of packets against ~1.6 ms of httpd service time, so even the
   expensive int3-kprobe path (~1.8 µs/packet, see
   [net-driver-tx.md](net-driver-tx.md)) disappears: −0.9%, within trial
   noise.
2. **Bulk streaming pays the per-packet cost.** iperf3 saturates the pair's
   packet rate, so the per-packet overhead surfaces directly as a −15%
   throughput loss — consistent with the microbenchmark's per-packet numbers.
   The optimization target identified there (replace the int3 kprobe with a
   static-call/callback hook) would recover most of this.
3. **The policy is enforced on real protocols.** ARP genuinely stops
   resolving, IPv4 genuinely flows, and extension, driver, and observed
   behavior agree packet-for-packet (4 drops, all phase-B ARP probes).
4. Counter note: under concurrent multi-CPU TCP the extension's map counters
   show ~0.001% skew between `STAT_total`/`STAT_passed`/`STAT_ipv4`
   (non-atomic read-modify-write per-key updates); pktgen runs (single kernel
   thread) are exact.

## Reproducing

```sh
# prerequisites in the host nix store (guest mounts host / read-only):
nix build nixpkgs#apacheHttpd nixpkgs#iperf3 --no-link

# build samples + driver module (inside `nix develop .#rex`)
meson compile -C build
LLVM=1 make -C linux M=$PWD/samples/net_driver/driver O=$PWD/build/linux modules

# run (TCG; use nix-q on a KVM-capable host)
cd build/linux
../../scripts/q-script/nix-q-tcg arch/x86/boot/bzImage \
    "TRIALS=3 AB_N=10000 IPERF_T=10 bash $PWD/../../samples/net_driver/integration_test.sh"

# results land in build/linux/net-integration-results.txt
```

`TRIALS`, `AB_N`, `AB_C`, `IPERF_T`, and the `HTTPD`/`AB`/`IPERF3` binary
paths are overridable via the environment of `integration_test.sh`.
