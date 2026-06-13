#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <bpf/libbpf.h>
#include <librex.h>

#define EXE "./target/x86_64-unknown-none/release/net_driver"

/* STATS map indices — must match src/main.rs. */
enum {
	STAT_TOTAL = 0,
	STAT_BYTES = 1,
	STAT_PASSED = 2,
	STAT_DROPPED = 3,
	STAT_ARP = 4,
	STAT_IPV4 = 5,
	CFG_QUIET = 6,
	STAT_SLOTS = 8,
};

static struct bpf_map *g_stats;
static volatile sig_atomic_t g_stop;

static void dump_stats(void)
{
	if (!g_stats)
		return;
	printf("\n==== rex_net STATS ====\n");
	for (uint32_t k = 0; k < STAT_SLOTS; k++) {
		uint64_t v = 0;
		if (bpf_map__lookup_elem(g_stats, &k, sizeof(k), &v, sizeof(v),
					 0))
			continue;
		const char *name = NULL;
		switch (k) {
		case STAT_TOTAL: name = "total"; break;
		case STAT_BYTES: name = "bytes"; break;
		case STAT_PASSED: name = "passed"; break;
		case STAT_DROPPED: name = "dropped"; break;
		case STAT_ARP: name = "arp"; break;
		case STAT_IPV4: name = "ipv4"; break;
		default: break;
		}
		if (name)
			printf("STAT_%s=%llu\n", name,
			       (unsigned long long)v);
	}
	fflush(stdout);
}

static void on_term(int sig)
{
	(void)sig;
	g_stop = 1;
}

int main(int argc, char **argv)
{
	struct bpf_object *obj;
	struct bpf_program *prog;
	struct bpf_link *link = NULL;
	int trace_pipe_fd;
	int quiet = argc > 1 && !strcmp(argv[1], "--quiet");

	obj = rex_obj_get_bpf(rex_obj_load(EXE));
	if (!obj) {
		fprintf(stderr, "rex_obj_load: could not open %s\n", EXE);
		return 1;
	}

	prog = bpf_object__find_program_by_name(obj, "net_filter");
	if (!prog) {
		fprintf(stderr, "net_filter not found in ELF\n");
		return 1;
	}

	link = bpf_program__attach(prog);
	if (libbpf_get_error(link)) {
		fprintf(stderr, "bpf_program__attach(net_filter) failed\n");
		return 1;
	}

	g_stats = bpf_object__find_map_by_name(obj, "STATS");

	if (quiet && g_stats) {
		/* benchmark mode: tell the extension to skip per-packet logging */
		uint32_t k = CFG_QUIET;
		uint64_t v = 1;
		if (bpf_map__update_elem(g_stats, &k, sizeof(k), &v, sizeof(v),
					 0))
			fprintf(stderr, "[loader] failed to set CFG_QUIET\n");
		else
			fprintf(stderr, "[loader] quiet (benchmark) mode\n");
	}

	signal(SIGTERM, on_term);
	signal(SIGINT, on_term);

	fprintf(stderr,
		"[loader] rex_net extension loaded\n"
		"[loader]   kprobe rex_net_dispatch -> net_filter\n"
		"[loader] Load the driver:  insmod driver/rex_net.ko\n"
		"[loader] Bring it up:      ip addr add 10.0.99.1/24 dev rexnet0; ip link set rexnet0 up\n"
		"[loader] Generate traffic: ping 10.0.99.2\n"
		"[loader] Streaming trace_pipe; SIGTERM to dump stats and exit\n");

	trace_pipe_fd = openat(AT_FDCWD,
			       "/sys/kernel/debug/tracing/trace_pipe",
			       O_RDONLY | O_NONBLOCK);
	if (trace_pipe_fd < 0) {
		perror("openat trace_pipe");
		/* not fatal — we can still dump stats on exit */
	}

	while (!g_stop) {
		char c;
		ssize_t n = trace_pipe_fd >= 0
				    ? read(trace_pipe_fd, &c, 1)
				    : -1;
		if (n == 1) {
			putchar(c);
			fflush(stdout);
		} else {
			usleep(20 * 1000);
		}
	}

	dump_stats();
	bpf_link__destroy(link);
	return 0;
}
