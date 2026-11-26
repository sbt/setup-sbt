#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

# Exercise the actual composite step, without downloading sbt or contacting caches.
# Ruby and its YAML library are available on all three CI runner images.
ruby -ryaml -rshellwords - "$test_dir" <<'RUBY'
action = YAML.load_file('action.yml')
steps = action.fetch('runs').fetch('steps')
paths = steps.find { |step| step['id'] == 'cache-paths' }
disk = steps.find { |step| step['id'] == 'disk-cache' }
distribution = steps.find { |step| step['id'] == 'cache-dir' }
raise 'Unexpected default policy' unless action['inputs']['disk-cache-restore-policy']['default'] == 'all'
raise 'Disk cache must remain enabled by default' unless action['inputs']['disk-cache']['default'] == true
raise 'Disk-cache opt-out changed' unless disk['if'] == "inputs.disk-cache == 'true'"
raise 'Primary key changed' unless disk['with']['key'] == "${{ steps.cache-paths.outputs.sbt_diskcachekey }}-${{ steps.cache-paths.outputs.sbt_monday }}-${{ hashFiles('**/*.sbt', '**/*.properties') }}"
raise 'Restore policy is not connected' unless disk['with']['restore-keys'] == '${{ steps.cache-paths.outputs.sbt_diskcache_restore_keys }}'
raise 'Distribution cache changed' unless distribution['with'] == {
  'path' => '${{ steps.cache-paths.outputs.sbt_toolpath }}',
  'key' => '${{ steps.cache-paths.outputs.sbt_cachekey }}'
}
raise 'Unsafe policy interpolation' if paths['run'].include?('${{ inputs.disk-cache-restore-policy }}')
raise 'Missing policy environment variable' unless paths['env']['SBT_DISK_CACHE_RESTORE_POLICY'] == '${{ inputs.disk-cache-restore-policy }}'
File.binwrite(File.join(ARGV[0], 'cache-paths.sh'), paths.fetch('run'))
defaults = {
  'SBT_RUNNER_VERSION' => action['inputs']['sbt-runner-version']['default'],
  'SBT_CACHE_KEY_VERSION' => paths['env']['SBT_CACHE_KEY_VERSION'],
  'SBT_TEST_DEFAULT_POLICY' => action['inputs']['disk-cache-restore-policy']['default']
}
File.binwrite(File.join(ARGV[0], 'defaults.sh'), defaults.map { |key, value| "export #{key}=#{Shellwords.escape(value.to_s)}\n" }.join)
RUBY
# shellcheck source=/dev/null
source "$test_dir/defaults.sh"

export RUNNER_OS="${RUNNER_OS:-Linux}" RUNNER_ARCH="${RUNNER_ARCH:-X64}"
export RUNNER_TEMP="${RUNNER_TEMP:-$test_dir/runner-temp}"
export RUNNER_TOOL_CACHE="$test_dir/tools" LOCALAPPDATA="$test_dir/local"
export SBT_TEST_REAL_DATE
SBT_TEST_REAL_DATE=$(command -v date)
export SBT_TEST_JAVA_VERSION=17.0.12
mkdir -p "$test_dir/bin"
cat > "$test_dir/bin/date" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$RUNNER_OS" == "macOS" ]]; then
  exec "$SBT_TEST_REAL_DATE" -j -f '%Y-%m-%d' "$SBT_TEST_DATE" "$@"
elif [[ "${1:-}" == "-d" ]]; then
  exec "$SBT_TEST_REAL_DATE" "$@"
else
  exec "$SBT_TEST_REAL_DATE" -d "$SBT_TEST_DATE" "$@"
fi
BASH
cat > "$test_dir/bin/java" <<'BASH'
#!/usr/bin/env bash
echo "openjdk version \"$SBT_TEST_JAVA_VERSION\"" >&2
BASH
chmod +x "$test_dir/bin/date" "$test_dir/bin/java"
export PATH="$test_dir/bin:$PATH"

run_paths() {
  : > "$test_dir/output"
  SBT_TEST_DATE="$1" SBT_DISK_CACHE_RESTORE_POLICY="${2-$SBT_TEST_DEFAULT_POLICY}" \
    GITHUB_OUTPUT="$test_dir/output" bash -e -o pipefail "$test_dir/cache-paths.sh"
}

assert_output() {
  if ! grep -Fx -- "$1=$2" "$test_dir/output" > /dev/null; then
    printf 'Expected output: %s=%s\nActual outputs:\n' "$1" "$2" >&2
    cat "$test_dir/output" >&2
    exit 1
  fi
}

base="$RUNNER_OS-$RUNNER_ARCH-java$SBT_TEST_JAVA_VERSION-sbt-diskcache-$SBT_CACHE_KEY_VERSION"
for dates in 2026-11-22:2026-11-16 2026-11-23:2026-11-23 2026-11-24:2026-11-23 \
    2026-01-01:2025-12-29 2024-02-29:2024-02-26; do
  day=${dates%:*}
  monday=${dates#*:}
  run_paths "$day"
  assert_output sbt_diskcache_restore_keys "$base"
  for policy in all current-week none; do
    run_paths "$day" "$policy"
    assert_output sbt_monday "$monday"
    assert_output sbt_diskcachekey "$base"
    assert_output sbt_cachekey "$RUNNER_OS-$RUNNER_ARCH-sbt-runner-$SBT_RUNNER_VERSION-$SBT_CACHE_KEY_VERSION"
    case "$policy" in
      all) assert_output sbt_diskcache_restore_keys "$base" ;;
      current-week) assert_output sbt_diskcache_restore_keys "$base-$monday-" ;;
      none) assert_output sbt_diskcache_restore_keys "" ;;
    esac
  done
done

# Changing the JDK or architecture must still isolate both generated prefixes.
original_arch=$RUNNER_ARCH
export RUNNER_ARCH=ARM64 SBT_TEST_JAVA_VERSION=21.0.4
run_paths 2026-11-24 current-week
assert_output sbt_diskcachekey "$RUNNER_OS-ARM64-java21.0.4-sbt-diskcache-$SBT_CACHE_KEY_VERSION"
assert_output sbt_diskcache_restore_keys "$RUNNER_OS-ARM64-java21.0.4-sbt-diskcache-$SBT_CACHE_KEY_VERSION-2026-11-23-"
export RUNNER_ARCH="$original_arch" SBT_TEST_JAVA_VERSION=17.0.12

# Keep the command substitution literal to check that invalid input is not run.
# shellcheck disable=SC2016
for policy in invalid '' ALL '$(exit 0)'; do
  if run_paths 2026-11-24 "$policy" > "$test_dir/error" 2>&1; then
    printf 'Invalid policy unexpectedly succeeded: %s\n' "$policy" >&2
    exit 1
  fi
  grep -F 'disk-cache-restore-policy must be one of: all, current-week, none' "$test_dir/error" > /dev/null
done
echo "Disk-cache policy checks passed on $RUNNER_OS."

# Give the integration job actual generated prefixes in a unique test namespace.
if [[ "${1:-}" == "--github-output" ]]; then
  export SBT_CACHE_KEY_VERSION="policy-test-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
  base="$RUNNER_OS-$RUNNER_ARCH-java$SBT_TEST_JAVA_VERSION-sbt-diskcache-$SBT_CACHE_KEY_VERSION"
  for policy in all current-week none; do
    run_paths 2026-11-24 "$policy"
    prefix=$(sed -n 's/^sbt_diskcache_restore_keys=//p' "$test_dir/output")
    echo "$policy=$prefix" >> "$GITHUB_OUTPUT"
  done
  {
    echo "primary=$base-2026-11-23-build-a"
    echo "previous=$base-2026-11-16-build-a"
    echo "same-week=$base-2026-11-23-build-b"
  } >> "$GITHUB_OUTPUT"
  mkdir -p "$RUNNER_TEMP/disk-cache-policy-fixture"
  echo fixture > "$RUNNER_TEMP/disk-cache-policy-fixture/marker"
fi
