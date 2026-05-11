#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <librex.h>
#include <bpf/libbpf.h>

#define EXE        "./target/x86_64-unknown-none/release/test"
#define DEV_PATH   "/dev/rex_test"
#define REX_IOC_SET_MAP_FD _IOW('r', 1, int)

#include <sys/syscall.h>
#include <linux/bpf.h>
#include <string.h>

static int find_map_fd_by_name(const char *name)
{
    unsigned int id = 0;
    union bpf_attr attr;
    struct bpf_map_info info;
    union bpf_attr info_attr;
    int fd;

    for (;;) {
        memset(&attr, 0, sizeof(attr));
        attr.start_id = id;
        if (syscall(SYS_bpf, BPF_MAP_GET_NEXT_ID, &attr, sizeof(attr)) < 0)
            return -1;
        id = attr.next_id;

        memset(&attr, 0, sizeof(attr));
        attr.map_id = id;
        fd = syscall(SYS_bpf, BPF_MAP_GET_FD_BY_ID, &attr, sizeof(attr));
        if (fd < 0)
            continue;

        memset(&info, 0, sizeof(info));
        memset(&info_attr, 0, sizeof(info_attr));
        info_attr.info.bpf_fd   = fd;
        info_attr.info.info_len = sizeof(info);
        info_attr.info.info     = (uint64_t)(uintptr_t)&info;

        if (syscall(SYS_bpf, BPF_OBJ_GET_INFO_BY_FD, &info_attr, sizeof(info_attr)) == 0
            && strcmp(info.name, name) == 0)
            return fd;

        close(fd);
    }
}

int main(void)
{
    int trace_pipe_fd;
    struct bpf_object  *obj;
    struct bpf_program *prog_open, *prog_read, *prog_write;
    struct bpf_link    *link_open = NULL, *link_read = NULL, *link_write = NULL;

    fprintf(stderr, "REX_LOADER: START\n");
    /* Load the Rex ELF and get the wrapped bpf_object. */
    obj = rex_obj_get_bpf(rex_obj_load(EXE));
    if (!obj) {
        fprintf(stderr, "rex_obj_load: could not open %s\n", EXE);
        return 1;
    }
    fprintf(stderr, "REX OBJ LOADED\n");

    /* Locate each Rex program by the function name in main.rs. */
    prog_open = bpf_object__find_program_by_name(obj, "rex_sensor_open");
    if (!prog_open) { fprintf(stderr, "rex_sensor_open not found\n"); return 1; }

    prog_read = bpf_object__find_program_by_name(obj, "rex_sensor_read");
    if (!prog_read) { fprintf(stderr, "rex_sensor_read not found\n"); return 1; }

    prog_write = bpf_object__find_program_by_name(obj, "rex_sensor_write");
    if (!prog_write) { fprintf(stderr, "rex_sensor_write not found\n"); return 1; }

    fprintf(stderr, "REX FUNCTION FOUND\n");

    /* Attach programs */
    link_open = bpf_program__attach(prog_open);
    if (libbpf_get_error(link_open)) {
        fprintf(stderr, "bpf_program__attach(rex_sensor_open) failed\n");
        return 1;
    }
    link_read = bpf_program__attach(prog_read);
    if (libbpf_get_error(link_read)) {
        fprintf(stderr, "bpf_program__attach(rex_sensor_read) failed\n");
        return 1;
    }
    link_write = bpf_program__attach(prog_write);
    if (libbpf_get_error(link_write)) {
        fprintf(stderr, "bpf_program__attach(rex_sensor_write) failed\n");
        return 1;
    }

    fprintf(stderr, "REX FUNCTIONS ATTACHED\n");
    
    int map_fd = find_map_fd_by_name("sensor_data");
    fprintf(stderr, "[loader] sensor_data map_fd = %d\n", map_fd);
    if (map_fd < 0) {
        fprintf(stderr, "[loader] sensor_data map not found, available maps:\n");
        struct bpf_map *map;
        bpf_object__for_each_map(map, obj)
            fprintf(stderr, "  - %s\n", bpf_map__name(map));
        return 1;
    }



    int dev_fd = open(DEV_PATH, O_RDWR);
    if (dev_fd < 0) {
        perror("open " DEV_PATH);
        return 1;
    }

    if (ioctl(dev_fd, REX_IOC_SET_MAP_FD, map_fd) < 0) {
        perror("ioctl REX_IOC_SET_MAP_FD");
        close(dev_fd);
        return 1;
    }
    close(dev_fd);

    fprintf(stderr,
        "[loader] rex_sensor_dev loaded\n"
        "[loader]   kprobe vfs_open  -> rex_sensor_open\n"
        "[loader]   kprobe vfs_read  -> rex_sensor_read\n"
        "[loader]   kprobe vfs_write -> rex_sensor_write\n"
        "[loader]   sensor_data map fd=%d passed to %s\n"
        "[loader] tail -f /sys/kernel/debug/tracing/trace_pipe\n",
        map_fd, DEV_PATH
    );

    /* Stream trace output to stdout. */
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
