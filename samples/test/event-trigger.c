#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#define DEVICE "/dev/zero"

/*
 * event-trigger — exercises all three Rex sensor-device hooks:
 *
 *   open()  -> on_openat tracepoint  (registers PID in OPEN_PIDS)
 *   read()  -> rex_sensor_read kprobe (updates SENSOR_DATA, emits ring-buf event)
 *   write() -> rex_sensor_write kprobe (stores cmd in CMD_REGISTER, emits event)
 *
 * Run after the loader has attached the Rex programs:
 *   sudo ./event-trigger
 *
 * Then check:
 *   cat /sys/kernel/debug/tracing/trace_pipe
 */

int main(void)
{
	int  fd;
	char rbuf[64];
	/* Command word sent to the device (arbitrary 8 bytes). */
	uint64_t cmd = 0xCAFEBABE00000001ULL;

	/* open — triggers rex_sensor_open via the openat tracepoint */
	fd = openat(AT_FDCWD, DEVICE, O_RDWR);
	if (fd < 0) {
		perror("openat " DEVICE);
		fprintf(stderr,
			"Hint: sudo mknod /dev/rex_sensor c 244 0 && "
			"sudo chmod 666 /dev/rex_sensor\n");
		return 1;
	}
	fprintf(stderr, "[trigger] opened %s (fd=%d)\n", DEVICE, fd);

	/* read — triggers rex_sensor_read kprobe */
	ssize_t n = read(fd, rbuf, sizeof(rbuf));
	fprintf(stderr, "[trigger] read() returned %zd\n", n);

	/* write — triggers rex_sensor_write kprobe */
	n = write(fd, &cmd, sizeof(cmd));
	fprintf(stderr, "[trigger] write(cmd=0x%016llx) returned %zd\n",
		(unsigned long long)cmd, n);

	close(fd);
	return 0;
}
