#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <librex.h>
#include <bpf/libbpf.h>

#define EXE "./target/x86_64-unknown-none/release/test"

int main(void)
{
	int trace_pipe_fd;
	struct bpf_object  *obj;
	struct bpf_program *prog_open, *prog_read, *prog_write;
	struct bpf_link    *link_open = NULL, *link_read = NULL, *link_write = NULL;

	/* Load the Rex ELF and get the wrapped bpf_object. */
	obj = rex_obj_get_bpf(rex_obj_load(EXE));
	if (!obj) {
		fprintf(stderr, "rex_obj_load: could not open %s\n", EXE);
		return 1;
	}

	/* Locate each Rex program by the function name in main.rs. */
	prog_open = bpf_object__find_program_by_name(obj, "rex_sensor_open");
	if (!prog_open) {
		fprintf(stderr, "rex_sensor_open not found in ELF\n");
		return 1;
	}

	prog_read = bpf_object__find_program_by_name(obj, "rex_sensor_read");
	if (!prog_read) {
		fprintf(stderr, "rex_sensor_read not found in ELF\n");
		return 1;
	}

	prog_write = bpf_object__find_program_by_name(obj, "rex_sensor_write");
	if (!prog_write) {
		fprintf(stderr, "rex_sensor_write not found in ELF\n");
		return 1;
	}

	/* Attach tracepoint: raw_syscalls/sys_enter -> rex_sensor_open */
	link_open = bpf_program__attach(prog_open);
	if (libbpf_get_error(link_open)) {
		fprintf(stderr, "bpf_program__attach(rex_sensor_open) failed\n");
		return 1;
	}

	/* Attach kprobe: vfs_read -> rex_sensor_read */
	link_read = bpf_program__attach(prog_read);
	if (libbpf_get_error(link_read)) {
		fprintf(stderr, "bpf_program__attach(rex_sensor_read) failed\n");
		return 1;
	}

	/* Attach kprobe: vfs_write -> rex_sensor_write */
	link_write = bpf_program__attach(prog_write);
	if (libbpf_get_error(link_write)) {
		fprintf(stderr, "bpf_program__attach(rex_sensor_write) failed\n");
		return 1;
	}

	fprintf(stderr,
		"[loader] rex_sensor_dev loaded\n"
		"[loader]   tracepoint -> rex_sensor_open\n"
		"[loader]   kprobe vfs_read  -> rex_sensor_read\n"
		"[loader]   kprobe vfs_write -> rex_sensor_write\n"
		"[loader] tail -f /sys/kernel/debug/tracing/trace_pipe\n"
	);

	/* Stream trace output to stdout (same as hello/loader.c). */
	trace_pipe_fd = openat(AT_FDCWD,
			       "/sys/kernel/debug/tracing/trace_pipe",
			       O_RDONLY);
	if (trace_pipe_fd < 0) {
		perror("openat trace_pipe");
		return 1;
	}

	for (;;) {
		char c;
		fflush(stdout);
		if (read(trace_pipe_fd, &c, 1) == 1)
			putchar(c);
	}

	bpf_link__destroy(link_open);
	bpf_link__destroy(link_read);
	bpf_link__destroy(link_write);
	return 0;
}
