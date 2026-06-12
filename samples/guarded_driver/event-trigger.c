/*
 * Route B end-to-end check: the bounds bug lives in the DRIVER BODY
 * (same as baseline_driver), but the buggy region runs under the
 * kernel-side recovery trampoline (rex_driver_protected_call), so:
 *
 *   1. small writes behave identically to the unprotected baseline,
 *   2. the 40-byte write panics inside the driver — the kernel unwinds
 *      to the protected-call site and write(2) returns -EIO,
 *   3. the very next write works: the kernel survived.
 *
 * Exit status 0 iff every check passed.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define DEVICE "/dev/rex_guarded"

/* Must match the driver logic: count >= 32 panics. */
#define PANIC_COUNT 40

static int failures;

static void check(const char *what, long got_ret, int got_errno,
		  long want_ret, int want_errno)
{
	int ok = (got_ret == want_ret) &&
		 (want_ret >= 0 || got_errno == want_errno);

	if (got_ret < 0)
		printf("[trigger] %-15s -> errno=%d (%s)",
		       what, got_errno, strerror(got_errno));
	else
		printf("[trigger] %-15s -> ret=%ld", what, got_ret);

	printf("  %s\n", ok ? "PASS" : "FAIL");
	if (!ok) {
		failures++;
		if (want_ret >= 0)
			printf("[trigger]   expected ret=%ld\n", want_ret);
		else
			printf("[trigger]   expected errno=%d (%s)\n",
			       want_errno, strerror(want_errno));
	}
	fflush(stdout);
}

static void do_write(int fd, size_t n, long want_ret, int want_errno)
{
	char buf[64];
	char what[32];
	long ret;

	memset(buf, 'x', sizeof(buf));
	snprintf(what, sizeof(what), "write %zu bytes", n);

	errno = 0;
	ret = write(fd, buf, n);
	check(what, ret, errno, want_ret, want_errno);
}

int main(void)
{
	char buf[16];
	long ret;
	int fd;

	fd = open(DEVICE, O_RDWR);
	if (fd < 0) {
		perror("open " DEVICE);
		fprintf(stderr, "Hint: insmod driver/rex_guarded.ko\n");
		return 1;
	}

	/* Normal path — identical behaviour to the unprotected baseline. */
	do_write(fd, 5, 5, 0);
	do_write(fd, 17, 17, 0);

	/*
	 * The recovery case: the bounds bug fires in the DRIVER BODY, but
	 * the trampoline unwinds it.  On the unprotected baseline this
	 * exact write is a kernel panic.
	 */
	do_write(fd, PANIC_COUNT, -1, EIO);

	/* The kernel survived and the driver still works. */
	do_write(fd, 9, 9, 0);

	/* Read path: demo driver says EOF. */
	errno = 0;
	ret = read(fd, buf, sizeof(buf));
	check("read 16 bytes", ret, errno, 0, 0);

	close(fd);

	if (failures) {
		printf("[trigger] %d CHECK(S) FAILED\n", failures);
		return 1;
	}
	printf("[trigger] ALL CHECKS PASSED — "
	       "in-driver panic was contained, kernel survived\n");
	return 0;
}
