# Live Android sensors

This is the first live Android probe for the proposed Grease hardware namespace.
It deliberately tests the public native Android sensor boundary before adding a
synthetic filesystem, 9P, FUSE, IIO, direct HAL access, or a Termux:API bridge.

The first program is only `sensors`: enumerate the sensors visible through
`libandroid` and print stable tab-separated metadata.  This source is an Android
experiment, not a Grease execution receipt.

## Build and run on Android

From this directory in Termux:

```sh
cc -std=c11 -O2 -Wall -Wextra sensors.c -landroid -o sensors
./sensors
```

The expected shape is:

```text
type    name    vendor    resolution    min_delay_us
1       ...     ...       ...           ...
```

The exact sensor names and metadata are device data and must not be baked into
tests.

## Acceptance boundary

The direct path is accepted only after the exact source revision:

1. compiles in the actual Android/Termux environment;
2. launches on the physical device; and
3. returns the device's sensor list through `libandroid`.

A successful Termux:API command, emulator run, host cross-build, or source
inspection does not substitute for that physical-device result.

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

The Android mechanism is an adapter.  It must not define the permanent Grease
hardware semantics merely because it is the first implementation.
