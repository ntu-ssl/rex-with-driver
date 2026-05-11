savedcmd_rex_test.mod.o := clang -Wp,-MMD,./.rex_test.mod.o.d -nostdinc -I/home/mtmatt/rex-with-driver/linux/arch/x86/include -I/home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated -I/home/mtmatt/rex-with-driver/linux/include -I/home/mtmatt/rex-with-driver/build/linux/include -I/home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi -I/home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/uapi -I/home/mtmatt/rex-with-driver/linux/include/uapi -I/home/mtmatt/rex-with-driver/build/linux/include/generated/uapi -include /home/mtmatt/rex-with-driver/linux/include/linux/compiler-version.h -include /home/mtmatt/rex-with-driver/linux/include/linux/kconfig.h -include /home/mtmatt/rex-with-driver/linux/include/linux/compiler_types.h -D__KERNEL__ --target=x86_64-linux-gnu -fintegrated-as -Werror=unknown-warning-option -Werror=ignored-optimization-argument -Werror=option-ignored -Werror=unused-command-line-argument -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mno-sse -mno-mmx -mno-sse2 -mno-3dnow -mno-avx -mno-sse4a -fcf-protection=none -m64 -falign-loops=1 -mno-80387 -mno-fp-ret-in-387 -mstack-alignment=8 -mskip-rax-setup -march=native -mno-red-zone -mcmodel=kernel -mstack-protector-guard-reg=gs -mstack-protector-guard-symbol=__ref_stack_chk_guard -Wno-sign-compare -fno-asynchronous-unwind-tables -fno-delete-null-pointer-checks -O2 -fstack-protector-strong -fno-stack-clash-protection -pg -mfentry -DCC_USING_NOP_MCOUNT -DCC_USING_FENTRY -fno-lto -flto=thin -fsplit-lto-unit -fvisibility=hidden -falign-functions=16 -fstrict-flex-arrays=3 -fms-extensions -fno-strict-overflow -fno-stack-check -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048 -Wno-gnu -Wno-microsoft-anon-tag -Wno-format-overflow-non-kprintf -Wno-format-truncation-non-kprintf -Wno-pointer-sign -Wcast-function-type -Wimplicit-fallthrough -Werror=date-time -Werror=incompatible-pointer-types -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-format-overflow -Wno-override-init -Wno-pointer-to-enum-cast -Wno-tautological-constant-out-of-range-compare -Wno-unaligned-access -Wno-enum-compare-conditional -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-enum-enum-conversion -Wno-sign-compare -Wno-unused-parameter -g  -DMODULE  -DKBUILD_BASENAME='"rex_test.mod"' -DKBUILD_MODNAME='"rex_test"' -D__KBUILD_MODNAME=rex_test -c -o rex_test.mod.o rex_test.mod.c  ; ld.lld -m elf_x86_64 -mllvm -import-instr-limit=5 -z noexecstack   -r -o ./.tmp_rex_test.mod.o rex_test.mod.o; mv ./.tmp_rex_test.mod.o rex_test.mod.o  ; /home/mtmatt/rex-with-driver/build/linux/tools/objtool/objtool --hacks=jump_label --hacks=noinstr --mcount --mnop --orc --static-call --uaccess  --link  --module rex_test.mod.o

source_rex_test.mod.o := rex_test.mod.c

deps_rex_test.mod.o := \
    $(wildcard include/config/MODULE_UNLOAD) \
  /home/mtmatt/rex-with-driver/linux/include/linux/compiler-version.h \
    $(wildcard include/config/CC_VERSION_TEXT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/kconfig.h \
    $(wildcard include/config/CPU_BIG_ENDIAN) \
    $(wildcard include/config/BOOGER) \
    $(wildcard include/config/FOO) \
  /home/mtmatt/rex-with-driver/linux/include/linux/compiler_types.h \
    $(wildcard include/config/DEBUG_INFO_BTF) \
    $(wildcard include/config/PAHOLE_HAS_BTF_TAG) \
    $(wildcard include/config/FUNCTION_ALIGNMENT) \
    $(wildcard include/config/CC_HAS_SANE_FUNCTION_ALIGNMENT) \
    $(wildcard include/config/X86_64) \
    $(wildcard include/config/ARM64) \
    $(wildcard include/config/LD_DEAD_CODE_DATA_ELIMINATION) \
    $(wildcard include/config/LTO_CLANG) \
    $(wildcard include/config/HAVE_ARCH_COMPILER_H) \
    $(wildcard include/config/CC_HAS_ASSUME) \
    $(wildcard include/config/CC_HAS_COUNTED_BY) \
    $(wildcard include/config/CC_HAS_MULTIDIMENSIONAL_NONSTRING) \
    $(wildcard include/config/UBSAN_INTEGER_WRAP) \
    $(wildcard include/config/CFI) \
    $(wildcard include/config/ARCH_USES_CFI_GENERIC_LLVM_PASS) \
    $(wildcard include/config/CC_HAS_ASM_INLINE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/compiler_attributes.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/compiler-clang.h \
    $(wildcard include/config/ARCH_USE_BUILTIN_BSWAP) \
    $(wildcard include/config/CC_HAS_TYPEOF_UNQUAL) \
  /home/mtmatt/rex-with-driver/linux/include/linux/module.h \
    $(wildcard include/config/MODULES) \
    $(wildcard include/config/SYSFS) \
    $(wildcard include/config/MODULES_TREE_LOOKUP) \
    $(wildcard include/config/LIVEPATCH) \
    $(wildcard include/config/STACKTRACE_BUILD_ID) \
    $(wildcard include/config/ARCH_USES_CFI_TRAPS) \
    $(wildcard include/config/MODULE_SIG) \
    $(wildcard include/config/GENERIC_BUG) \
    $(wildcard include/config/KALLSYMS) \
    $(wildcard include/config/SMP) \
    $(wildcard include/config/TRACEPOINTS) \
    $(wildcard include/config/TREE_SRCU) \
    $(wildcard include/config/BPF_EVENTS) \
    $(wildcard include/config/DEBUG_INFO_BTF_MODULES) \
    $(wildcard include/config/JUMP_LABEL) \
    $(wildcard include/config/TRACING) \
    $(wildcard include/config/EVENT_TRACING) \
    $(wildcard include/config/DYNAMIC_FTRACE) \
    $(wildcard include/config/KPROBES) \
    $(wildcard include/config/HAVE_STATIC_CALL_INLINE) \
    $(wildcard include/config/KUNIT) \
    $(wildcard include/config/PRINTK_INDEX) \
    $(wildcard include/config/CONSTRUCTORS) \
    $(wildcard include/config/FUNCTION_ERROR_INJECTION) \
    $(wildcard include/config/DYNAMIC_DEBUG_CORE) \
    $(wildcard include/config/MITIGATION_RETPOLINE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/list.h \
    $(wildcard include/config/LIST_HARDENED) \
    $(wildcard include/config/DEBUG_LIST) \
  /home/mtmatt/rex-with-driver/linux/include/linux/container_of.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/build_bug.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/compiler.h \
    $(wildcard include/config/TRACE_BRANCH_PROFILING) \
    $(wildcard include/config/PROFILE_ALL_BRANCHES) \
    $(wildcard include/config/OBJTOOL) \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/asm/rwonce.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/rwonce.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kasan-checks.h \
    $(wildcard include/config/KASAN_GENERIC) \
    $(wildcard include/config/KASAN_SW_TAGS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/types.h \
    $(wildcard include/config/HAVE_UID16) \
    $(wildcard include/config/UID16) \
    $(wildcard include/config/ARCH_DMA_ADDR_T_64BIT) \
    $(wildcard include/config/PHYS_ADDR_T_64BIT) \
    $(wildcard include/config/64BIT) \
    $(wildcard include/config/ARCH_32BIT_USTAT_F_TINODE) \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/types.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/uapi/asm/types.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/types.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/int-ll64.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/int-ll64.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/bitsperlong.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitsperlong.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/bitsperlong.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/posix_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/stddef.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/stddef.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/posix_types.h \
    $(wildcard include/config/X86_32) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/posix_types_64.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/posix_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kcsan-checks.h \
    $(wildcard include/config/KCSAN) \
    $(wildcard include/config/KCSAN_WEAK_MEMORY) \
    $(wildcard include/config/KCSAN_IGNORE_ATOMICS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/poison.h \
    $(wildcard include/config/ILLEGAL_POINTER_VALUE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/const.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/const.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/const.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/barrier.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/alternative.h \
    $(wildcard include/config/CALL_THUNKS) \
    $(wildcard include/config/MITIGATION_ITS) \
    $(wildcard include/config/MITIGATION_RETHUNK) \
  /home/mtmatt/rex-with-driver/linux/include/linux/stringify.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/objtool.h \
    $(wildcard include/config/FRAME_POINTER) \
    $(wildcard include/config/NOINSTR_VALIDATION) \
    $(wildcard include/config/MITIGATION_UNRET_ENTRY) \
    $(wildcard include/config/MITIGATION_SRSO) \
  /home/mtmatt/rex-with-driver/linux/include/linux/objtool_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/annotate.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/asm.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/asm-offsets.h \
  /home/mtmatt/rex-with-driver/build/linux/include/generated/asm-offsets.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/extable_fixup_types.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/bug.h \
    $(wildcard include/config/DEBUG_BUGVERBOSE) \
    $(wildcard include/config/DEBUG_BUGVERBOSE_DETAILED) \
  /home/mtmatt/rex-with-driver/linux/include/linux/instrumentation.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/static_call_types.h \
    $(wildcard include/config/HAVE_STATIC_CALL) \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bug.h \
    $(wildcard include/config/BUG) \
    $(wildcard include/config/GENERIC_BUG_RELATIVE_POINTERS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/once_lite.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/panic.h \
    $(wildcard include/config/PANIC_TIMEOUT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/stdarg.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/printk.h \
    $(wildcard include/config/MESSAGE_LOGLEVEL_DEFAULT) \
    $(wildcard include/config/CONSOLE_LOGLEVEL_DEFAULT) \
    $(wildcard include/config/CONSOLE_LOGLEVEL_QUIET) \
    $(wildcard include/config/EARLY_PRINTK) \
    $(wildcard include/config/PRINTK) \
    $(wildcard include/config/DYNAMIC_DEBUG) \
  /home/mtmatt/rex-with-driver/linux/include/linux/init.h \
    $(wildcard include/config/MEMORY_HOTPLUG) \
    $(wildcard include/config/HAVE_ARCH_PREL32_RELOCATIONS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/kern_levels.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/linkage.h \
    $(wildcard include/config/ARCH_USE_SYM_ANNOTATIONS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/export.h \
    $(wildcard include/config/MODVERSIONS) \
    $(wildcard include/config/GENDWARFKSYMS) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/linkage.h \
    $(wildcard include/config/CALL_PADDING) \
    $(wildcard include/config/MITIGATION_SLS) \
    $(wildcard include/config/FUNCTION_PADDING_BYTES) \
    $(wildcard include/config/UML) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/ibt.h \
    $(wildcard include/config/X86_KERNEL_IBT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/ratelimit_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/bits.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/bits.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/bits.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/overflow.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/limits.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/limits.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/limits.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/param.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/uapi/asm/param.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/param.h \
    $(wildcard include/config/HZ) \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/param.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/spinlock_types_raw.h \
    $(wildcard include/config/DEBUG_SPINLOCK) \
    $(wildcard include/config/DEBUG_LOCK_ALLOC) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/spinlock_types.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/qspinlock_types.h \
    $(wildcard include/config/NR_CPUS) \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/qrwlock_types.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/byteorder.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/byteorder/little_endian.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/byteorder/little_endian.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/swab.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/swab.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/swab.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/byteorder/generic.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/lockdep_types.h \
    $(wildcard include/config/PROVE_RAW_LOCK_NESTING) \
    $(wildcard include/config/LOCKDEP) \
    $(wildcard include/config/LOCK_STAT) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/nops.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/barrier.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/stat.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/stat.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/stat.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/time.h \
    $(wildcard include/config/POSIX_TIMERS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/cache.h \
    $(wildcard include/config/ARCH_HAS_CACHE_LINE_SIZE) \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/kernel.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/sysinfo.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/cache.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cache.h \
    $(wildcard include/config/X86_L1_CACHE_SHIFT) \
    $(wildcard include/config/X86_INTERNODE_CACHE_SHIFT) \
    $(wildcard include/config/X86_VSMP) \
  /home/mtmatt/rex-with-driver/linux/include/linux/math64.h \
    $(wildcard include/config/ARCH_SUPPORTS_INT128) \
  /home/mtmatt/rex-with-driver/linux/include/linux/math.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/div64.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/div64.h \
    $(wildcard include/config/CC_OPTIMIZE_FOR_PERFORMANCE) \
  /home/mtmatt/rex-with-driver/linux/include/vdso/math64.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/time64.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/time64.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/time.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/time_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/time32.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/timex.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/timex.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/timex.h \
    $(wildcard include/config/X86_TSC) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/processor.h \
    $(wildcard include/config/X86_VMX_FEATURE_NAMES) \
    $(wildcard include/config/X86_IOPL_IOPERM) \
    $(wildcard include/config/VM86) \
    $(wildcard include/config/X86_USER_SHADOW_STACK) \
    $(wildcard include/config/X86_DEBUG_FPU) \
    $(wildcard include/config/USE_X86_SEG_SUPPORT) \
    $(wildcard include/config/PARAVIRT_XXL) \
    $(wildcard include/config/CPU_SUP_AMD) \
    $(wildcard include/config/XEN) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/processor-flags.h \
    $(wildcard include/config/MITIGATION_PAGE_TABLE_ISOLATION) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/processor-flags.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/mem_encrypt.h \
    $(wildcard include/config/ARCH_HAS_MEM_ENCRYPT) \
    $(wildcard include/config/AMD_MEM_ENCRYPT) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/mem_encrypt.h \
    $(wildcard include/config/X86_MEM_ENCRYPT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/cc_platform.h \
    $(wildcard include/config/ARCH_HAS_CC_PLATFORM) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/math_emu.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/ptrace.h \
    $(wildcard include/config/PARAVIRT) \
    $(wildcard include/config/IA32_EMULATION) \
    $(wildcard include/config/X86_DEBUGCTLMSR) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/segment.h \
    $(wildcard include/config/XEN_PV) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/page_types.h \
    $(wildcard include/config/PHYSICAL_START) \
    $(wildcard include/config/PHYSICAL_ALIGN) \
    $(wildcard include/config/DYNAMIC_PHYSICAL_MASK) \
  /home/mtmatt/rex-with-driver/linux/include/vdso/page.h \
    $(wildcard include/config/PAGE_SHIFT) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/page_64_types.h \
    $(wildcard include/config/KASAN) \
    $(wildcard include/config/RANDOMIZE_BASE) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/kaslr.h \
    $(wildcard include/config/RANDOMIZE_MEMORY) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/ptrace.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/ptrace-abi.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/paravirt_types.h \
    $(wildcard include/config/ZERO_CALL_USED_REGS) \
    $(wildcard include/config/PARAVIRT_DEBUG) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/desc_defs.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/pgtable_types.h \
    $(wildcard include/config/X86_INTEL_MEMORY_PROTECTION_KEYS) \
    $(wildcard include/config/X86_PAE) \
    $(wildcard include/config/MEM_SOFT_DIRTY) \
    $(wildcard include/config/HAVE_ARCH_USERFAULTFD_WP) \
    $(wildcard include/config/PGTABLE_LEVELS) \
    $(wildcard include/config/PROC_FS) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/pgtable_64_types.h \
    $(wildcard include/config/KMSAN) \
    $(wildcard include/config/DEBUG_KMAP_LOCAL_FORCE_MAP) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/sparsemem.h \
    $(wildcard include/config/SPARSEMEM) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/nospec-branch.h \
    $(wildcard include/config/CALL_THUNKS_DEBUG) \
    $(wildcard include/config/MITIGATION_CALL_DEPTH_TRACKING) \
    $(wildcard include/config/MITIGATION_IBPB_ENTRY) \
  /home/mtmatt/rex-with-driver/linux/include/linux/static_key.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/jump_label.h \
    $(wildcard include/config/HAVE_ARCH_JUMP_LABEL_RELATIVE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/cleanup.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/err.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/uapi/asm/errno.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/errno.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/errno-base.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/args.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/jump_label.h \
    $(wildcard include/config/HAVE_JUMP_LABEL_HACK) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cpufeatures.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/msr-index.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/unwind_hints.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/orc_types.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/percpu.h \
    $(wildcard include/config/CC_HAS_NAMED_AS) \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/percpu.h \
    $(wildcard include/config/DEBUG_PREEMPT) \
    $(wildcard include/config/HAVE_SETUP_PER_CPU_AREA) \
  /home/mtmatt/rex-with-driver/linux/include/linux/threads.h \
    $(wildcard include/config/BASE_SMALL) \
  /home/mtmatt/rex-with-driver/linux/include/linux/percpu-defs.h \
    $(wildcard include/config/ARCH_MODULE_NEEDS_WEAK_PER_CPU) \
    $(wildcard include/config/DEBUG_FORCE_WEAK_PER_CPU) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/proto.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/ldt.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/sigcontext.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/current.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cpuid/api.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cpuid/types.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/string.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/string_64.h \
    $(wildcard include/config/ARCH_HAS_UACCESS_FLUSHCACHE) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/page.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/page_64.h \
    $(wildcard include/config/DEBUG_VIRTUAL) \
    $(wildcard include/config/X86_VSYSCALL_EMULATION) \
  /home/mtmatt/rex-with-driver/linux/include/linux/kmsan-checks.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/mmdebug.h \
    $(wildcard include/config/DEBUG_VM) \
    $(wildcard include/config/DEBUG_VM_IRQSOFF) \
    $(wildcard include/config/DEBUG_VM_PGFLAGS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/bug.h \
    $(wildcard include/config/BUG_ON_DATA_CORRUPTION) \
  /home/mtmatt/rex-with-driver/linux/include/linux/range.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/memory_model.h \
    $(wildcard include/config/FLATMEM) \
    $(wildcard include/config/SPARSEMEM_VMEMMAP) \
  /home/mtmatt/rex-with-driver/linux/include/linux/pfn.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/getorder.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/log2.h \
    $(wildcard include/config/ARCH_HAS_ILOG2_U32) \
    $(wildcard include/config/ARCH_HAS_ILOG2_U64) \
  /home/mtmatt/rex-with-driver/linux/include/linux/bitops.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/typecheck.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/generic-non-atomic.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/bitops.h \
    $(wildcard include/config/X86_CMOV) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/rmwcc.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/sched.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/arch_hweight.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/const_hweight.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/instrumented-atomic.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/instrumented.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/instrumented-non-atomic.h \
    $(wildcard include/config/KCSAN_ASSUME_PLAIN_WRITES_ATOMIC) \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/instrumented-lock.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/le.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/bitops/ext2-atomic-setbit.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/special_insns.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/errno.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/errno.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/irqflags.h \
    $(wildcard include/config/PROVE_LOCKING) \
    $(wildcard include/config/TRACE_IRQFLAGS) \
    $(wildcard include/config/PREEMPT_RT) \
    $(wildcard include/config/IRQSOFF_TRACER) \
    $(wildcard include/config/PREEMPT_TRACER) \
    $(wildcard include/config/DEBUG_IRQFLAGS) \
    $(wildcard include/config/TRACE_IRQFLAGS_SUPPORT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/irqflags_types.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/irqflags.h \
    $(wildcard include/config/DEBUG_ENTRY) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/fpu/types.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/vmxfeatures.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/vdso/processor.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/shstk.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/personality.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/personality.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/tsc.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cpufeature.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/asm/cpufeaturemasks.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/msr.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cpumask.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/cpumask.h \
    $(wildcard include/config/FORCE_NR_CPUS) \
    $(wildcard include/config/HOTPLUG_CPU) \
    $(wildcard include/config/DEBUG_PER_CPU_MAPS) \
    $(wildcard include/config/CPUMASK_OFFSTACK) \
  /home/mtmatt/rex-with-driver/linux/include/linux/atomic.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/atomic.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cmpxchg.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/cmpxchg_64.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/atomic64_64.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/atomic/atomic-arch-fallback.h \
    $(wildcard include/config/GENERIC_ATOMIC64) \
  /home/mtmatt/rex-with-driver/linux/include/linux/atomic/atomic-long.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/atomic/atomic-instrumented.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/bitmap.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/align.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/align.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/find.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/string.h \
    $(wildcard include/config/BINARY_PRINTF) \
    $(wildcard include/config/FORTIFY_SOURCE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/array_size.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/string.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/bitmap-str.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/cpumask_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/gfp_types.h \
    $(wildcard include/config/KASAN_HW_TAGS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/numa.h \
    $(wildcard include/config/NUMA_KEEP_MEMINFO) \
    $(wildcard include/config/NUMA) \
    $(wildcard include/config/HAVE_ARCH_NODE_DEV_GROUP) \
  /home/mtmatt/rex-with-driver/linux/include/linux/nodemask.h \
    $(wildcard include/config/HIGHMEM) \
  /home/mtmatt/rex-with-driver/linux/include/linux/minmax.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/nodemask_types.h \
    $(wildcard include/config/NODES_SHIFT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/random.h \
    $(wildcard include/config/VMGENID) \
  /home/mtmatt/rex-with-driver/linux/include/linux/kernel.h \
    $(wildcard include/config/PREEMPT_VOLUNTARY_BUILD) \
    $(wildcard include/config/PREEMPT_DYNAMIC) \
    $(wildcard include/config/HAVE_PREEMPT_DYNAMIC_CALL) \
    $(wildcard include/config/HAVE_PREEMPT_DYNAMIC_KEY) \
    $(wildcard include/config/PREEMPT_) \
    $(wildcard include/config/DEBUG_ATOMIC_SLEEP) \
    $(wildcard include/config/MMU) \
  /home/mtmatt/rex-with-driver/linux/include/linux/hex.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kstrtox.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/sprintf.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/instruction_pointer.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/util_macros.h \
    $(wildcard include/config/FOO_SUSPEND) \
  /home/mtmatt/rex-with-driver/linux/include/linux/wordpart.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/random.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/ioctl.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/uapi/asm/ioctl.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/ioctl.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/ioctl.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/irqnr.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/irqnr.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/msr.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/shared/msr.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/percpu.h \
    $(wildcard include/config/RANDOM_KMALLOC_CACHES) \
    $(wildcard include/config/PAGE_SIZE_4KB) \
    $(wildcard include/config/NEED_PER_CPU_PAGE_FIRST_CHUNK) \
  /home/mtmatt/rex-with-driver/linux/include/linux/alloc_tag.h \
    $(wildcard include/config/MEM_ALLOC_PROFILING_DEBUG) \
    $(wildcard include/config/MEM_ALLOC_PROFILING) \
    $(wildcard include/config/MEM_ALLOC_PROFILING_ENABLED_BY_DEFAULT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/codetag.h \
    $(wildcard include/config/CODE_TAGGING) \
  /home/mtmatt/rex-with-driver/linux/include/linux/preempt.h \
    $(wildcard include/config/PREEMPT_COUNT) \
    $(wildcard include/config/TRACE_PREEMPT_TOGGLE) \
    $(wildcard include/config/PREEMPTION) \
    $(wildcard include/config/PREEMPT_NOTIFIERS) \
    $(wildcard include/config/PREEMPT_NONE) \
    $(wildcard include/config/PREEMPT_VOLUNTARY) \
    $(wildcard include/config/PREEMPT) \
    $(wildcard include/config/PREEMPT_LAZY) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/preempt.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/smp.h \
    $(wildcard include/config/UP_LATE_INIT) \
    $(wildcard include/config/CSD_LOCK_WAIT_DEBUG) \
  /home/mtmatt/rex-with-driver/linux/include/linux/smp_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/llist.h \
    $(wildcard include/config/ARCH_HAVE_NMI_SAFE_CMPXCHG) \
  /home/mtmatt/rex-with-driver/linux/include/linux/thread_info.h \
    $(wildcard include/config/THREAD_INFO_IN_TASK) \
    $(wildcard include/config/GENERIC_ENTRY) \
    $(wildcard include/config/ARCH_HAS_PREEMPT_LAZY) \
    $(wildcard include/config/HAVE_ARCH_WITHIN_STACK_FRAMES) \
    $(wildcard include/config/SH) \
  /home/mtmatt/rex-with-driver/linux/include/linux/restart_block.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/thread_info.h \
    $(wildcard include/config/X86_FRED) \
    $(wildcard include/config/COMPAT) \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/thread_info_tif.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/smp.h \
    $(wildcard include/config/DEBUG_NMI_SELFTEST) \
  /home/mtmatt/rex-with-driver/linux/include/linux/sched.h \
    $(wildcard include/config/VIRT_CPU_ACCOUNTING_NATIVE) \
    $(wildcard include/config/SCHED_INFO) \
    $(wildcard include/config/SCHEDSTATS) \
    $(wildcard include/config/SCHED_CORE) \
    $(wildcard include/config/FAIR_GROUP_SCHED) \
    $(wildcard include/config/RT_GROUP_SCHED) \
    $(wildcard include/config/RT_MUTEXES) \
    $(wildcard include/config/UCLAMP_TASK) \
    $(wildcard include/config/UCLAMP_BUCKETS_COUNT) \
    $(wildcard include/config/KMAP_LOCAL) \
    $(wildcard include/config/SCHED_CLASS_EXT) \
    $(wildcard include/config/CGROUP_SCHED) \
    $(wildcard include/config/CFS_BANDWIDTH) \
    $(wildcard include/config/BLK_DEV_IO_TRACE) \
    $(wildcard include/config/PREEMPT_RCU) \
    $(wildcard include/config/TASKS_RCU) \
    $(wildcard include/config/TASKS_TRACE_RCU) \
    $(wildcard include/config/MEMCG_V1) \
    $(wildcard include/config/LRU_GEN) \
    $(wildcard include/config/COMPAT_BRK) \
    $(wildcard include/config/CGROUPS) \
    $(wildcard include/config/BLK_CGROUP) \
    $(wildcard include/config/PSI) \
    $(wildcard include/config/PAGE_OWNER) \
    $(wildcard include/config/EVENTFD) \
    $(wildcard include/config/ARCH_HAS_CPU_PASID) \
    $(wildcard include/config/X86_BUS_LOCK_DETECT) \
    $(wildcard include/config/TASK_DELAY_ACCT) \
    $(wildcard include/config/STACKPROTECTOR) \
    $(wildcard include/config/ARCH_HAS_SCALED_CPUTIME) \
    $(wildcard include/config/VIRT_CPU_ACCOUNTING_GEN) \
    $(wildcard include/config/NO_HZ_FULL) \
    $(wildcard include/config/POSIX_CPUTIMERS) \
    $(wildcard include/config/POSIX_CPU_TIMERS_TASK_WORK) \
    $(wildcard include/config/KEYS) \
    $(wildcard include/config/SYSVIPC) \
    $(wildcard include/config/DETECT_HUNG_TASK) \
    $(wildcard include/config/IO_URING) \
    $(wildcard include/config/AUDIT) \
    $(wildcard include/config/AUDITSYSCALL) \
    $(wildcard include/config/DETECT_HUNG_TASK_BLOCKER) \
    $(wildcard include/config/UBSAN) \
    $(wildcard include/config/UBSAN_TRAP) \
    $(wildcard include/config/COMPACTION) \
    $(wildcard include/config/TASK_XACCT) \
    $(wildcard include/config/CPUSETS) \
    $(wildcard include/config/X86_CPU_RESCTRL) \
    $(wildcard include/config/FUTEX) \
    $(wildcard include/config/PERF_EVENTS) \
    $(wildcard include/config/NUMA_BALANCING) \
    $(wildcard include/config/FAULT_INJECTION) \
    $(wildcard include/config/LATENCYTOP) \
    $(wildcard include/config/FUNCTION_GRAPH_TRACER) \
    $(wildcard include/config/KCOV) \
    $(wildcard include/config/MEMCG) \
    $(wildcard include/config/UPROBES) \
    $(wildcard include/config/BCACHE) \
    $(wildcard include/config/VMAP_STACK) \
    $(wildcard include/config/SECURITY) \
    $(wildcard include/config/BPF_SYSCALL) \
    $(wildcard include/config/KSTACK_ERASE) \
    $(wildcard include/config/KSTACK_ERASE_METRICS) \
    $(wildcard include/config/X86_MCE) \
    $(wildcard include/config/KRETPROBES) \
    $(wildcard include/config/RETHOOK) \
    $(wildcard include/config/ARCH_HAS_PARANOID_L1D_FLUSH) \
    $(wildcard include/config/RV) \
    $(wildcard include/config/RV_PER_TASK_MONITORS) \
    $(wildcard include/config/USER_EVENTS) \
    $(wildcard include/config/UNWIND_USER) \
    $(wildcard include/config/SCHED_PROXY_EXEC) \
    $(wildcard include/config/SCHED_MM_CID) \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/sched.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/pid_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/sem_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/shm.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/shmparam.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kmsan_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/mutex_types.h \
    $(wildcard include/config/MUTEX_SPIN_ON_OWNER) \
    $(wildcard include/config/DEBUG_MUTEXES) \
  /home/mtmatt/rex-with-driver/linux/include/linux/osq_lock.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/spinlock_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rwlock_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/plist_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/hrtimer_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/timerqueue_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rbtree_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/timer_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/seccomp_types.h \
    $(wildcard include/config/SECCOMP) \
  /home/mtmatt/rex-with-driver/linux/include/linux/refcount_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/resource.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/resource.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/uapi/asm/resource.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/resource.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/resource.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/latencytop.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/sched/prio.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/sched/types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/signal_types.h \
    $(wildcard include/config/OLD_SIGACTION) \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/signal.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/signal.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/signal.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/signal-defs.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/siginfo.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/asm-generic/siginfo.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/spinlock.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/bottom_half.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/lockdep.h \
    $(wildcard include/config/DEBUG_LOCKING_API_SELFTESTS) \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/asm/mmiowb.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/mmiowb.h \
    $(wildcard include/config/MMIOWB) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/spinlock.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/paravirt.h \
    $(wildcard include/config/PARAVIRT_SPINLOCKS) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/frame.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/qspinlock.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/qspinlock.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/qrwlock.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/qrwlock.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rwlock.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/spinlock_api_smp.h \
    $(wildcard include/config/INLINE_SPIN_LOCK) \
    $(wildcard include/config/INLINE_SPIN_LOCK_BH) \
    $(wildcard include/config/INLINE_SPIN_LOCK_IRQ) \
    $(wildcard include/config/INLINE_SPIN_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_SPIN_TRYLOCK) \
    $(wildcard include/config/INLINE_SPIN_TRYLOCK_BH) \
    $(wildcard include/config/UNINLINE_SPIN_UNLOCK) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_BH) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_IRQRESTORE) \
    $(wildcard include/config/GENERIC_LOCKBREAK) \
  /home/mtmatt/rex-with-driver/linux/include/linux/rwlock_api_smp.h \
    $(wildcard include/config/INLINE_READ_LOCK) \
    $(wildcard include/config/INLINE_WRITE_LOCK) \
    $(wildcard include/config/INLINE_READ_LOCK_BH) \
    $(wildcard include/config/INLINE_WRITE_LOCK_BH) \
    $(wildcard include/config/INLINE_READ_LOCK_IRQ) \
    $(wildcard include/config/INLINE_WRITE_LOCK_IRQ) \
    $(wildcard include/config/INLINE_READ_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_WRITE_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_READ_TRYLOCK) \
    $(wildcard include/config/INLINE_WRITE_TRYLOCK) \
    $(wildcard include/config/INLINE_READ_UNLOCK) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK) \
    $(wildcard include/config/INLINE_READ_UNLOCK_BH) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_BH) \
    $(wildcard include/config/INLINE_READ_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_READ_UNLOCK_IRQRESTORE) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_IRQRESTORE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/syscall_user_dispatch_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/mm_types_task.h \
    $(wildcard include/config/ARCH_WANT_BATCHED_UNMAP_TLB_FLUSH) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/tlbbatch.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/netdevice_xmit.h \
    $(wildcard include/config/NET_ACT_MIRRED) \
    $(wildcard include/config/NET_EGRESS) \
    $(wildcard include/config/NF_DUP_NETDEV) \
  /home/mtmatt/rex-with-driver/linux/include/linux/task_io_accounting.h \
    $(wildcard include/config/TASK_IO_ACCOUNTING) \
  /home/mtmatt/rex-with-driver/linux/include/linux/posix-timers_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rseq_types.h \
    $(wildcard include/config/RSEQ) \
  /home/mtmatt/rex-with-driver/linux/include/linux/irq_work_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/workqueue_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/seqlock_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kcsan.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rv.h \
    $(wildcard include/config/RV_LTL_MONITOR) \
    $(wildcard include/config/RV_REACTORS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/uidgid_types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/tracepoint-defs.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/unwind_deferred_types.h \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/asm/kmap_size.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/kmap_size.h \
    $(wildcard include/config/DEBUG_KMAP_LOCAL) \
  /home/mtmatt/rex-with-driver/build/linux/include/generated/rq-offsets.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/sched/ext.h \
    $(wildcard include/config/EXT_GROUP_SCHED) \
  /home/mtmatt/rex-with-driver/linux/include/linux/rhashtable-types.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/mutex.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/debug_locks.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/time32.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/time.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/uidgid.h \
    $(wildcard include/config/MULTIUSER) \
    $(wildcard include/config/USER_NS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/highuid.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/buildid.h \
    $(wildcard include/config/VMCORE_INFO) \
  /home/mtmatt/rex-with-driver/linux/include/linux/kmod.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/umh.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/gfp.h \
    $(wildcard include/config/ZONE_DMA) \
    $(wildcard include/config/ZONE_DMA32) \
    $(wildcard include/config/ZONE_DEVICE) \
    $(wildcard include/config/CONTIG_ALLOC) \
  /home/mtmatt/rex-with-driver/linux/include/linux/mmzone.h \
    $(wildcard include/config/ARCH_FORCE_MAX_ORDER) \
    $(wildcard include/config/PAGE_BLOCK_MAX_ORDER) \
    $(wildcard include/config/CMA) \
    $(wildcard include/config/MEMORY_ISOLATION) \
    $(wildcard include/config/ZSMALLOC) \
    $(wildcard include/config/UNACCEPTED_MEMORY) \
    $(wildcard include/config/SHADOW_CALL_STACK) \
    $(wildcard include/config/IOMMU_SUPPORT) \
    $(wildcard include/config/SWAP) \
    $(wildcard include/config/HUGETLB_PAGE) \
    $(wildcard include/config/TRANSPARENT_HUGEPAGE) \
    $(wildcard include/config/LRU_GEN_STATS) \
    $(wildcard include/config/LRU_GEN_WALKS_MMU) \
    $(wildcard include/config/MEMORY_FAILURE) \
    $(wildcard include/config/PAGE_EXTENSION) \
    $(wildcard include/config/DEFERRED_STRUCT_PAGE_INIT) \
    $(wildcard include/config/HAVE_MEMORYLESS_NODES) \
    $(wildcard include/config/SPARSEMEM_EXTREME) \
    $(wildcard include/config/SPARSEMEM_VMEMMAP_PREINIT) \
    $(wildcard include/config/HAVE_ARCH_PFN_VALID) \
  /home/mtmatt/rex-with-driver/linux/include/linux/list_nulls.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/wait.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/seqlock.h \
    $(wildcard include/config/CC_IS_GCC) \
    $(wildcard include/config/GCC_VERSION) \
  /home/mtmatt/rex-with-driver/linux/include/linux/pageblock-flags.h \
    $(wildcard include/config/HUGETLB_PAGE_SIZE_VARIABLE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/page-flags-layout.h \
  /home/mtmatt/rex-with-driver/build/linux/include/generated/bounds.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/mm_types.h \
    $(wildcard include/config/HAVE_ALIGNED_STRUCT_PAGE) \
    $(wildcard include/config/SLAB_OBJ_EXT) \
    $(wildcard include/config/HUGETLB_PMD_PAGE_TABLE_SHARING) \
    $(wildcard include/config/SLAB_FREELIST_HARDENED) \
    $(wildcard include/config/USERFAULTFD) \
    $(wildcard include/config/ANON_VMA_NAME) \
    $(wildcard include/config/PER_VMA_LOCK) \
    $(wildcard include/config/HAVE_ARCH_COMPAT_MMAP_BASES) \
    $(wildcard include/config/MEMBARRIER) \
    $(wildcard include/config/FUTEX_PRIVATE_HASH) \
    $(wildcard include/config/ARCH_HAS_ELF_CORE_EFLAGS) \
    $(wildcard include/config/AIO) \
    $(wildcard include/config/MMU_NOTIFIER) \
    $(wildcard include/config/SPLIT_PMD_PTLOCKS) \
    $(wildcard include/config/IOMMU_MM_DATA) \
    $(wildcard include/config/KSM) \
    $(wildcard include/config/MM_ID) \
    $(wildcard include/config/CORE_DUMP_DEFAULT_ELF_HEADERS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/auxvec.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/auxvec.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/uapi/asm/auxvec.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kref.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/refcount.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rbtree.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rcupdate.h \
    $(wildcard include/config/TINY_RCU) \
    $(wildcard include/config/RCU_STRICT_GRACE_PERIOD) \
    $(wildcard include/config/RCU_LAZY) \
    $(wildcard include/config/RCU_STALL_COMMON) \
    $(wildcard include/config/VIRT_XFER_TO_GUEST_WORK) \
    $(wildcard include/config/RCU_NOCB_CPU) \
    $(wildcard include/config/TASKS_RCU_GENERIC) \
    $(wildcard include/config/TASKS_RUDE_RCU) \
    $(wildcard include/config/TREE_RCU) \
    $(wildcard include/config/DEBUG_OBJECTS_RCU_HEAD) \
    $(wildcard include/config/PROVE_RCU) \
    $(wildcard include/config/ARCH_WEAK_RELEASE_ACQUIRE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/context_tracking_irq.h \
    $(wildcard include/config/CONTEXT_TRACKING_IDLE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/rcutree.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/maple_tree.h \
    $(wildcard include/config/MAPLE_RCU_DISABLED) \
    $(wildcard include/config/DEBUG_MAPLE_TREE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/rwsem.h \
    $(wildcard include/config/RWSEM_SPIN_ON_OWNER) \
    $(wildcard include/config/DEBUG_RWSEMS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/completion.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/swait.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/uprobes.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/timer.h \
    $(wildcard include/config/DEBUG_OBJECTS_TIMERS) \
    $(wildcard include/config/NO_HZ_COMMON) \
  /home/mtmatt/rex-with-driver/linux/include/linux/ktime.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/jiffies.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/jiffies.h \
  /home/mtmatt/rex-with-driver/build/linux/include/generated/timeconst.h \
  /home/mtmatt/rex-with-driver/linux/include/vdso/ktime.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/timekeeping.h \
    $(wildcard include/config/POSIX_AUX_CLOCKS) \
    $(wildcard include/config/GENERIC_CMOS_UPDATE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/clocksource_ids.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/debugobjects.h \
    $(wildcard include/config/DEBUG_OBJECTS) \
    $(wildcard include/config/DEBUG_OBJECTS_FREE) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/uprobes.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/notifier.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/srcu.h \
    $(wildcard include/config/TINY_SRCU) \
    $(wildcard include/config/NEED_SRCU_NMI_SAFE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/workqueue.h \
    $(wildcard include/config/DEBUG_OBJECTS_WORK) \
    $(wildcard include/config/FREEZER) \
    $(wildcard include/config/WQ_WATCHDOG) \
  /home/mtmatt/rex-with-driver/linux/include/linux/rcu_segcblist.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/srcutree.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/rcu_node_tree.h \
    $(wildcard include/config/RCU_FANOUT) \
    $(wildcard include/config/RCU_FANOUT_LEAF) \
  /home/mtmatt/rex-with-driver/linux/include/linux/percpu_counter.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/mmu.h \
    $(wildcard include/config/MODIFY_LDT_SYSCALL) \
    $(wildcard include/config/ADDRESS_MASKING) \
    $(wildcard include/config/BROADCAST_TLB_FLUSH) \
  /home/mtmatt/rex-with-driver/linux/include/linux/page-flags.h \
    $(wildcard include/config/PAGE_IDLE_FLAG) \
    $(wildcard include/config/ARCH_USES_PG_ARCH_2) \
    $(wildcard include/config/ARCH_USES_PG_ARCH_3) \
    $(wildcard include/config/MIGRATION) \
    $(wildcard include/config/HUGETLB_PAGE_OPTIMIZE_VMEMMAP) \
  /home/mtmatt/rex-with-driver/linux/include/linux/local_lock.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/local_lock_internal.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/zswap.h \
    $(wildcard include/config/ZSWAP) \
  /home/mtmatt/rex-with-driver/linux/include/linux/memory_hotplug.h \
    $(wildcard include/config/ARCH_HAS_ADD_PAGES) \
    $(wildcard include/config/MEMORY_HOTREMOVE) \
  /home/mtmatt/rex-with-driver/build/linux/arch/x86/include/generated/asm/mmzone.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/mmzone.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/topology.h \
    $(wildcard include/config/USE_PERCPU_NUMA_NODE_ID) \
    $(wildcard include/config/SCHED_SMT) \
    $(wildcard include/config/GENERIC_ARCH_TOPOLOGY) \
  /home/mtmatt/rex-with-driver/linux/include/linux/arch_topology.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/topology.h \
    $(wildcard include/config/X86_LOCAL_APIC) \
    $(wildcard include/config/SCHED_MC_PRIO) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/mpspec.h \
    $(wildcard include/config/EISA) \
    $(wildcard include/config/X86_MPPARSE) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/mpspec_def.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/x86_init.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/apicdef.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/topology.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/cpu_smt.h \
    $(wildcard include/config/HOTPLUG_SMT) \
  /home/mtmatt/rex-with-driver/linux/include/linux/sysctl.h \
    $(wildcard include/config/SYSCTL) \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/sysctl.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/elf.h \
    $(wildcard include/config/ARCH_HAVE_EXTRA_ELF_NOTES) \
    $(wildcard include/config/ARCH_USE_GNU_PROPERTY) \
    $(wildcard include/config/ARCH_HAVE_ELF_PROT) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/elf.h \
    $(wildcard include/config/X86_X32_ABI) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/ia32.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/user.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/user_64.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/fsgsbase.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/vdso.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/elf.h \
  /home/mtmatt/rex-with-driver/linux/include/uapi/linux/elf-em.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kobject.h \
    $(wildcard include/config/UEVENT_HELPER) \
    $(wildcard include/config/DEBUG_KOBJECT_RELEASE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/sysfs.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kernfs.h \
    $(wildcard include/config/KERNFS) \
  /home/mtmatt/rex-with-driver/linux/include/linux/idr.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/radix-tree.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/xarray.h \
    $(wildcard include/config/XARRAY_MULTI) \
  /home/mtmatt/rex-with-driver/linux/include/linux/sched/mm.h \
    $(wildcard include/config/MMU_LAZY_TLB_REFCOUNT) \
    $(wildcard include/config/ARCH_HAS_MEMBARRIER_CALLBACKS) \
    $(wildcard include/config/ARCH_HAS_SYNC_CORE_BEFORE_USERMODE) \
  /home/mtmatt/rex-with-driver/linux/include/linux/sync_core.h \
    $(wildcard include/config/ARCH_HAS_PREPARE_SYNC_CORE_CMD) \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/sync_core.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/sched/coredump.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/kobject_ns.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/moduleparam.h \
    $(wildcard include/config/ALPHA) \
    $(wildcard include/config/PPC64) \
  /home/mtmatt/rex-with-driver/linux/include/linux/rbtree_latch.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/error-injection.h \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/error-injection.h \
  /home/mtmatt/rex-with-driver/linux/include/linux/dynamic_debug.h \
  /home/mtmatt/rex-with-driver/linux/arch/x86/include/asm/module.h \
    $(wildcard include/config/UNWINDER_ORC) \
  /home/mtmatt/rex-with-driver/linux/include/asm-generic/module.h \
    $(wildcard include/config/HAVE_MOD_ARCH_SPECIFIC) \
  /home/mtmatt/rex-with-driver/linux/include/linux/export-internal.h \
    $(wildcard include/config/PARISC) \

rex_test.mod.o: $(deps_rex_test.mod.o)

$(deps_rex_test.mod.o):

rex_test.mod.o: $(wildcard /home/mtmatt/rex-with-driver/build/linux/tools/objtool/objtool)
