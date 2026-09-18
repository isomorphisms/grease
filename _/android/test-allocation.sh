#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

package_dir=${1:?usage: test-allocation.sh PACKAGE_DIR PROBE_PROGRAM TEST_DIRECTORY}
probe_program=${2:?usage: test-allocation.sh PACKAGE_DIR PROBE_PROGRAM TEST_DIRECTORY}
test_directory=${3:?usage: test-allocation.sh PACKAGE_DIR PROBE_PROGRAM TEST_DIRECTORY}

package_dir=$(cd "$package_dir" && pwd)
probe_program=$(cd "$(dirname "$probe_program")" && pwd)/$(basename "$probe_program")
mkdir -p "$test_directory"
test_directory=$(cd "$test_directory" && pwd)

runtime="$package_dir/libexec/ish"
probe_file="$test_directory/ish-keep-size-probe"

for path in \
  "$runtime/scheme" \
  "$runtime/petite.boot" \
  "$runtime/scheme.boot" \
  "$runtime/libish_runtime.so" \
  "$probe_program"; do
  test -e "$path"
done

rm -f "$probe_file"

printf 'architecture\t%s\n' "$(uname -m)"
printf 'test_directory\t%s\n' "$test_directory"
printf 'filesystem_type\t%s\n' "$(stat -f -c '%T' "$test_directory")"
printf 'probe_program\t%s\n' "$probe_program"

set +e
(
  cd "$test_directory"
  LD_LIBRARY_PATH="$runtime${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  IDRIS2_INC_SRC="$runtime" \
    "$runtime/scheme" \
      -B "$runtime/petite.boot" \
      -B "$runtime/scheme.boot" \
      --program "$probe_program"
)
status=$?
set -e

printf 'probe_status\t%s\n' "$status"

if test -e "$probe_file"; then
  size=$(stat -c '%s' "$probe_file")
  blocks=$(stat -c '%b' "$probe_file")
  printf 'visible_size\t%s\n' "$size"
  printf 'allocated_blocks\t%s\n' "$blocks"
else
  size=missing
  blocks=missing
  printf 'visible_size\tmissing\n'
  printf 'allocated_blocks\tmissing\n'
fi

if test "$status" -eq 0; then
  test "$size" = 0
  test "$blocks" -gt 0
  printf 'ISH_KEEP_SIZE_PHYSICAL\tPASS\n'
else
  printf 'ISH_KEEP_SIZE_PHYSICAL\tOPERATING_SYSTEM_ERROR\n'
fi

rm -f "$probe_file"
exit "$status"
