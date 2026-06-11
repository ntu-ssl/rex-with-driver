/*
 * Exercises /dev/rex_recover through the normal write(2)/read(2) path and
 * checks the crash-recovery story end to end:
 *
 *   1. small writes succeed (the logic in the Rex extension runs and
 *      commits),
 *   2. a >= 32-byte write trips the latent bounds bug in the logic — the
 *      Rust panic is caught by Rex's exception handling and surfaces here
 *      as a plain -EIO instead of a kernel panic,
 *   3. the very next write succeeds again: the kernel survived and the
 *      driver is still serviceable.
 *
 * Exit status 0 iff every check passed.
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define DEVICE "/dev/rex_recover"

/* Must match the logic in ../src/main.rs: count >= 32 panics. */
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
		fprintf(stderr,
			"Hint: insmod driver/rex_recover.ko, then ./loader &\n");
		return 1;
	}

	/* Normal operations: the logic runs, commits, bytes are consumed. */
	do_write(fd, 5, 5, 0);
	do_write(fd, 17, 17, 0);

	/*
	 * The recovery case: count >= 32 trips the bounds bug in the
	 * extension logic.  Rex catches the Rust panic; the dispatch body
	 * sees INFLIGHT without RESULT and returns -EIO.  Without this
	 * framework the same bug inside the driver proper would be a
	 * kernel BUG().
	 */
	do_write(fd, PANIC_COUNT, -1, EIO);

	/* The kernel survived and the driver still works. */
	do_write(fd, 9, 9, 0);

	/* Read path goes through the same dispatch; demo logic says EOF. */
	errno = 0;
	ret = read(fd, buf, sizeof(buf));
	check("read 16 bytes", ret, errno, 0, 0);

	close(fd);

	if (failures) {
		printf("[trigger] %d CHECK(S) FAILED\n", failures);
		return 1;
	}
	printf("[trigger] ALL CHECKS PASSED — "
	       "panic was contained, kernel survived\n");
	return 0;
}
