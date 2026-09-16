#!/usr/bin/env bash
set -Eeuo pipefail

target=${1:?usage: build-package.sh TARGET CHEZ_SOURCE OUTPUT_DIR}
chez_source=${2:?usage: build-package.sh TARGET CHEZ_SOURCE OUTPUT_DIR}
output_dir=${3:?usage: build-package.sh TARGET CHEZ_SOURCE OUTPUT_DIR}
api=${ANDROID_API:-28}

case "$target" in
  phone)
    abi=armeabi-v7a
    machine=tarmv7le
    clang_target=armv7a-linux-androideabi
    elf_machine='ARM'
    ;;
  tablet)
    abi=arm64-v8a
    machine=tarm64le
    clang_target=aarch64-linux-android
    elf_machine='AArch64'
    ;;
  *)
    printf 'unsupported Ish Android target: %s\n' "$target" >&2
    exit 2
    ;;
esac

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
chez_source=$(cd "$chez_source" && pwd)
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
if [[ -z $ndk ]]; then
  android_home=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
  [[ -n $android_home ]] || {
    printf '%s\n' 'Android SDK/NDK location is not available on this build host' >&2
    exit 2
  }
  ndk=$(find "$android_home/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
    sort -V | tail -n 1)
fi
[[ -n $ndk && -d $ndk ]] || {
  printf '%s\n' 'Android NDK not found on this build host' >&2
  exit 2
}

ndk_bin="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
cc="$ndk_bin/${clang_target}${api}-clang"
readelf="$ndk_bin/llvm-readelf"
strip="$ndk_bin/llvm-strip"
for tool in "$cc" "$readelf" "$strip"; do
  [[ -x $tool ]] || {
    printf 'required Android NDK tool is missing: %s\n' "$tool" >&2
    exit 2
  }
done

scheme_source="$repo_root/_/build/exec/ish-backend_app/ish-backend.ss"
[[ -f $scheme_source ]] || {
  printf 'generated Ish Chez source is missing: %s\n' "$scheme_source" >&2
  exit 2
}

work="$repo_root/_/build/android-$target"
rm -rf "$work" "$output_dir/bin" "$output_dir/libexec" "$output_dir/receipts"
mkdir -p "$work" "$output_dir/bin" "$output_dir/libexec/ish" "$output_dir/receipts"

# Build a threaded host portable-bytecode Chez first. Its bootquick target creates both
# target boot files and xc-<machine>/s/xpatch, which is Chez's supported path
# for making compile-program emit code for another machine type.
pushd "$chez_source" >/dev/null
./configure --pb --threads --disable-x11 --disable-curses --disable-iconv
make -j2
make bootquick XM="$machine"
host_scheme="$chez_source/tpb/bin/tpb/scheme"
xpatch="$chez_source/xc-$machine/s/xpatch"
[[ -x $host_scheme && -f $xpatch ]] || {
  printf '%s\n' 'Chez did not produce the host compiler and target cross patch' >&2
  exit 3
}

cross_program="$work/compile-ish.ss"
target_program="$work/ish-backend.so"
cat >"$cross_program" <<EOF
(load "$xpatch")
(parameterize ([optimize-level 3] [compile-file-message #f])
  (compile-program "$scheme_source" "$target_program"))
EOF
"$host_scheme" --script "$cross_program"
[[ -s $target_program ]] || {
  printf '%s\n' 'Chez cross compilation did not produce ish-backend.so' >&2
  exit 3
}

# Reconfigure the same pinned Chez source for the Android kernel. The target
# boot files above make --force legitimate; target code is never executed on
# the Ubuntu build host.
make clean >/dev/null 2>&1 || true
CC="$cc" CC_FOR_BUILD=cc ./configure \
  --cross --force -m="$machine" \
  --disable-x11 --disable-curses --disable-iconv --disable-hard-links

# Chez infers t*le as a Linux target and adds separate librt and libpthread.
# Android/Bionic provides those APIs from libc, so keep -pthread compilation
# flags but remove only the two nonexistent target libraries before linking.
sed -i \
  -e '/^LIBS=/s/[[:space:]]-lrt//g' \
  -e '/^LIBS=/s/[[:space:]]-lpthread//g' \
  "$machine/Mf-config"
make -j2

target_scheme="$chez_source/$machine/bin/$machine/scheme"
petite_boot="$chez_source/$machine/boot/$machine/petite.boot"
scheme_boot="$chez_source/$machine/boot/$machine/scheme.boot"
for path in "$target_scheme" "$petite_boot" "$scheme_boot"; do
  [[ -f $path ]] || {
    printf 'Chez Android build is missing: %s\n' "$path" >&2
    exit 3
  }
done
popd >/dev/null

runtime="$output_dir/libexec/ish"
cp "$target_scheme" "$runtime/scheme"
cp "$petite_boot" "$runtime/petite.boot"
cp "$scheme_boot" "$runtime/scheme.boot"
cp "$target_program" "$runtime/ish-backend.so"

"$cc" -std=c11 -Wall -Wextra -Werror -fPIC -shared \
  -o "$runtime/libish_runtime.so" "$repo_root/_/runtime/execute.c"
"$cc" -std=c11 -Wall -Wextra -Werror \
  -o "$output_dir/bin/ish" "$repo_root/_/android/launch.c"
"$strip" --strip-unneeded "$runtime/scheme" "$runtime/libish_runtime.so" "$output_dir/bin/ish"
chmod 0755 "$output_dir/bin/ish" "$runtime/scheme" "$runtime/ish-backend.so"

for elf in "$output_dir/bin/ish" "$runtime/scheme" "$runtime/libish_runtime.so"; do
  elf_header=$("$readelf" -h "$elf")
  if ! grep -Eq "Machine:[[:space:]]+$elf_machine" <<<"$elf_header"; then
    printf 'wrong ELF machine for %s\n' "$elf" >&2
    printf '%s\n' "$elf_header" >&2
    exit 3
  fi
done

# Cat Food must receive a real Ish entrypoint, not an alias to an Oils shell.
test ! -L "$output_dir/bin/ish"
if grep -aE '/(ysh|osh|oils-for-unix)([[:space:]\000]|$)' "$output_dir/bin/ish" >/dev/null; then
  printf '%s\n' 'Android Ish launcher unexpectedly names an Oils shell' >&2
  exit 3
fi

ndk_revision=$(sed -n 's/^Pkg.Revision[[:space:]]*=[[:space:]]*//p' \
  "$ndk/source.properties" 2>/dev/null | head -n 1)
compiler_line=$("$cc" --version | head -n 1)
chez_sha=$(git -C "$chez_source" rev-parse HEAD)
idric_revision=$(sed -n 's/^revision = "\([0-9a-f][0-9a-f]*\)"$/\1/p' \
  "$repo_root/_/idric.lock")

{
  printf 'format\tish-android-runtime-v1\n'
  printf 'source\tisomorphisms/grease\n'
  printf 'source_sha\t%s\n' "${ISH_SOURCE_SHA:-unknown}"
  printf 'idric_sha\t%s\n' "$idric_revision"
  printf 'chez_source\tcisco/ChezScheme\n'
  printf 'chez_sha\t%s\n' "$chez_sha"
  printf 'target\t%s\n' "$target"
  printf 'abi\t%s\n' "$abi"
  printf 'chez_machine\t%s\n' "$machine"
  printf 'android_api\t%s\n' "$api"
  printf 'ndk_revision\t%s\n' "${ndk_revision:-unknown}"
  printf 'compiler\t%s\n' "$compiler_line"
  printf 'entrypoint\tbin/ish\n'
  printf 'engine\tlibexec/ish/ish-backend.so\n'
  printf 'physical_device_execution\tPENDING\n'
} >"$output_dir/receipts/build.tsv"

sha256sum \
  "$output_dir/bin/ish" \
  "$runtime/scheme" \
  "$runtime/petite.boot" \
  "$runtime/scheme.boot" \
  "$runtime/ish-backend.so" \
  "$runtime/libish_runtime.so" \
  >"$output_dir/receipts/files.sha256"
"$readelf" -h "$output_dir/bin/ish" >"$output_dir/receipts/ish-elf-header.txt"
"$readelf" -h "$runtime/scheme" >"$output_dir/receipts/scheme-elf-header.txt"
"$readelf" -d "$runtime/scheme" >"$output_dir/receipts/scheme-elf-dynamic.txt" 2>/dev/null || true

printf 'Ish %s Android package built at %s\n' "$target" "$output_dir"
