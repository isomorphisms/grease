#!/usr/bin/env bash
set -Eeuo pipefail

package_root=${1:?usage: package-boundary.sh PACKAGE_ROOT ABI}
expected_abi=${2:?usage: package-boundary.sh PACKAGE_ROOT ABI}
entrypoint="$package_root/bin/ish"
receipt="$package_root/receipts/build.tsv"

fail() {
  printf 'Ish package boundary: %s\n' "$1" >&2
  exit 1
}

[[ -f $entrypoint && -x $entrypoint ]] ||
  fail 'bin/ish is not an executable regular file'
[[ ! -L $entrypoint ]] || fail 'bin/ish is a symlink'

for alias in grease ysh osh oils-for-unix; do
  [[ ! -e "$package_root/bin/$alias" ]] ||
    fail "package exposes forbidden shell alias bin/$alias"
done

[[ -x $package_root/libexec/ish/scheme ]] ||
  fail 'private Chez runtime is missing'
[[ -s $package_root/libexec/ish/ish-backend.so ]] ||
  fail 'compiler-generated Ish program is missing'
[[ -f $receipt ]] || fail 'build provenance receipt is missing'

grep -Fx $'source\tisomorphisms/grease' "$receipt" >/dev/null ||
  fail 'receipt does not identify the Ish source repository'
grep -Fx $'entrypoint\tbin/ish' "$receipt" >/dev/null ||
  fail 'receipt does not bind the Ish entrypoint'
grep -Fx $'engine\tlibexec/ish/ish-backend.so' "$receipt" >/dev/null ||
  fail 'receipt does not bind the compiler-generated Ish program'
grep -Fx "$(printf 'abi\t%s' "$expected_abi")" "$receipt" >/dev/null ||
  fail 'receipt ABI does not match the requested package'
grep -Fx $'physical_device_execution\tPENDING' "$receipt" >/dev/null ||
  fail 'cloud package receipt promoted physical-device execution'

if grep -aE '(^|[/[:space:]])(grease|ysh|osh|oils-for-unix)([/[:space:]\000]|$)' \
    "$entrypoint" >/dev/null; then
  fail 'bin/ish names a forbidden shell implementation'
fi

printf 'Ish package boundary PASS (%s)\n' "$expected_abi"
