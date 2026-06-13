recover_build_dir = run_command(
  realpath,
  '--relative-to',
  meson.current_source_dir(),
  meson.current_build_dir(),
  capture: true,
  check: true
).stdout().strip()

recover_env = environment()
recover_env.prepend('PATH', rust_bin)
recover_env.set('LINUX_OBJ', kbuild_dir)
recover_env.set('LINUX_SRC', join_paths(meson.project_source_root(), './linux'))
recover_env.set('CARGO_TARGET_DIR', join_paths(recover_build_dir, 'target'))

recover_clippy = custom_target(
  'recover_driver-clippy',
  output: ['target'],
  command: [
    cargo_wrapper, rust_bin, '-Z',
    'unstable-options',
    '-C', meson.current_source_dir(),
    'clippy', '-qr'
  ],
  env: recover_env,
  console: false,
  build_by_default: true
)

recover_build = custom_target(
  'recover_driver-build',
  output: ['recover_driver'],
  command: [
    cargo_wrapper, rust_bin, '-Z',
    'unstable-options',
    '-C', meson.current_source_dir(),
    'rustc', '-qr', '--',
    '-Cenable_rex'
  ],
  depends: recover_clippy,
  env: recover_env,
  console: false,
  build_by_default: true
)

recover_loader = executable(
  'loader',
  'loader.c',
  build_by_default: true,
  dependencies: [librex_dep, libbpf_dep, kernel_dep],
  pie: true
)

recover_trigger = executable(
  'event-trigger',
  'event-trigger.c',
  build_by_default: true,
  dependencies: [kernel_dep],
  pie: true
)

# for the driver: just copy the driver/
_recover_driver_src = join_paths(meson.current_source_dir(), 'driver')

recover_copy_driver = custom_target(
  'copy-driver',
  output: ['driver'],
  command: ['cp', '-rT', _recover_driver_src, '@OUTPUT0@'],
  console: false,
  build_by_default: true,
  build_always_stale: true,
)

# Build rex_recover.ko in the copied driver dir (needs the kernel from
# build_deps).  Only the sanity test depends on it; not built by default.
sh_bin = find_program('sh')

recover_ko = custom_target(
  'recover_driver-ko',
  output: ['rex_recover_ko_stamp'],
  command: [
    sh_bin, '-c',
    'make -C "' +
    join_paths(meson.current_build_dir(), 'driver') + '" && touch "' +
    join_paths(meson.current_build_dir(), 'rex_recover_ko_stamp') + '"'
  ],
  depends: recover_copy_driver,
  console: false,
  build_by_default: false,
)

recover_sanity_test = custom_target(
  'recover_sanity_test',
  output: ['runtest.py'],
  input: join_paths(meson.current_source_dir(), 'tests/runtest.py'),
  command: [
    'cp', '@INPUT@', '@OUTPUT@',
  ]
)

recover_test_env = environment()
recover_test_env.set('SAMPLE_PATH', meson.current_build_dir())
recover_test_env.set('Q_SCRIPT',
  join_paths(meson.project_source_root(), 'scripts/q-script/sanity-test-q')
)
recover_test_env.set('KERNEL_PATH', kbuild_dir)

test('recover_driver_test',
  python3_bin,
  args: [sanity_test_scripts],
  env: recover_test_env,
  depends: [
    recover_build, recover_loader, recover_trigger,
    recover_sanity_test, recover_ko
  ],
  is_parallel: false,
  workdir: meson.current_build_dir()
)
