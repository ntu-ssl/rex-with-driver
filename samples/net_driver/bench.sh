#!/bin/bash
# Runs inside the QEMU guest. TX-datapath efficiency benchmark for the Rex
# network driver, using the in-kernel packet generator (pktgen) so no syscall
# or copy overhead pollutes the numbers.
#
# Four configurations are measured with identical traffic:
#   1. dummy0            — stock kernel virtual device, the no-Rex baseline
#   2. rexnet0 (no ext)  — cost of the instrumented driver alone (dispatch
#                          call + verdict counters), no extension attached
#   3. rexnet0 (Rex ext, int3 kprobe) — full path: int3 kprobe -> Rex program
#                          (map counters + bpf_override_return), logging off
#   4. rexnet0 (Rex ext, optimized kprobe) — informational: jump-optimized
#                          kprobe, monitoring only (override is ignored there)
#
# Each configuration runs TRIALS times for every size in PKT_SIZES.
# Results are echoed to the console and appended to
# $KERNEL/net-bench-results.txt ($KERNEL = build/linux on the host, the only
# writable host mount).
set -x
REPO=$(realpath "$(dirname "$0")/../..")
KO=$REPO/samples/net_driver/driver/rex_net.ko
PKTGEN=$KERNEL/net/core/pktgen.ko
OUT=$KERNEL/net-bench-results.txt
COUNT=${COUNT:-50000}
TRIALS=${TRIALS:-5}
PKT_SIZES=${PKT_SIZES:-"64 1500"}

cd $REPO/build/samples/net_driver || exit 0
: > "$OUT"

log() { echo "$@" | tee -a "$OUT"; }

pgset() { echo "$1" > "$2"; }

# run_pktgen <tag> <dev>: TRIALS x PKT_SIZES pktgen runs on <dev>; one
# "RESULT tag=<tag> size=<n> trial=<n> usec=<n> count=<n>" line per run.
run_pktgen() {
    local tag=$1 dev=$2 size trial res usec
    pgset "rem_device_all" /proc/net/pktgen/kpktgend_0
    pgset "add_device $dev" /proc/net/pktgen/kpktgend_0
    for size in $PKT_SIZES; do
        pgset "count $COUNT" /proc/net/pktgen/$dev
        pgset "pkt_size $size" /proc/net/pktgen/$dev
        pgset "clone_skb 1000" /proc/net/pktgen/$dev
        pgset "delay 0" /proc/net/pktgen/$dev
        pgset "dst 10.0.99.2" /proc/net/pktgen/$dev
        pgset "dst_mac 02:00:00:00:00:02" /proc/net/pktgen/$dev
        for trial in $(seq 1 $TRIALS); do
            pgset "start" /proc/net/pktgen/pgctrl   # blocks until done
            res=$(grep -E "^Result: OK" /proc/net/pktgen/$dev)
            usec=$(echo "$res" | grep -oP 'OK: \K[0-9]+')
            log "RESULT tag=$tag size=$size trial=$trial usec=${usec:-NA} count=$COUNT"
        done
    done
}

log "==== net_driver TX benchmark ===="
log "INFO kernel=$(uname -r) cpus=$(nproc) count=$COUNT trials=$TRIALS sizes='$PKT_SIZES'"

insmod "$PKTGEN" || { log "BENCH_ABORT pktgen.ko failed to load"; exit 0; }
insmod "$KO" || { log "BENCH_ABORT rex_net.ko failed to load"; exit 0; }

ip link add dummy0 type dummy
ip link set dummy0 up
ip link set rexnet0 up
ip -br link show dummy0 rexnet0

log "==== BENCH 1: dummy0 (stock baseline, no Rex) ===="
run_pktgen dummy0 dummy0

log "==== BENCH 2: rexnet0, hook point present, no extension ===="
run_pktgen rexnet0-noext rexnet0

log "==== BENCH 3: rexnet0, Rex extension attached (int3 kprobe, override) ===="
echo 0 > /proc/sys/debug/kprobes-optimization
./loader --quiet > /tmp/bench_loader.log 2>&1 &
LPID=$!
sleep 3
run_pktgen rexnet0-rex-int3 rexnet0
kill -TERM $LPID
sleep 1
grep -E 'STAT_|quiet' /tmp/bench_loader.log | tee -a "$OUT"

log "==== BENCH 4: rexnet0, Rex extension, jump-optimized kprobe (monitor only) ===="
echo 1 > /proc/sys/debug/kprobes-optimization
./loader --quiet > /tmp/bench_loader2.log 2>&1 &
LPID=$!
sleep 3   # registration + async optimization
run_pktgen rexnet0-rex-optprobe rexnet0
kill -TERM $LPID
sleep 1
grep -E 'STAT_|quiet' /tmp/bench_loader2.log | tee -a "$OUT"

log "==== driver counters ===="
rmmod rex_net
dmesg | grep -oE 'tx_pass=[0-9]+ tx_drop=[0-9]+' | tail -1 | tee -a "$OUT"

log "BENCH_DONE"
exit 0
