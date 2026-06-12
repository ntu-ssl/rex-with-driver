# Route B demo: buggy driver body + kernel-side recovery trampoline.
# No Rex extension / loader — the kernel itself recovers the panic.

guarded_trigger = executable(
  'event-trigger',
  'event-trigger.c',
  build_by_default: true,
  dependencies: [kernel_dep],
  pie: true
)

# for the driver: just copy the driver/
_guarded_driver_src = join_paths(meson.current_source_dir(), 'driver')

guarded_copy_driver = custom_target(
  'copy-driver',
  output: ['driver'],
  command: ['cp', '-rT', _guarded_driver_src, '@OUTPUT0@'],
  console: false,
  build_by_default: true,
  build_always_stale: true,
)

# Build rex_guarded.ko in the copied driver dir (needs the kernel from
# build_deps).  Only the sanity test depends on it; not built by default.
guarded_sh = find_program('sh')

guarded_ko = custom_target(
  'guarded_driver-ko',
  output: ['rex_guarded_ko_stamp'],
  command: [
    guarded_sh, '-c',
    'make -C "' +
    join_paths(meson.current_build_dir(), 'driver') + '" && touch "' +
    join_paths(meson.current_build_dir(), 'rex_guarded_ko_stamp') + '"'
  ],
  depends: guarded_copy_driver,
  console: false,
  build_by_default: false,
)

guarded_sanity_test = custom_target(
  'guarded_sanity_test',
  output: ['runtest.py'],
  input: join_paths(meson.current_source_dir(), 'tests/runtest.py'),
  command: [
    'cp', '@INPUT@', '@OUTPUT@',
  ]
)

guarded_test_env = environment()
guarded_test_env.set('SAMPLE_PATH', meson.current_build_dir())
guarded_test_env.set('Q_SCRIPT',
  join_paths(meson.project_source_root(), 'scripts/q-script/sanity-test-q')
)
guarded_test_env.set('KERNEL_PATH', kbuild_dir)

test('guarded_driver_test',
  python3_bin,
  args: [sanity_test_scripts],
  env: guarded_test_env,
  depends: [guarded_trigger, guarded_sanity_test, guarded_ko],
  is_parallel: false,
  workdir: meson.current_build_dir()
)
