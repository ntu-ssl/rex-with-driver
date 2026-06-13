#!/bin/python

import subprocess

# Runs inside the QEMU VM with cwd = the sample's build dir.
#
# This is the *baseline / control* experiment: the bounds bug lives in the
# driver body, so the expected outcome is a kernel panic — the VM dies
# mid-run and never reaches poweroff.  It is intentionally NOT wired into
# `meson test`; run it manually:
#
#   cd build/linux
#   ../../scripts/q-script/sanity-test-q \
#       -t ../samples/baseline_driver/tests/runtest.py
#
# and watch the console end in "Kernel panic - not syncing".


def main():
    subprocess.run(
        "insmod driver/rex_baseline.ko", shell=True, check=True
    )
    print(
        "[baseline] triggering the bug in the driver body — "
        "expect a kernel panic",
        flush=True,
    )
    subprocess.run("./event-trigger", shell=True)

    # Unreachable on this kernel (CONFIG_PANIC_ON_OOPS=y, oops=panic).
    print("[baseline] UNEXPECTED: VM survived event-trigger", flush=True)
    with open("auto_grade.txt", "w") as grade_file:
        grade_file.write("survived")


if __name__ == "__main__":
    main()
