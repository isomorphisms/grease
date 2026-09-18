#!/usr/bin/env sh
set -eu

target=${1:?usage: accept-package.sh phone|tablet PACKAGE_DIR}
package=${2:?usage: accept-package.sh phone|tablet PACKAGE_DIR}
runtime=$package/libexec/ish
receipt=$package/receipts/build.tsv

case "$target" in
  phone)
    expected_uname=armv7l
    expected_abi=armeabi-v7a
    ;;
  tablet)
    expected_uname=aarch64
    expected_abi=arm64-v8a
    ;;
  *)
    printf 'unsupported Ish Android target: %s\n' "$target" >&2
    exit 2
    ;;
esac

fail() {
  printf 'FAIL  %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'PASS  %s\n' "$*"
}

test -x "$package/bin/ish" || fail 'missing bin/ish'
test -x "$runtime/scheme" || fail 'missing bundled Chez'
test -s "$runtime/ish-backend.so" || fail 'missing compiled Ish program'
test -s "$runtime/libish_runtime.so" || fail 'missing Ish native runtime'
test -s "$receipt" || fail 'missing build receipt'
test -s "$package/receipts/files.sha256" || fail 'missing file digest receipt'

actual_uname=$(uname -m)
actual_abi=
if command -v getprop >/dev/null 2>&1; then
  actual_abi=$(getprop ro.product.cpu.abi 2>/dev/null || true)
fi
if [ -n "$actual_abi" ]; then
  [ "$actual_abi" = "$expected_abi" ] ||
    fail "device ABI is $actual_abi, expected $expected_abi"
  pass "device ABI $actual_abi (kernel $actual_uname)"
else
  [ "$actual_uname" = "$expected_uname" ] ||
    fail "device architecture is $actual_uname, expected $expected_uname"
  pass "device architecture $actual_uname"
fi

grep -F "target	$target" "$receipt" >/dev/null ||
  fail "package target is not $target"
grep -F "abi	$expected_abi" "$receipt" >/dev/null ||
  fail "package ABI is not $expected_abi"
grep -F 'physical_device_execution	PENDING' "$receipt" >/dev/null ||
  fail 'cloud receipt no longer preserves the pending physical boundary'
pass "package identity $target/$expected_abi"

while read -r digest recorded_path; do
  case "$recorded_path" in
    *build/package/*) relative=${recorded_path#*build/package/} ;;
    ./*) relative=${recorded_path#./} ;;
    *) fail "unexpected digest receipt path: $recorded_path" ;;
  esac
  actual=$(sha256sum "$package/$relative" | awk '{print $1}')
  [ "$actual" = "$digest" ] || fail "digest mismatch for $relative"
done < "$package/receipts/files.sha256"
pass 'all packaged file digests'

temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

LD_LIBRARY_PATH="$runtime${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"   "$runtime/scheme" -B "$runtime/petite.boot" -B "$runtime/scheme.boot"   --version >/dev/null
pass 'bundled Chez starts'

LD_LIBRARY_PATH="$runtime${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"   "$runtime/scheme" -B "$runtime/petite.boot" -B "$runtime/scheme.boot"   -q >"$temporary/chez.stdout" 2>"$temporary/chez.stderr" <<'EOF'
(display "CHEZ-EVAL-PASS")
(newline)
(exit 0)
EOF
grep -Fx 'CHEZ-EVAL-PASS' "$temporary/chez.stdout" >/dev/null ||
  fail 'bundled Chez did not evaluate Scheme'
test ! -s "$temporary/chez.stderr" ||
  fail 'bundled Chez emitted a diagnostic during ordinary evaluation'
pass 'bundled Chez evaluation'

source_file=$temporary/source.ish

printf '%s\n' '/system/bin/toybox echo café $HOME;*' >"$source_file"
actual=$("$package/bin/ish" "$source_file")
[ "$actual" = 'café $HOME;*' ] ||
  fail "literal input execution returned <$actual>"
pass 'exact path and literal UTF-8 inputs'

printf '%s\n' '/system/bin/toybox env' >"$source_file"
ISH_ACCEPTANCE_VALUE=preserved   "$package/bin/ish" "$source_file" >"$temporary/environment"
grep -Fx 'ISH_ACCEPTANCE_VALUE=preserved' "$temporary/environment" >/dev/null ||
  fail 'requested program did not inherit the caller environment'
pass 'environment inheritance'

printf '%s\n' '/system/bin/toybox cat' >"$source_file"
printf '\000\377Z' >"$temporary/incoming"
"$package/bin/ish" "$source_file"   <"$temporary/incoming" >"$temporary/outgoing"
cmp "$temporary/incoming" "$temporary/outgoing" >/dev/null ||
  fail 'requested program did not inherit exact standard input bytes'
pass 'standard input inheritance'

printf '%s\n' '/system/bin/toybox false' >"$source_file"
set +e
"$package/bin/ish" "$source_file" >/dev/null 2>"$temporary/false.stderr"
status=$?
set -e
[ "$status" -eq 1 ] ||
  fail "requested program status was $status, expected 1"
test ! -s "$temporary/false.stderr" ||
  fail 'successful process replacement emitted a diagnostic'
pass 'process status inheritance'

printf '%s\n' 'toybox echo path-search-must-not-happen' >"$source_file"
set +e
PATH="/system/bin:$PATH" "$package/bin/ish" "$source_file"   >"$temporary/path.stdout" 2>"$temporary/path.stderr"
status=$?
set -e
[ "$status" -eq 126 ] ||
  fail "PATH refusal status was $status, expected 126"
test ! -s "$temporary/path.stdout" ||
  fail 'PATH refusal produced standard output'
grep -F 'could not replace ish with executable "toybox"'   "$temporary/path.stderr" >/dev/null ||
  fail 'PATH refusal diagnostic did not identify the exact executable'
pass 'no PATH search'

printf '%s\n' '/definitely/not/present/ish-probe alpha beta' >"$source_file"
set +e
"$package/bin/ish" "$source_file"   >"$temporary/missing.stdout" 2>"$temporary/missing.stderr"
status=$?
set -e
[ "$status" -eq 126 ] ||
  fail "missing executable status was $status, expected 126"
test ! -s "$temporary/missing.stdout" ||
  fail 'missing executable produced standard output'
grep -F 'could not replace ish with executable "/definitely/not/present/ish-probe"'   "$temporary/missing.stderr" >/dev/null ||
  fail 'missing executable diagnostic lost source execution identity'
pass 'missing executable behavior'

printf 'bad\000name input\n' >"$source_file"
set +e
"$package/bin/ish" "$source_file"   >"$temporary/nul.stdout" 2>"$temporary/nul.stderr"
status=$?
set -e
[ "$status" -eq 2 ] ||
  fail "NUL source status was $status, expected 2"
grep -F 'source contains NUL text' "$temporary/nul.stderr" >/dev/null ||
  fail 'NUL source diagnostic missing'
pass 'NUL source rejection'

printf '\377\n' >"$source_file"
set +e
"$package/bin/ish" "$source_file"   >"$temporary/utf8.stdout" 2>"$temporary/utf8.stderr"
status=$?
set -e
[ "$status" -eq 2 ] ||
  fail "invalid UTF-8 status was $status, expected 2"
grep -F 'source is not UTF-8 near byte 0' "$temporary/utf8.stderr" >/dev/null ||
  fail 'invalid UTF-8 diagnostic missing'
pass 'invalid UTF-8 rejection'

: >"$source_file"
set +e
"$package/bin/ish" "$source_file"   >"$temporary/empty.stdout" 2>"$temporary/empty.stderr"
status=$?
set -e
[ "$status" -eq 2 ] ||
  fail "empty source status was $status, expected 2"
grep -F 'incomplete incantation: expected a name at [0,0)'   "$temporary/empty.stderr" >/dev/null ||
  fail 'empty source diagnostic missing'
pass 'empty source rejection'

printf '%s\n' 'PHYSICAL DEVICE ISH EXECUTION: PASS'
printf 'target\t%s\n' "$target"
printf 'abi\t%s\n' "$expected_abi"
printf 'source_sha\t%s\n' "$(sed -n 's/^source_sha[[:space:]]*//p' "$receipt")"
printf 'idric_sha\t%s\n' "$(sed -n 's/^idric_sha[[:space:]]*//p' "$receipt")"
