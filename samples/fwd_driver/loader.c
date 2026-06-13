#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#include <bpf/libbpf.h>
#include <librex.h>

#define EXE "./target/x86_64-unknown-none/release/fwd_driver"

/*
 * Map indices / sizes — must match src/main.rs.
 */
#define EVENTS_SIZE  64
#define SEQ_IDX      0

/* FwdEvent layout (repr(C)) — must match src/main.rs. */
struct fwd_event {
	uint32_t op;
	uint32_t pid;
	uint64_t timestamp_ns;
	uint64_t count;
	uint64_t offset;
	int64_t  retval;
};

// static const char *op_name(uint32_t op)
// {
// 	switch (op) {
// 	case 1: return "read";
// 	case 2: return "write";
// 	case 3: return "open";
// 	case 4: return "release";
// 	default: return "unknown";
// 	}
// }

int main(void)
{
	struct bpf_object  *obj;
	struct bpf_program *prog;
	struct bpf_link    *link = NULL;
	struct bpf_map     *map_events, *map_seq;
	int trace_pipe_fd;

	/* ── load Rex extension ─────────────────────────────────────────── */
	obj = rex_obj_get_bpf(rex_obj_load(EXE));
	if (!obj) {
		fprintf(stderr, "rex_obj_load: could not open %s\n", EXE);
		return 1;
	}
	fprintf(stderr, "rex_obj_get_bpf done\n");

	/* ── locate and attach the kprobe program ───────────────────────── */
	prog = bpf_object__find_program_by_name(obj, "fwd_dispatch");
	if (!prog) {
		fprintf(stderr, "fwd_dispatch not found in ELF\n");
		return 1;
	}
	fprintf(stderr, "bpf_object_find_program_by_name done\n");

	link = bpf_program__attach(prog);
	if (libbpf_get_error(link)) {
		fprintf(stderr, "bpf_program__attach(fwd_dispatch) failed\n");
		return 1;
	}
	fprintf(stderr, "bpf_program_attach done\n");

	/* ── locate maps for userspace polling ──────────────────────────── */
	map_events = bpf_object__find_map_by_name(obj, "EVENTS");
	map_seq    = bpf_object__find_map_by_name(obj, "EVENT_SEQ");

	fprintf(stderr,
		"[loader] rex_fwd extension loaded\n"
		"[loader]   kprobe rex_fwd_dispatch -> rex_fwd_dispatch\n"
		"[loader] Load the driver:  insmod driver/rex_fwd.ko\n"
		"[loader] Trigger events:   ./event-trigger\n"
		"[loader] Streaming trace_pipe (Ctrl-C to stop) ...\n"
	);

	/* ── stream kernel trace ring buffer ────────────────────────────── */
	trace_pipe_fd = openat(AT_FDCWD,
			       "/sys/kernel/debug/tracing/trace_pipe",
			       O_RDONLY);
	if (trace_pipe_fd < 0) {
		perror("openat trace_pipe");
		return 1;
	}

	(void)map_events;
	(void)map_seq;

	for (;;) {
		char c;
		fflush(stdout);
		if (read(trace_pipe_fd, &c, 1) == 1)
			putchar(c);
	}

	bpf_link__destroy(link);
	return 0;
}
