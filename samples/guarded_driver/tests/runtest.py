#!/bin/python

import subprocess

# Runs inside the QEMU VM with cwd = the sample's build dir.
#
# Route B end-to-end check: insmod the guarded driver (the bounds bug is
# in the driver body, wrapped by the kernel recovery trampoline) and let
# event-trigger exercise normal writes, the panic-inducing write (must
# surface as -EIO) and a post-recovery write.  No Rex extension / loader
# involved — the recovery is done by the kernel itself.


def main():
    grade = "fail"
    try:
        subprocess.run(
            "insmod driver/rex_guarded.ko", shell=True, check=True
        )
        result = subprocess.run(
            "./event-trigger", shell=True, capture_output=True, text=True
        )
        print(result.stdout)
        print(result.stderr)
        if (
            result.returncode == 0 and
            "ALL CHECKS PASSED" in result.stdout
        ):
            print("Success")
            grade = "success"
        else:
            print("Failed")
    except Exception as e:
        print(f"test error: {e}")

    with open("auto_grade.txt", "w") as grade_file:
        grade_file.write(grade)


if __name__ == "__main__":
    main()
