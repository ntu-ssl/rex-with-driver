// SPDX-License-Identifier: GPL-2.0
/*
 * C shim for the Rex recoverable-driver module.
 *
 * Rust-for-Linux has no bindings for BPF maps, and hand-rolling the
 * `struct bpf_map` offsets from Rust is fragile.  So the Rust side
 * (rex_recover_main.rs) keeps the module framework, the misc device and
 * the `rex_recover_dispatch` kprobe target, and calls these three helpers
 * via FFI to touch the INFLIGHT/RESULT maps.  Same `.rs` + `.c`
 * single-module layout as the in-tree `rust_print` sample.
 *
 * rex_recover_collect() implements the three-state protocol (must stay in
 * sync with ../src/main.rs):
 *
 *   RESULT[pid] present        -> logic completed; return its value
 *   only INFLIGHT[pid] present -> logic panicked mid-operation and was
 *                                 caught by Rex EH before committing;
 *                                 return -EIO (the recovery case)
 *   neither present            -> no extension attached; return -ENXIO
 *
 * Both entries are consumed (deleted) on every call so stale state can
 * never leak into the next operation.
 */

#define pr_fmt(fmt) "rex_recover: " fmt

#include <linux/bpf.h>
#include <linux/err.h>
#include <linux/errno.h>
#include <linux/module.h>
#include <linux/rcupdate.h>
#include <linux/sched.h>

/* bpf_map_get() lives in the BPF_INTERNAL symbol namespace. */
MODULE_IMPORT_NS("BPF_INTERNAL");

/* Map slot ids — must match rex_recover_main.rs and loader.c. */
#define REX_RECOVER_MAP_INFLIGHT 1
#define REX_RECOVER_MAP_RESULT   2

/* Prototypes (the Rust side declares matching extern "C" signatures). */
int rex_recover_register_map(int which, int fd);
void rex_recover_unregister_maps(void);
s64 rex_recover_collect(void);

/*
 * INFLIGHT: RexHashMap<u32 pid, u64>   ("logic started")
 * RESULT:   RexHashMap<u32 pid, i64>   (committed return value)
 */
static struct bpf_map *inflight_map;
static struct bpf_map *result_map;

int rex_recover_register_map(int which, int fd)
{
	struct bpf_map *map, *old;
	struct bpf_map **slot;

	switch (which) {
	case REX_RECOVER_MAP_INFLIGHT:
		slot = &inflight_map;
		break;
	case REX_RECOVER_MAP_RESULT:
		slot = &result_map;
		break;
	default:
		return -EINVAL;
	}

	map = bpf_map_get(fd);
	if (IS_ERR(map))
		return PTR_ERR(map);
	/* Both maps are RexHashMap<u32, 8-byte value>. */
	if (map->key_size != sizeof(u32) || map->value_size != sizeof(u64)) {
		bpf_map_put(map);
		return -EINVAL;
	}
	old = xchg(slot, map);
	if (old)
		bpf_map_put(old);
	return 0;
}

void rex_recover_unregister_maps(void)
{
	struct bpf_map *map;

	map = xchg(&inflight_map, NULL);
	if (map)
		bpf_map_put(map);
	map = xchg(&result_map, NULL);
	if (map)
		bpf_map_put(map);
}

/*
 * Called from the body of rex_recover_dispatch(), i.e. *after* the kprobe
 * at its entry has run the extension logic (or its panic landingpad).
 * kprobe handler and dispatch body run in the same task, so the current
 * pid keys both maps.
 */
s64 rex_recover_collect(void)
{
	struct bpf_map *im = READ_ONCE(inflight_map);
	struct bpf_map *rm = READ_ONCE(result_map);
	u32 key = task_pid_nr(current);
	bool started = false, committed = false;
	s64 val = 0;
	void *v;

	if (!im || !rm)
		return -ENXIO;

	rcu_read_lock();
	if (im->ops->map_lookup_elem(im, &key))
		started = true;
	v = rm->ops->map_lookup_elem(rm, &key);
	if (v) {
		committed = true;
		val = *(s64 *)v;
	}
	rcu_read_unlock();

	/* Consume both entries so nothing leaks into the next operation. */
	if (started)
		im->ops->map_delete_elem(im, &key);
	if (committed)
		rm->ops->map_delete_elem(rm, &key);

	if (!started)
		return -ENXIO;
	if (!committed) {
		pr_warn("logic panicked mid-operation; recovered, returning -EIO\n");
		return -EIO;
	}
	return val;
}
