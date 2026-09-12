# Live Android sensors

This is the first live Android probe for the proposed Grease hardware namespace.
It deliberately tests the public native Android sensor boundary before adding a
synthetic filesystem, 9P, FUSE, IIO, direct HAL access, or a Termux:API bridge.

The first program is only `sensors`: enumerate the sensors visible through the
phone's `libandroid` and print tab-separated metadata. This is an Android
experiment, not a Grease execution receipt.

## Phone workflow

Do not install a compiler or Android NDK on the phone for this experiment. The
phone is the execution target only: pull the already-built ARMv7 executable,
check it, and run it.

The repository carries the executable as `sensors.armv7.b64` because GitHub's
text-content path is being used for this small experimental artifact. Decode it
on the phone, mark it executable, verify the recorded SHA-256, and run it.

The current executable is 3556 bytes and has SHA-256:

```text
9270b8ebd1243b388a17f24a5cad4883363ca7a5dd122431df2d2a7dc49c87f5
```

It is an ARMv7 Thumb-2 PIE with `/system/bin/linker` as interpreter and one
runtime dependency: the phone's real `libandroid.so`.

## Cloud build

`sensors.c` is freestanding so the cross-build does not need Android headers or
libc. It writes output with ARM Linux system calls and calls only the public
Android sensor symbols it needs.

`link-libandroid-stub.c` is link-time scaffolding only. It gives the host linker
the `libandroid.so` symbol names and SONAME. The stub is not shipped to the
phone; Android's dynamic linker must load the phone's real `libandroid.so`.

The artifact currently checked in was produced with Clang/LLD 17 using:

```sh
clang --target=armv7a-linux-gnueabi -march=armv7-a -mthumb \
  -ffreestanding -fPIC -fno-stack-protector -fno-builtin -nostdlib \
  -fuse-ld=lld -shared -Wl,-soname,libandroid.so -Wl,--no-undefined \
  -o /tmp/libandroid.so link-libandroid-stub.c

clang --target=armv7a-linux-gnueabi -march=armv7-a -mthumb -Oz \
  -ffreestanding -fPIE -fno-stack-protector -fno-builtin -nostdlib \
  -c -o /tmp/sensors.o sensors.c

clang --target=armv7a-linux-gnueabi -fuse-ld=lld -nostdlib \
  -Wl,-pie -Wl,--dynamic-linker=/system/bin/linker -Wl,-e,_start \
  -Wl,--hash-style=both -L/tmp /tmp/sensors.o -landroid -o sensors
```

Host inspection established that the result is a 32-bit ARM EABI5 PIE, its
entry point is Thumb, and its only dynamic library dependency is `libandroid.so`.
That is cross-build evidence only, not Android runtime acceptance.

## Expected output

The current minimal formatter uses hexadecimal integers to avoid dragging a C
runtime into the probe. Output has this shape:

```text
count   0x00000005
index   type    min_delay_us    name    vendor
0x00000000      0x00000001      0x00002710      ...     ...
```

The exact count, names, vendor strings, types, and delays are device data and
must not be baked into acceptance tests.

## Acceptance boundary

The direct path is accepted only after the exact cross-built artifact:

1. launches on the physical Android phone;
2. resolves the sensor entry points from the phone's real `libandroid.so`; and
3. returns that phone's sensor list.

A host cross-build, source inspection, emulator result, or Termux:API command
does not substitute for that physical-device result. Conversely, the phone does
not need to compile the source merely to supply runtime acceptance.

## Next steps after enumeration works

Add, in order:

1. one fresh accelerometer sample using the native Android event queue;
2. a continuous accelerometer event stream;
3. the semantic hardware objects that can later be presented as
   `/hardware/sensors`, `/hardware/sensors/accelerometer/info`,
   `/hardware/sensors/accelerometer/sample`, and
   `/hardware/sensors/accelerometer/events`;
4. alternative adapters such as Termux:API, Linux IIO, 9P, or FUSE without
   changing those object meanings.

The Android mechanism is an adapter. It must not define the permanent Grease
hardware semantics merely because it is the first implementation.
