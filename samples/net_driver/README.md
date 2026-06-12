# net_driver — a Rust network driver controllable by Rex

This sample ports a **network driver** to the Rex hook-point model used by
[`samples/fwd_driver`](../fwd_driver). Where `fwd_driver` forwards file
operations (read/write/open/release) through a Rex-controllable dispatch
function, `net_driver` does the same for the **network transmit datapath**:
every packet a virtual Ethernet interface sends is forwarded to a hookable
function that a loaded Rex eBPF extension can monitor and override.

## Components

| File | Role |
|------|------|
| `driver/rex_net_main.rs` | Rust kernel module. Registers the `rexnet0` virtual Ethernet device, owns the transmit logic and the `rex_net_dispatch` hook point. |
| `driver/rex_net_glue.c` | Tiny C ABI shim for the `ndo_*` callbacks (see *kCFI* below). |
| `src/main.rs` | Rex extension. Kprobes `rex_net_dispatch`; counts packets, and drops ARP via `bpf_override_return`. |
| `loader.c` | Loads/attaches the extension and streams its trace output. |
| `guest_test.sh` / `tests/runtest.py` | End-to-end in-VM test. |

## Dispatch protocol

The driver calls, once per transmitted packet:

```
rex_net_dispatch(op: u64, len: u64, proto: u64) -> i64
  rdi = op     1 = xmit
  rsi = len    skb->len (bytes)
  rdx = proto  EtherType, host byte order
```

The return value decides the packet's fate:

| return | meaning | driver action |
|--------|---------|---------------|
| `-38` (`-ENOSYS`) | no extension loaded | transmit (counted PASS) |
| `>= 0` | Rex: PASS | transmit (counted PASS) |
| `< 0` (≠ `-38`) | Rex: DROP | drop (counted DROP) |

The driver keeps `tx_pass`/`tx_drop` counters (printed on unload) so Rex's
effect on the datapath is observable independently of the extension.

## Two things worth knowing

These are the reasons this sample is more than a copy of `fwd_driver`:

1. **kCFI and indirect calls.** The kernel is built with kCFI
   (`CONFIG_CFI=y`). A netdev's `ndo_start_xmit` is called *indirectly* through
   a C function pointer, and the call site checks the target's kCFI type-id.
   `ndo_start_xmit` returns `netdev_tx_t` (a C `enum`), which bindgen flattens
   to `c_int` on the Rust side; rustc's type-id for an `int` return does not
   match clang's id for the `enum` return, so a Rust function assigned straight
   into `ndo_start_xmit` traps with "invalid opcode". The `ndo_*` callbacks
   therefore live in `rex_net_glue.c` (compiled by clang → correct ids) and
   forward to the Rust logic via a *direct* call, which is not kCFI-checked.
   `fwd_driver` never hit this because its hook point is only ever called
   directly.

2. **`bpf_override_return` needs non-optimized kprobes.** Rex implements the
   override by setting `regs->ip` to `just_return_func`. An *optimized*
   (jmp-based) kprobe does not re-read `regs->ip` after the handler, so the
   override is silently ignored and the driver sees the default return. The
   test disables kprobe optimization first:

   ```sh
   echo 0 > /proc/sys/debug/kprobes-optimization
   ```

## Run it

In the Nix dev shell, after `meson compile -C build`:

```sh
# build the kernel module against the configured kernel
make -C linux M=$(pwd)/samples/net_driver/driver \
     O=$(pwd)/build/linux modules LLVM=1

# boot the VM (KVM: scripts/q-script/nix-q, or the TCG fallback nix-q-tcg)
cd build/linux
../../scripts/q-script/nix-q-tcg arch/x86/boot/bzImage \
    "bash $(pwd)/../samples/net_driver/guest_test.sh"
```

Inside the VM the test loads the driver, brings up `rexnet0`, loads the Rex
extension, generates ICMP (PASS) and ARP (DROP) traffic, triggers a deliberate
out-of-bounds panic inside the extension (caught by Rex; the kernel keeps
running), and prints `NET_RESULT=success` when all checks pass.
