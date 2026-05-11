# The experiment result

```
root@q:~/rex-with-driver/build/linux# cd ../samples/test/
root@q:~/rex-with-driver/build/samples/test# ./loader &
[1] 399
root@q:~/rex-with-driver/build/samples/test# [loader] rex_sensor_dev loaded
[loader]   tracepoint -> rex_sensor_open
[loade[   15.787016][  T399] NOTICE: Automounting of tracing to debugfs is deprecated and will be removed in 2030
r]   kprobe vfs_read  -> rex_sensor_read
[loader]   kprobe vfs_write -> rex_sensor_write
[loader] tail -f /sys/kernel/debug/tracing/trace_pipe

root@q:~/rex-with-driver/build/samples/test# ./event-trigger
[trigger] opened /dev/zero (fd=3)
[trigger] read() returned 64
[trigger] write(cmd=0xcafebabe00000001) returned 8
           <...>-401     [001] ....1    26.143026: bpf_trace_printk: [test::rex_sensor_open] open on target device, pid=401

   event-trigger-401     [001] ....1    26.146371: bpf_trace_printk: [test::rex_sensor_read] vfs_read on target device, pid=401

   event-trigger-401     [001] ....1    26.root@q:~/rex-with-driver/build/samples/test# 146377: bpf_trace_printk: [test::rex_sensor_write] vfs_write on target device, pid=401
```

## Test flow

```
cp ~/rex-with-driver/samples/test/rex_test.ko \
   ~/rex-with-driver/build/samples/test/rex_test.ko
```

```
insmod rex_test.ko
```
