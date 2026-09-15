# `sensors`

`sensors` is a Grease hardware command, not an Android experiment. Its job is to enumerate sensing hardware through the best available platform adapter while keeping the command meaning independent of that adapter.

The first implementation is Android ARMv7. It reaches the public native Android sensor boundary through the phone's real `libandroid.so` and prints tab-separated metadata.

A physical Android Go phone has now executed the exact cross-built artifact carried here and returned its real sensor list. The observed run reported `count 0x00000026` and included the phone's accelerometer plus the vendor's gesture/orientation sensors. That device-specific count and those names are evidence from one phone, not values to bake into tests.

## Phone workflow

Do not install Clang or the Android NDK on the phone. The phone is an execution target only: fetch the already-built ARMv7 executable, verify it, install it in the Termux command directory, and run `sensors`.

The repository carries the executable as `sensors.armv7.b64` because this small artifact is stored through a text-content path. After decoding, its SHA-256 is:

```text
9270b8ebd1243b388a17f24a5cad4883363ca7a5dd122431df2d2a7dc49c87f5
```

It is a 3556-byte ARMv7 Thumb-2 PIE with `/system/bin/linker` as interpreter and `libandroid.so` as its only dynamic library dependency.

A typical install is:

```sh
base64 -d sensors.armv7.b64 > "$PREFIX/bin/sensors"
echo '9270b8ebd1243b388a17f24a5cad4883363ca7a5dd122431df2d2a7dc49c87f5  '"$PREFIX/bin/sensors" | sha256sum -c -
chmod 755 "$PREFIX/bin/sensors"
sensors
```

## Off-device build

`sensors.c` is freestanding so the cross-build does not need Android headers or libc. It writes output with ARM Linux system calls and calls only the public Android sensor symbols it needs.

`link-libandroid-stub.c` is link-time scaffolding only. It supplies symbol names and the `libandroid.so` SONAME to the off-device linker. The stub is not shipped to the phone; Android's dynamic linker loads the phone's real `libandroid.so`.

The current artifact was produced with Clang/LLD 17:

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

The libc-free formatter is an implementation convenience, not part of the command semantics. The meaningful architectural choice is that the Android implementation uses the native sensor service boundary rather than a vendor HAL or raw kernel device.

## Command family

The next hardware commands should keep the same separation between program meaning and platform adapter:

```text
sensors
    enumerate available sensors

read accelerometer
    wait for one fresh acceleration measurement and print it

watch accelerometer
    stream acceleration measurements
```

Later adapters may use Linux IIO, a Termux:API bridge, 9P, FUSE, or another native system interface without changing those meanings.

The ARM/Thumb compiler repository carries the same programs as backend sample targets. A hand-written C oracle or a physically working Android binary is not, by itself, evidence that Idriç generated that ARM/Thumb program.
