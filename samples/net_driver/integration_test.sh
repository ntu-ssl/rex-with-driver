#!/bin/bash
# Runs inside the QEMU guest. End-to-end integration test for the Rex network
# driver pair (rexnet0 ⟷ rexnet1): real TCP/HTTP traffic through the hooked
# TX datapath, served by Apache httpd, loaded with ApacheBench and iperf3.
#
# Topology:
#   root netns                         netns "peer"
#   rexnet0 10.0.99.1/24  ⟷ (driver) ⟷  rexnet1 10.0.99.2/24
#   curl / ab / iperf3 -c              httpd :8080, iperf3 -s
#
# Every packet either side transmits goes through rex_net_dispatch(), so an
# attached Rex extension sees (and rules on) the entire conversation.
#
# Phases:
#   A. functional, no extension   — ARP/ping, HTTP GET (curl vs known content)
#   B. functional, extension on   — ARP is DROPPED (ping fails after neigh
#      flush), IPv4 PASSes (HTTP works once static neigh entries are set)
#   C. benchmark                  — ab requests/sec and iperf3 throughput,
#      no-ext vs ext (int3 kprobe + bpf_override_return), TRIALS each
#
# Results land in $KERNEL/net-integration-results.txt ($KERNEL = build/linux
# on the host, the only writable host mount).
set -x
REPO=$(realpath "$(dirname "$0")/../..")
KO=$REPO/samples/net_driver/driver/rex_net.ko
OUT=$KERNEL/net-integration-results.txt
TRIALS=${TRIALS:-3}
AB_N=${AB_N:-2000}        # requests per ab trial
AB_C=${AB_C:-8}           # ab concurrency
IPERF_T=${IPERF_T:-5}     # seconds per iperf3 trial

# Server/loadgen binaries from the host nix store (mounted read-only in the
# guest). Env-overridable; globbed so store hashes don't need hardcoding.
HTTPD=${HTTPD:-$(ls -d /nix/store/*-apache-httpd-*/bin/httpd 2>/dev/null | head -1)}
AB=${AB:-$(ls -d /nix/store/*-apache-httpd-*/bin/ab 2>/dev/null | head -1)}
IPERF3=${IPERF3:-$(ls -d /nix/store/*-iperf-*/bin/iperf3 2>/dev/null | head -1)}

cd $REPO/build/samples/net_driver || exit 0
: > "$OUT"

log() { echo "$@" | tee -a "$OUT"; }
fail() { log "FAIL $*"; }
ok() { log "OK $*"; }

log "==== net_driver integration test (Apache/HTTP over rexnet pair) ===="
log "INFO kernel=$(uname -r) cpus=$(nproc) trials=$TRIALS ab_n=$AB_N ab_c=$AB_C iperf_t=${IPERF_T}s"
log "INFO httpd=$HTTPD"
log "INFO iperf3=$IPERF3"

[ -x "$HTTPD" ] || { log "BENCH_ABORT no httpd binary"; exit 0; }

# ── topology ─────────────────────────────────────────────────────────────────
insmod "$KO" || { log "BENCH_ABORT rex_net.ko failed to load"; exit 0; }
ip netns add peer
ip link set rexnet1 netns peer
ip addr add 10.0.99.1/24 dev rexnet0
ip link set rexnet0 up
ip netns exec peer ip addr add 10.0.99.2/24 dev rexnet1
ip netns exec peer ip link set rexnet1 up
ip netns exec peer ip link set lo up
MAC0=$(cat /sys/class/net/rexnet0/address)
MAC1=$(ip netns exec peer cat /sys/class/net/rexnet1/address)
log "INFO rexnet0=$MAC0 rexnet1=$MAC1"

# ── Apache httpd in the peer namespace ───────────────────────────────────────
mkdir -p /tmp/httpd /tmp/www
echo "rex-net-integration-$(date +%s)" > /tmp/www/index.html
head -c 65536 /dev/urandom | base64 | head -c 65536 > /tmp/www/blob64k.bin
MODULES=$(dirname "$(dirname "$HTTPD")")/modules
cat > /tmp/httpd/httpd.conf <<EOF
ServerRoot "/tmp/httpd"
ServerName rexnet-test
PidFile /tmp/httpd/httpd.pid
ErrorLog /tmp/httpd/error.log
Listen 10.0.99.2:8080
LoadModule mpm_event_module $MODULES/mod_mpm_event.so
LoadModule unixd_module $MODULES/mod_unixd.so
LoadModule authz_core_module $MODULES/mod_authz_core.so
User nobody
Group nogroup
DocumentRoot "/tmp/www"
<Directory "/tmp/www">
    Require all granted
</Directory>
EOF
ip netns exec peer "$HTTPD" -f /tmp/httpd/httpd.conf || { log "BENCH_ABORT httpd failed to start"; cat /tmp/httpd/error.log; exit 0; }
sleep 2

URL=http://10.0.99.2:8080/index.html
BLOB=http://10.0.99.2:8080/blob64k.bin

# ── PHASE A: functional, no extension ────────────────────────────────────────
log "==== PHASE A: functional, no Rex extension ===="
if ping -c 3 -W 2 10.0.99.2 > /tmp/ping_a.log 2>&1; then
    ok "A-ping: ARP + ICMP across the pair"
else
    fail "A-ping"; tail -2 /tmp/ping_a.log | tee -a "$OUT"
fi
GOT=$(timeout 20 curl -s "$URL")
WANT=$(cat /tmp/www/index.html)
[ "$GOT" = "$WANT" ] && ok "A-http: GET index.html content matches" || fail "A-http: got '$GOT'"
SZ=$(timeout 30 curl -s "$BLOB" | wc -c)
[ "$SZ" = 65536 ] && ok "A-http-blob: 64KiB body intact" || fail "A-http-blob: $SZ bytes"

# ── PHASE B: functional, Rex extension attached (int3, override) ─────────────
log "==== PHASE B: functional, Rex extension attached ===="
echo 0 > /proc/sys/debug/kprobes-optimization
./loader --quiet > /tmp/loader_b.log 2>&1 &
LPID=$!
sleep 3

ip neigh flush dev rexnet0
ip netns exec peer ip neigh flush dev rexnet1
if ping -c 2 -W 2 10.0.99.2 > /dev/null 2>&1; then
    fail "B-arp-drop: ping succeeded but ARP should be dropped"
else
    ok "B-arp-drop: ARP dropped by extension, ping cannot resolve"
fi

# Static neighbor entries let IPv4 flow while the ARP policy stays active.
ip neigh replace 10.0.99.2 lladdr "$MAC1" dev rexnet0 nud permanent
ip netns exec peer ip neigh replace 10.0.99.1 lladdr "$MAC0" dev rexnet1 nud permanent
ping -c 3 -W 2 10.0.99.2 > /dev/null 2>&1 && ok "B-ping-static: ICMP passes with static neigh" || fail "B-ping-static"
GOT=$(timeout 20 curl -s "$URL")
[ "$GOT" = "$WANT" ] && ok "B-http: HTTP works with extension attached (IPv4 PASS)" || fail "B-http: got '$GOT'"

kill -TERM $LPID
sleep 1
log "---- extension counters after phase B ----"
grep -E 'STAT_' /tmp/loader_b.log | tee -a "$OUT"

# ── PHASE C: benchmarks ──────────────────────────────────────────────────────
# Static neigh entries stay in place so both configs run identical ARP-free
# traffic; the only variable is the attached extension.
run_ab() {  # <cfg>
    local cfg=$1 trial out rps
    for trial in $(seq 1 $TRIALS); do
        out=$(timeout 300 "$AB" -q -k -n $AB_N -c $AB_C "$URL" 2>&1)
        rps=$(echo "$out" | grep -oP 'Requests per second:\s+\K[0-9.]+')
        log "RESULT bench=ab cfg=$cfg trial=$trial rps=${rps:-NA} n=$AB_N c=$AB_C"
    done
}
run_iperf() {  # <cfg>
    local cfg=$1 trial bps
    for trial in $(seq 1 $TRIALS); do
        bps=$(timeout 120 "$IPERF3" -c 10.0.99.2 -t $IPERF_T --json 2>/dev/null |
              python3 -c 'import json,sys; print(int(json.load(sys.stdin)["end"]["sum_received"]["bits_per_second"]))')
        log "RESULT bench=iperf3 cfg=$cfg trial=$trial bps=${bps:-NA} t=$IPERF_T"
    done
}

if [ -x "$IPERF3" ]; then
    ip netns exec peer "$IPERF3" -s -B 10.0.99.2 > /tmp/iperf_srv.log 2>&1 &
    IPERF_SRV=$!
    sleep 2
fi

log "==== PHASE C1: benchmark, no extension ===="
run_ab noext
[ -x "$IPERF3" ] && run_iperf noext

log "==== PHASE C2: benchmark, Rex extension (int3 kprobe, override) ===="
./loader --quiet > /tmp/loader_c.log 2>&1 &
LPID=$!
sleep 3
run_ab rex-int3
[ -x "$IPERF3" ] && run_iperf rex-int3
kill -TERM $LPID
sleep 1
log "---- extension counters after phase C2 ----"
grep -E 'STAT_' /tmp/loader_c.log | tee -a "$OUT"

# ── teardown + driver counters ───────────────────────────────────────────────
[ -n "$IPERF_SRV" ] && kill $IPERF_SRV 2>/dev/null
kill "$(cat /tmp/httpd/httpd.pid 2>/dev/null)" 2>/dev/null
sleep 1
ip netns del peer
sleep 1
rmmod rex_net
log "---- driver counters ----"
dmesg | grep -oE 'tx_pass=[0-9]+ tx_drop=[0-9]+' | tail -1 | tee -a "$OUT"

log "INTEGRATION_DONE"
exit 0
