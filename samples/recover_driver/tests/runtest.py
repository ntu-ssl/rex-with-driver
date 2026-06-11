#!/bin/python

import subprocess
from time import sleep

# Runs inside the QEMU VM with cwd = the sample's build dir.
#
# End-to-end check of the crash-recovery story:
#   insmod the thin shim, attach the Rex extension (the driver logic),
#   then let event-trigger exercise normal writes, a panic-inducing write
#   (caught by Rex EH, surfaced as -EIO) and a post-recovery write.
# event-trigger exits 0 and prints ALL CHECKS PASSED iff every step
# behaved as expected.

loader = None


def count_bpf_programs():
    try:
        result = subprocess.run(
            "bpftool prog show",
            capture_output=True,
            shell=True,
            text=True,
        )
        if result.stdout:
            output = result.stdout.strip().split("\n")
            return len([line for line in output if "name" in line])
        return 0
    except Exception as e:
        print(f"bpftool failed: {e}")
        return 0


def run() -> bool:
    global loader

    subprocess.run(
        "insmod driver/rex_recover.ko", shell=True, check=True
    )

    old_prog_num = count_bpf_programs()
    loader = subprocess.Popen(
        ["./loader"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    # Wait for the extension to be attached ...
    for _ in range(8):
        if count_bpf_programs() != old_prog_num:
            break
        sleep(1)
    # ... and give the loader a moment to register the maps via ioctl.
    sleep(1)

    result = subprocess.run(
        "./event-trigger", shell=True, capture_output=True, text=True
    )
    print(result.stdout)
    print(result.stderr)

    return result.returncode == 0 and "ALL CHECKS PASSED" in result.stdout


def main():
    grade = "fail"
    try:
        if run():
            print("Success")
            grade = "success"
        else:
            print("Failed")
    except Exception as e:
        print(f"test error: {e}")
    finally:
        if loader is not None:
            loader.kill()

    with open("auto_grade.txt", "w") as grade_file:
        grade_file.write(grade)


if __name__ == "__main__":
    main()
