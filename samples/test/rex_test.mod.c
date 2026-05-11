#include <linux/module.h>
#include <linux/export-internal.h>
#include <linux/compiler.h>

MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x04c62fd7, "__memset" },
	{ 0x06052f8d, "__memmove" },
	{ 0x0925493f, "clear_page_orig" },
	{ 0x23b4e0d7, "clear_page_rep" },
	{ 0x9084b044, "clear_page_erms" },
	{ 0x33b84f74, "copy_page" },
	{ 0x92997ed8, "_printk" },
	{ 0x2d083494, "class_create" },
	{ 0xdaa7a814, "device_create" },
	{ 0x495fd7a3, "class_destroy" },
	{ 0x60c0eab8, "__register_chrdev" },
	{ 0xf20b1872, "_copy_to_user" },
	{ 0x650693a9, "_copy_from_user" },
	{ 0x8f346394, "bpf_map_put" },
	{ 0x0fd123c7, "bpf_map_get" },
	{ 0x6bc3fbc0, "__unregister_chrdev" },
	{ 0xa2da3f09, "device_destroy" },
	{ 0xbdfb6dbb, "__fentry__" },
	{ 0xdc50aae2, "__ref_stack_chk_guard" },
	{ 0xf0fdf6cb, "__stack_chk_fail" },
	{ 0xdcc75c48, "module_layout" },
};

MODULE_INFO(depends, "");

