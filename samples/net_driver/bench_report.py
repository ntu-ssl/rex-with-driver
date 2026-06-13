#!/usr/bin/env python3
"""Summarize net-bench-results.txt into a markdown table.

Usage: bench_report.py <net-bench-results.txt>

Reads the "RESULT tag=... size=... trial=... usec=... count=..." lines
emitted by bench.sh and prints, per (tag, size): mean/stdev of ns/packet
and packets/sec across trials.
"""

import re
import statistics
import sys
from collections import defaultdict

LABELS = {
    "dummy0": "`dummy0` (stock virtual device, no Rex)",
    "rexnet0-noext": "`rexnet0`, hook point, no extension",
    "rexnet0-rex-int3": "`rexnet0` + Rex ext (int3 kprobe, override)",
    "rexnet0-rex-optprobe": "`rexnet0` + Rex ext (optimized kprobe, monitor)",
}


def main(path: str) -> None:
    runs = defaultdict(list)  # (tag, size) -> [usec, ...]
    counts = {}
    for line in open(path):
        m = re.match(
            r"RESULT tag=(\S+) size=(\d+) trial=\d+ usec=(\d+) count=(\d+)",
            line,
        )
        if m:
            tag, size, usec, count = m.groups()
            runs[(tag, int(size))].append(int(usec))
            counts[(tag, int(size))] = int(count)

    print(
        "| Configuration | Pkt size | ns/packet (mean ± stdev) | kpps (mean) |"
    )
    print("|---|---|---|---|")
    base = {}  # size -> mean ns/pkt of dummy0, for the overhead column
    for (tag, size), usecs in runs.items():
        count = counts[(tag, size)]
        ns = [u * 1000 / count for u in usecs]
        mean, stdev = statistics.mean(ns), statistics.stdev(ns)
        if tag == "dummy0":
            base[size] = mean
        kpps = 1e6 / mean
        label = LABELS.get(tag, tag)
        print(f"| {label} | {size}B | {mean:.0f} ± {stdev:.0f} | {kpps:.0f} |")


if __name__ == "__main__":
    main(sys.argv[1])
