#!/bin/bash
# Runs inside the QEMU guest. Exercises the Rex network driver end to end:
#   monitoring, protocol-based drop control, and panic recovery.
set -x
KO=/home/mtmatt/rex-with-driver/samples/net_driver/driver/rex_net.ko
cd /home/mtmatt/rex-with-driver/build/samples/net_driver

echo "==== STEP 1: load driver ===="
insmod "$KO"
grep -m1 rex_net_dispatch /proc/kallsyms
ip link show rexnet0 || { echo "NETDEV_MISSING"; }

echo "==== STEP 2: configure interface ===="
ip addr add 10.0.99.1/24 dev rexnet0
ip link set rexnet0 up
ip -br addr show rexnet0
# Static neighbour so ICMP to .2 is transmitted directly (proto IPv4 -> PASS).
ip neigh replace 10.0.99.2 lladdr 02:00:00:00:00:02 dev rexnet0 nud permanent

echo "==== STEP 3: load Rex extension ===="
# Rex's bpf_override_return redirects the probed function's return by setting
# regs->ip; an *optimized* (jmp-based) kprobe ignores that change, so disable
# kprobe optimization to make int3-based probes honour the override.
echo 0 > /proc/sys/debug/kprobes-optimization
cat /proc/sys/debug/kprobes-optimization
./loader > /tmp/net_loader.log 2>/tmp/net_loader.err &
LPID=$!
sleep 3
bpftool prog show | grep -c name
cat /tmp/net_loader.err

echo "==== STEP 4: generate PASS traffic (ICMP to neighbour .2) ===="
ping -c 4 -i 0.3 -W 1 10.0.99.2 ; true

echo "==== STEP 5: generate DROP traffic (ARP for unresolved .3) ===="
ping -c 3 -i 0.3 -W 1 10.0.99.3 ; true

echo "==== STEP 6: trigger Rex panic (len==1000) and prove recovery ===="
ping -c 2 -i 0.3 -W 1 -s 958 10.0.99.2 ; true
# Kernel must still be alive: do more normal traffic afterwards.
ping -c 3 -i 0.3 -W 1 10.0.99.2 ; true
echo "KERNEL_ALIVE_AFTER_PANIC=yes"

echo "==== STEP 7: dump Rex stats ===="
kill -TERM $LPID
sleep 1
cat /tmp/net_loader.log

echo "==== STEP 8: interface tx stats ===="
ip -s link show rexnet0

echo "==== STEP 9: unload driver (prints driver-side counters) ===="
rmmod rex_net
dmesg | grep -E "rex_net" | tail -8

echo "==== EVALUATE ===="
# Driver-side counters are the definitive proof that Rex's verdict reached the
# datapath: tx_pass = packets Rex allowed, tx_drop = packets Rex dropped.
DRV=$(dmesg | grep -oE 'tx_pass=[0-9]+ tx_drop=[0-9]+' | tail -1)
TXPASS=$(echo "$DRV" | grep -oP 'tx_pass=\K[0-9]+')
TXDROP=$(echo "$DRV" | grep -oP 'tx_drop=\K[0-9]+')
# Rex extension trace: confirms per-packet monitoring + per-protocol decisions.
TRACE_PASS=$(grep -c 'rex_net\] PASS proto=0x800' /tmp/net_loader.log)
TRACE_DROP=$(grep -c 'rex_net\] DROP arp' /tmp/net_loader.log)
# Best-effort Rex map readout (informational).
grep -E 'STAT_' /tmp/net_loader.log || echo "(map dump unavailable)"
echo "EVAL tx_pass=$TXPASS tx_drop=$TXDROP trace_pass=$TRACE_PASS trace_drop=$TRACE_DROP"

ok=1
[ "${TXPASS:-0}" -gt 0 ] || ok=0           # Rex allowed packets through
[ "${TXDROP:-0}" -gt 0 ] || ok=0           # Rex dropped packets (override took effect)
[ "${TRACE_PASS:-0}" -gt 0 ] || ok=0       # monitoring saw IPv4
[ "${TRACE_DROP:-0}" -gt 0 ] || ok=0       # monitoring saw + dropped ARP
if [ "$ok" = 1 ]; then echo "NET_RESULT=success"; else echo "NET_RESULT=fail"; fi
