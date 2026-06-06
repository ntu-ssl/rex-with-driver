build_dir = run_command(
  realpath,
  '--relative-to',
  meson.current_source_dir(),
  meson.current_build_dir(),
  capture: true,
  check: true
).stdout().strip()

env = environment()
env.prepend('PATH', rust_bin)
env.set('LINUX_OBJ', kbuild_dir)
env.set('LINUX_SRC', join_paths(meson.project_source_root(), './linux'))
env.set('CARGO_TARGET_DIR', join_paths(build_dir, 'target'))

fwd_clippy = custom_target(
  'fwd_driver-clippy',
  output: ['target'],
  command: [
    cargo_wrapper, rust_bin, '-Z',
    'unstable-options',
    '-C', meson.current_source_dir(),
    'clippy', '-qr'
  ],
  env: env,
  console: false,
  build_by_default: true
)

fwd_build = custom_target(
  'fwd_driver-build',
  output: ['fwd_driver'],
  command: [
    cargo_wrapper, rust_bin, '-Z',
    'unstable-options',
    '-C', meson.current_source_dir(),
    'rustc', '-qr', '--',
    '-Cenable_rex'
  ],
  depends: fwd_clippy,
  env: env,
  console: false,
  build_by_default: true
)

fwd_loader = executable(
  'loader',
  'loader.c',
  build_by_default: true,
  dependencies: [librex_dep, libbpf_dep, kernel_dep],
  pie: true
)

fwd_trigger = executable(
  'event-trigger',
  'event-trigger.c',
  build_by_default: true,
  dependencies: [kernel_dep],
  pie: true
)

# for the driver: just copy the driver/
_driver_src = join_paths(meson.current_source_dir(), 'driver')

custom_target(
  'copy-driver',
  output: ['driver'],
  command: ['cp', '-rT', _driver_src, '@OUTPUT0@'],
  console: false,
  build_by_default: true,
  build_always_stale: true,
)