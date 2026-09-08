#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
temporary=$repo_root/test/tmp
runner=$repo_root/build/exec/ish
probe=$repo_root/test/probe

mkdir -p "$temporary"

source_file=$temporary/one-incantation.ish
actual=$temporary/actual
expected=$temporary/expected
diagnostic=$temporary/diagnostic
trace=$temporary/execve.trace
trace_capability=$temporary/strace-capability
literal_probe=$temporary/'probe;literal'
incoming=$temporary/incoming

cp "$probe" "$literal_probe"
printf '%s %s %s\n' "$literal_probe" 'café' '$HOME;*' >"$source_file"
printf '%s' 'incoming data' >"$incoming"

trace_execve=false
if command -v strace >/dev/null 2>&1 &&
   strace -qq -e trace=execve -o "$trace_capability" /usr/bin/true \
     >/dev/null 2>&1; then
    trace_execve=true
fi

set +e
if "$trace_execve"; then
    env LD_LIBRARY_PATH=caller-ld DYLD_LIBRARY_PATH=caller-dyld \
      IDRIS2_INC_SRC=caller-source __ISH_LAUNCH_ENVIRONMENT=caller-marker \
      ISH_ACCEPTANCE_VALUE=preserved \
      strace -f -qq -e trace=execve -o "$trace" \
      "$runner" "$source_file" <"$incoming" >"$actual" 2>"$diagnostic"
else
    env LD_LIBRARY_PATH=caller-ld DYLD_LIBRARY_PATH=caller-dyld \
      IDRIS2_INC_SRC=caller-source __ISH_LAUNCH_ENVIRONMENT=caller-marker \
      ISH_ACCEPTANCE_VALUE=preserved \
      "$runner" "$source_file" <"$incoming" >"$actual" 2>"$diagnostic"
fi
status=$?
set -e

if [ "$status" -ne 73 ]; then
    printf 'expected probe status 73, got %s\n' "$status" >&2
    cat "$diagnostic" >&2
    exit 1
fi

cat >"$expected" <<EOF
argv-count=3
argv[0]=${#literal_probe}:$literal_probe
argv[1]=5:café
argv[2]=7:\$HOME;*
environment[ISH_ACCEPTANCE_VALUE]=9:preserved
environment[LD_LIBRARY_PATH]=9:caller-ld
environment[DYLD_LIBRARY_PATH]=11:caller-dyld
environment[IDRIS2_INC_SRC]=13:caller-source
environment[__ISH_LAUNCH_ENVIRONMENT]=13:caller-marker
incoming=13:incoming data
EOF

cmp "$expected" "$actual"
test ! -s "$diagnostic"

if "$trace_execve" &&
   grep -E 'execve\("(/usr)?/bin/(ba|da|z|k)?sh"' "$trace" >/dev/null; then
    printf '%s\n' 'ish invoked an existing shell' >&2
    cat "$trace" >&2
    exit 1
fi

missing_source=$temporary/missing.ish
printf '/definitely/not/present/ish-probe alpha beta\n' >"$missing_source"

set +e
"$runner" "$missing_source" >"$actual" 2>"$diagnostic"
missing_status=$?
set -e

test "$missing_status" -eq 126
test ! -s "$actual"
grep -F 'execve failed for "/definitely/not/present/ish-probe" at [0,33)' \
  "$diagnostic" >/dev/null

path_source=$temporary/no-path-search.ish
printf 'probe alpha\n' >"$path_source"

set +e
PATH="$repo_root/test:$PATH" \
  "$runner" "$path_source" >"$actual" 2>"$diagnostic"
path_status=$?
set -e

test "$path_status" -eq 126
test ! -s "$actual"
grep -F 'execve failed for "probe" at [0,5)' "$diagnostic" >/dev/null

invalid_source=$temporary/nul.ish
printf 'bad\000name input\n' >"$invalid_source"

set +e
"$runner" "$invalid_source" >"$actual" 2>"$diagnostic"
invalid_status=$?
set -e

test "$invalid_status" -eq 2
test ! -s "$actual"
grep -F 'source contains NUL text at [3,4)' "$diagnostic" >/dev/null

invalid_utf8_source=$temporary/invalid-utf8.ish
printf '\377\n' >"$invalid_utf8_source"

set +e
"$runner" "$invalid_utf8_source" >"$actual" 2>"$diagnostic"
invalid_utf8_status=$?
set -e

test "$invalid_utf8_status" -eq 2
test ! -s "$actual"
grep -F 'source is not UTF-8 near byte 0' "$diagnostic" >/dev/null

empty_source=$temporary/empty.ish
: >"$empty_source"

set +e
"$runner" "$empty_source" >"$actual" 2>"$diagnostic"
empty_status=$?
set -e

test "$empty_status" -eq 2
test ! -s "$actual"
grep -F 'incomplete incantation: expected a name at [0,0)' \
  "$diagnostic" >/dev/null

printf '%s\n' 'one incantation became one process: PASS'
