#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <librex.h>

#define EXE "./target/x86_64-unknown-none/release/recover_driver"

#define DEVICE "/dev/rex_recover"
#define DRIVER_KO "driver/rex_recover.ko"

/* Must match driver/rex_recover_main.rs and driver/rex_recover_shim.c. */
#define REX_RECOVER_IOC_MAGIC        'R'
#define REX_RECOVER_SET_INFLIGHT_MAP _IOW(REX_RECOVER_IOC_MAGIC, 1, int)
#define REX_RECOVER_SET_RESULT_MAP   _IOW(REX_RECOVER_IOC_MAGIC, 2, int)

static int register_map(struct bpf_object *obj, int dev_fd,
			const char *name, unsigned long ioc)
{
	struct bpf_map *map;

	map = bpf_object__find_map_by_name(obj, name);
	if (!map) {
		fprintf(stderr, "%s map not found in ELF\n", name);
		return -1;
	}
	if (ioctl(dev_fd, ioc, bpf_map__fd(map)) < 0) {
		fprintf(stderr, "ioctl(register %s map): ", name);
		perror("");
		return -1;
	}
	return 0;
}

/*
 * When a Rex program panics, rex_landingpad() sends SIGSYS to the loader
 * process (fail-stop default: an unhandled SIGSYS kills the loader, which
 * closes the bpf link and detaches the program).  This sample's whole
 * point is to keep serving after a recovered panic, so install a real
 * handler (SIG_IGN would not survive force_sig) that just logs the event
 * and keeps the link alive.
 */
static void on_sigsys(int sig)
{
	static const char msg[] =
		"[loader] extension panicked — caught by Rex EH, "
		"still attached\n";
	(void)sig;
	write(STDERR_FILENO, msg, sizeof(msg) - 1);
}

int main(void)
{
	struct sigaction    sa = { 0 };
	struct bpf_object  *obj;
	struct bpf_program *prog;
	struct bpf_link    *link = NULL;
	int trace_pipe_fd;
	int dev_fd;

	sa.sa_handler = on_sigsys;
	sa.sa_flags = SA_RESTART;
	if (sigaction(SIGSYS, &sa, NULL) < 0) {
		perror("sigaction(SIGSYS)");
		return 1;
	}

	/* ── load Rex extension (the actual driver logic) ───────────────── */
	obj = rex_obj_get_bpf(rex_obj_load(EXE));
	if (!obj) {
		fprintf(stderr, "rex_obj_load: could not open %s\n", EXE);
		return 1;
	}

	/* ── attach the logic to the dispatch hook point ────────────────── */
	prog = bpf_object__find_program_by_name(obj, "recover_logic");
	if (!prog) {
		fprintf(stderr, "recover_logic not found in ELF\n");
		return 1;
	}

	/*
	 * kprobe target is rex_recover_dispatch, provided by the driver
	 * module — it must be loaded first or the attach fails.
	 */
	link = bpf_program__attach(prog);
	if (libbpf_get_error(link)) {
		fprintf(stderr,
			"bpf_program__attach(recover_logic) failed\n"
			"Hint: insmod " DRIVER_KO " first "
			"(provides the rex_recover_dispatch symbol)\n");
		return 1;
	}

	/*
	 * ── register the protocol maps with the driver ──────────────────
	 *
	 * The logic writes INFLIGHT[pid] at entry and commits RESULT[pid]
	 * as its last step; the dispatch body consumes both to tell
	 * "completed" / "panicked" / "not attached" apart (kernel pull,
	 * no bpf_override_return).  Hand the map fds to the module via
	 * ioctl so it can bpf_map_get() them.
	 */
	dev_fd = open(DEVICE, O_RDWR);
	if (dev_fd < 0) {
		perror("open " DEVICE);
		fprintf(stderr, "Hint: insmod " DRIVER_KO " first\n");
		return 1;
	}
	if (register_map(obj, dev_fd, "INFLIGHT",
			 REX_RECOVER_SET_INFLIGHT_MAP) ||
	    register_map(obj, dev_fd, "RESULT",
			 REX_RECOVER_SET_RESULT_MAP)) {
		close(dev_fd);
		return 1;
	}
	close(dev_fd); /* module holds its own refs now */

	fprintf(stderr,
		"[loader] recover_driver logic loaded\n"
		"[loader]   kprobe rex_recover_dispatch -> recover_logic\n"
		"[loader]   INFLIGHT/RESULT maps registered with driver\n"
		"[loader] Exercise the driver:  ./event-trigger\n"
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

	for (;;) {
		char c;
		fflush(stdout);
		if (read(trace_pipe_fd, &c, 1) == 1)
			putchar(c);
	}

	bpf_link__destroy(link);
	return 0;
}
