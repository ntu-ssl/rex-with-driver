#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/uaccess.h>
#include <linux/cdev.h>
#include <linux/bpf.h>
#include <linux/filter.h>

#define DEVICE_NAME "rex_test"
#define REX_IOC_SET_MAP_FD _IOW('r', 1, int)

static int major;
static struct class  *rex_test_class;
static struct device *rex_test_device;
static struct bpf_map *sensor_map = NULL;

static ssize_t rex_test_read(struct file *file, char __user *buf, size_t count, loff_t *pos) {
    u64 value = 0;
    u32 key = 0;
    void *val;

    if (!sensor_map)
        return -ENODEV;
    if (count < sizeof(u64))
        return -EINVAL;

    rcu_read_lock();
    val = sensor_map->ops->map_lookup_elem(sensor_map, &key);
    if (val)
        value = *(u64 *)val;
    rcu_read_unlock();

    if (copy_to_user(buf, &value, sizeof(u64)))
        return -EFAULT;

    return sizeof(u64);
}

static long rex_test_ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
    pr_info("rex_test: ioctl cmd=0x%x arg=%lu expected=0x%lx\n",
            cmd, arg, (unsigned long)REX_IOC_SET_MAP_FD);  
    if (cmd != REX_IOC_SET_MAP_FD)
        return -EINVAL;

    /* Release previous map if any */
    if (sensor_map) {
        bpf_map_put(sensor_map);
        sensor_map = NULL;
    }

    sensor_map = bpf_map_get((u32)arg);
    if (IS_ERR(sensor_map)) {
        sensor_map = NULL;
        return -EBADF;
    }

    pr_info("rex_test: sensor map fd=%lu registered\n", arg);
    return 0;
}

static ssize_t rex_test_write(struct file *file, const char __user *buf, size_t count, loff_t *pos) {
    u64 value;
    u32 key = 0;

    if (!sensor_map)
        return -ENODEV;
    if (count < sizeof(u64))
        return -EINVAL;
    if (copy_from_user(&value, buf, sizeof(u64)))
        return -EFAULT;

    sensor_map->ops->map_update_elem(sensor_map, &key, &value, BPF_ANY);

    return sizeof(u64);
}

static struct file_operations fops = {
    .owner = THIS_MODULE,
    .read = rex_test_read,
    .write = rex_test_write,
    .unlocked_ioctl = rex_test_ioctl,
};

static int __init rex_test_init(void) {
    int ret;

    major = register_chrdev(0, DEVICE_NAME, &fops);
    if (major < 0) {
        pr_err("rex_test: register_chrdev() failed\n");
        return major;
    }

    /* Linux >= 6.4: class_create() takes only the name, no THIS_MODULE XD */
    rex_test_class = class_create(DEVICE_NAME);
    if (IS_ERR(rex_test_class)) {
        pr_err("rex_test: class_create() failed\n");
        ret = PTR_ERR(rex_test_class);
        goto out_chrdev;
    }

    rex_test_device = device_create(rex_test_class, NULL,
                                    MKDEV(major, 0), NULL, DEVICE_NAME);
    if (IS_ERR(rex_test_device)) {
        pr_err("rex_test: device_create() failed\n");
        ret = PTR_ERR(rex_test_device);
        goto out_class;
    }

    pr_info("rex_test: loaded, major=%d\n", major);
    return 0;

out_class:
    class_destroy(rex_test_class); 
out_chrdev:
    unregister_chrdev(major, DEVICE_NAME);
    return ret;
}

static void __exit rex_test_exit(void) {
    device_destroy(rex_test_class, MKDEV(major, 0));
    class_destroy(rex_test_class); 
    unregister_chrdev(major, DEVICE_NAME);
    pr_info("rex_test: unloaded\n");
}

module_init(rex_test_init);
module_exit(rex_test_exit);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("XXX");
MODULE_DESCRIPTION("Stub device node for Rex extension");
MODULE_IMPORT_NS("BPF_INTERNAL");
