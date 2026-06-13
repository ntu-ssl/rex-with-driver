# Baseline / control experiment for recover_driver: no Rex extension at
# all, just the buggy driver module and a trigger.  Intentionally not
# wired into `meson test` — the expected outcome is a kernel panic, so
# the sanity-test harness (which waits for auto_grade.txt) cannot grade
# it.  See README.md for the manual run.

baseline_trigger = executable(
  'event-trigger',
  'event-trigger.c',
  build_by_default: true,
  dependencies: [kernel_dep],
  pie: true
)

# for the driver: just copy the driver/
_baseline_driver_src = join_paths(meson.current_source_dir(), 'driver')

baseline_copy_driver = custom_target(
  'copy-driver',
  output: ['driver'],
  command: ['cp', '-rT', _baseline_driver_src, '@OUTPUT0@'],
  console: false,
  build_by_default: true,
  build_always_stale: true,
)

# Build rex_baseline.ko in the copied driver dir (needs the kernel from
# build_deps).  Not built by default; build it with
#   meson compile samples/baseline_driver/baseline_driver-ko:custom
baseline_sh = find_program('sh')

baseline_ko = custom_target(
  'baseline_driver-ko',
  output: ['rex_baseline_ko_stamp'],
  command: [
    baseline_sh, '-c',
    'make -C "' +
    join_paths(meson.current_build_dir(), 'driver') + '" && touch "' +
    join_paths(meson.current_build_dir(), 'rex_baseline_ko_stamp') + '"'
  ],
  depends: baseline_copy_driver,
  console: false,
  build_by_default: false,
)

# Copy the test script next to the binaries so the manual q-script run
# can use a stable path in the build dir.
baseline_test_copy = custom_target(
  'baseline_runtest',
  output: ['runtest.py'],
  input: join_paths(meson.current_source_dir(), 'tests/runtest.py'),
  command: [
    'cp', '@INPUT@', '@OUTPUT@',
  ],
  build_by_default: true,
)
