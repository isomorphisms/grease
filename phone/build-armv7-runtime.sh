#!/usr/bin/env bash
set -Eeuo pipefail

source_tree=${1:?usage: build-armv7-runtime.sh SOURCE_TREE OUTPUT_DIR}
output_dir=${2:?usage: build-armv7-runtime.sh SOURCE_TREE OUTPUT_DIR}
api=${ANDROID_API:-24}
abi=${ANDROID_ABI:-armeabi-v7a}

case "$abi" in
  armeabi-v7a) target=armv7a-linux-androideabi ;;
  *)
    echo "unsupported phone Grease ABI: $abi" >&2
    exit 2
    ;;
esac

ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
if [[ -z $ndk ]]; then
  android_home=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
  [[ -n $android_home ]] || {
    echo 'Android SDK/NDK location is not available on this build host' >&2
    exit 2
  }
  ndk=$(find "$android_home/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
    sort -V | tail -n 1)
fi
[[ -n $ndk && -d $ndk ]] || {
  echo 'Android NDK not found on this build host' >&2
  exit 2
}

ndk_bin="$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin"
cc="$ndk_bin/${target}${api}-clang"
cxx="$ndk_bin/${target}${api}-clang++"
llvm_strip="$ndk_bin/llvm-strip"
readelf="$ndk_bin/llvm-readelf"

for tool in "$cc" "$cxx" "$llvm_strip" "$readelf"; do
  [[ -x $tool ]] || {
    echo "required Android NDK tool is missing: $tool" >&2
    exit 2
  }
done

source_tree=$(cd "$source_tree" && pwd)
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)

[[ -x "$source_tree/_build/oils.sh" ]] || {
  echo "generated Oils/Grease native build script is missing: $source_tree/_build/oils.sh" >&2
  exit 2
}

wrapper_dir=$(mktemp -d)
cleanup() {
  rm -rf "$wrapper_dir"
}
trap cleanup EXIT

cat > "$wrapper_dir/android-armv7-clang++" <<EOF
#!/bin/sh
exec "$cxx" "\$@"
EOF
cat > "$wrapper_dir/strip" <<EOF
#!/bin/sh
exec "$llvm_strip" "\$@"
EOF
chmod +x "$wrapper_dir/android-armv7-clang++" "$wrapper_dir/strip"
export PATH="$wrapper_dir:$PATH"

pushd "$source_tree" >/dev/null

# Native Grease only needs the C++ configuration.  The legacy C configuration
# probes execute target binaries and therefore cannot run while cross-compiling.
# Source configure in its documented test mode and run only compile-time probes.
export _OIL_CONFIGURE_TEST=1
export _OIL_DEV=''
# shellcheck disable=SC1091
. ./configure
FLAG_cxx_for_configure=$cc
FLAG_without_readline=1
FLAG_without_systemtap_sdt=1
mkdir -p _build

cc_quiet build/detect-cc.c || {
  echo 'Android target compiler cannot compile a basic C program' >&2
  exit 3
}
detect_readline
detect_libc
detect_systemtap_sdt
echo_cpp > _build/detected-cpp-config.h
echo_shell_vars > _build/detected-config.sh
unset _OIL_CONFIGURE_TEST

export LDFLAGS="${LDFLAGS:-} -static-libstdc++"
OILS_PARALLEL_BUILD=${OILS_PARALLEL_BUILD:-1} \
  _build/oils.sh \
    --cxx android-armv7-clang++ \
    --variant opt \
    --without-readline

runtime=_bin/android-armv7-clang++-opt-sh/oils-for-unix.stripped
[[ -x $runtime ]] || {
  echo "cross-build did not produce $runtime" >&2
  exit 3
}

"$readelf" -h "$runtime" | grep -Eq 'Machine:[[:space:]]+ARM' || {
  echo 'Grease phone runtime is not an ARM ELF binary' >&2
  "$readelf" -h "$runtime" >&2
  exit 3
}
if "$readelf" -d "$runtime" 2>/dev/null | grep -q 'libc++_shared\.so'; then
  echo 'Grease phone runtime unexpectedly depends on libc++_shared.so' >&2
  exit 3
fi

rm -rf "$output_dir/bin" "$output_dir/receipts"
mkdir -p "$output_dir/bin" "$output_dir/receipts"
cp "$runtime" "$output_dir/bin/ysh"
cat > "$output_dir/bin/grease" <<'EOF'
#!/bin/sh
self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$self_dir/ysh" "$@"
EOF
chmod +x "$output_dir/bin/grease" "$output_dir/bin/ysh"

source_sha=${GREASE_SOURCE_SHA:-unknown}
packaging_sha=${GREASE_PACKAGING_SHA:-unknown}
ndk_revision=$(sed -n 's/^Pkg.Revision[[:space:]]*=[[:space:]]*//p' "$ndk/source.properties" 2>/dev/null | head -n 1)
compiler_line=$("$cxx" --version | head -n 1)

{
  printf 'format\tgrease-phone-runtime-v1\n'
  printf 'source\tisomorphisms/oils\n'
  printf 'source_sha\t%s\n' "$source_sha"
  printf 'packaging_source\tisomorphisms/grease\n'
  printf 'packaging_sha\t%s\n' "$packaging_sha"
  printf 'abi\t%s\n' "$abi"
  printf 'android_api\t%s\n' "$api"
  printf 'ndk_revision\t%s\n' "${ndk_revision:-unknown}"
  printf 'compiler\t%s\n' "$compiler_line"
  printf 'entrypoint\tbin/grease\n'
  printf 'engine\tbin/ysh\n'
  printf 'physical_phone_execution\tPENDING\n'
} > "$output_dir/receipts/build.tsv"

sha256sum "$output_dir/bin/ysh" > "$output_dir/receipts/ysh.sha256"
"$readelf" -h "$output_dir/bin/ysh" > "$output_dir/receipts/elf-header.txt"
"$readelf" -d "$output_dir/bin/ysh" > "$output_dir/receipts/elf-dynamic.txt" 2>/dev/null || true

popd >/dev/null

printf 'Grease ARMv7 runtime built: %s/bin/grease\n' "$output_dir"
