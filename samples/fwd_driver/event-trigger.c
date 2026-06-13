#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define DEVICE "/dev/rex_fwd"

/*
 * event-trigger — exercises all four rex_fwd_dispatch hooks:
 *
 *   open()    -> OP_OPEN    (rex records PID in OPEN_PIDS, returns 0)
 *   read()    -> OP_READ    (rex overrides return with 0 bytes)
 *   write()   -> OP_WRITE   (rex overrides return with byte count)
 *   close()   -> OP_RELEASE (rex removes PID from OPEN_PIDS)
 *
 * Prerequisites:
 *   1. insmod driver/rex_fwd.ko
 *   2. Run the loader (attaches the Rex kprobe extension)
 *   3. sudo ./event-trigger
 *
 * Check output:
 *   cat /sys/kernel/debug/tracing/trace_pipe
 */

int main(void)
{
	int      fd;
	char     rbuf[64];
	uint64_t cmd = 0xCAFEBABE00000001ULL;
	ssize_t  n;

	fd = open(DEVICE, O_RDWR);
	if (fd < 0) {
		perror("open " DEVICE);
		fprintf(stderr,
			"Hint: make sure rex_fwd.ko is loaded "
			"(insmod driver/rex_fwd.ko)\n");
		return 1;
	}
	fprintf(stderr, "[trigger] opened %s (fd=%d)\n", DEVICE, fd);

	/* read — Rex extension overrides return to 0 (no data in this demo) */
	n = read(fd, rbuf, sizeof(rbuf));
	fprintf(stderr, "[trigger] read()  returned %zd\n", n);

	/* write — Rex extension overrides return to byte count (success) */
	n = write(fd, &cmd, sizeof(cmd));
	fprintf(stderr, "[trigger] write() returned %zd (cmd=0x%016llx)\n",
		n, (unsigned long long)cmd);

	close(fd);
	fprintf(stderr, "[trigger] closed\n");
	return 0;
}
