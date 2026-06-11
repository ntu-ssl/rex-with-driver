/*
 * Baseline (control experiment) for samples/recover_driver.
 *
 * Drives /dev/rex_baseline with the exact same write sequence the
 * recover_driver test uses.  The driver carries the identical latent
 * bounds bug, but in the *driver body* instead of a Rex extension —
 * so the 40-byte write does not come back as -EIO; it panics the kernel
 * (CONFIG_PANIC_ON_OOPS=y / oops=panic) and output stops right there.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define DEVICE "/dev/rex_baseline"

/* Must match the driver logic: count >= 32 panics. */
#define PANIC_COUNT 40

static void do_write(int fd, size_t n)
{
	char buf[64];
	long ret;

	memset(buf, 'x', sizeof(buf));
	errno = 0;
	ret = write(fd, buf, n);
	if (ret < 0)
		printf("[baseline] write %2zu bytes -> errno=%d (%s)\n",
		       n, errno, strerror(errno));
	else
		printf("[baseline] write %2zu bytes -> ret=%ld\n", n, ret);
	fflush(stdout);
}

int main(void)
{
	int fd;

	fd = open(DEVICE, O_RDWR);
	if (fd < 0) {
		perror("open " DEVICE);
		fprintf(stderr, "Hint: insmod driver/rex_baseline.ko\n");
		return 1;
	}

	/* Normal path — identical behaviour to the protected variant. */
	do_write(fd, 5);
	do_write(fd, 17);

	printf("[baseline] now writing %d bytes — the bug is in the DRIVER "
	       "BODY, no Rex protection.\n"
	       "[baseline] On this kernel (panic_on_oops) the machine dies "
	       "here; nothing below will print.\n", PANIC_COUNT);
	fflush(stdout);

	do_write(fd, PANIC_COUNT);

	/* Only reachable if the kernel somehow survived the oops. */
	printf("[baseline] UNEXPECTED: still alive after the buggy write — "
	       "check dmesg for the oops/taint state\n");
	do_write(fd, 9);

	close(fd);
	return 0;
}
