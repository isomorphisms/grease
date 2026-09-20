#!/usr/bin/env bash
set -Eeuo pipefail

repository_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

make_fixture() {
  root=$1
  mkdir -p "$root/bin" "$root/libexec/ish" "$root/receipts"
  printf '#!/bin/sh\nexec ../libexec/ish/ish-backend.so "$@"\n' >"$root/bin/ish"
  printf '#!/bin/sh\nexit 0\n' >"$root/libexec/ish/scheme"
  printf 'compiled-ish-program\n' >"$root/libexec/ish/ish-backend.so"
  chmod +x "$root/bin/ish" "$root/libexec/ish/scheme"
  {
    printf 'source\tisomorphisms/grease\n'
    printf 'abi\tarmeabi-v7a\n'
    printf 'entrypoint\tbin/ish\n'
    printf 'engine\tlibexec/ish/ish-backend.so\n'
    printf 'physical_device_execution\tPENDING\n'
  } >"$root/receipts/build.tsv"
}

make_fixture "$work/good"
bash "$repository_root/_/test/package-boundary.sh" \
  "$work/good" armeabi-v7a >/dev/null

cp -a "$work/good" "$work/symlink"
printf '#!/bin/sh\nexit 0\n' >"$work/symlink/bin/ysh"
chmod +x "$work/symlink/bin/ysh"
rm "$work/symlink/bin/ish"
ln -s ysh "$work/symlink/bin/ish"
if bash "$repository_root/_/test/package-boundary.sh" \
    "$work/symlink" armeabi-v7a >"$work/out" 2>"$work/err"; then
  printf 'package boundary accepted an Ish-to-YSH symlink\n' >&2
  exit 1
fi
grep -F 'bin/ish is a symlink' "$work/err" >/dev/null

cp -a "$work/good" "$work/wrapper"
printf '#!/bin/sh\nexec /data/local/tmp/grease "$@"\n' \
  >"$work/wrapper/bin/ish"
chmod +x "$work/wrapper/bin/ish"
if bash "$repository_root/_/test/package-boundary.sh" \
    "$work/wrapper" armeabi-v7a >"$work/out" 2>"$work/err"; then
  printf 'package boundary accepted an Ish-to-Grease wrapper\n' >&2
  exit 1
fi
grep -F 'bin/ish names a forbidden shell implementation' "$work/err" >/dev/null

printf 'Ish package boundary self-test PASS\n'
