# Native libc actions in Grease

Grease is still the Oils/YSH-derived executable described in
[`CURRENT-GREASE.md`](CURRENT-GREASE.md). This native vocabulary extends that
implementation; it does not add a second runtime.

The C++ layer here is inherited from Oils. Oils translates the shell runtime to
C++ for the native `oils-for-unix` / YSH executable, and already keeps native
replacements for Python-extension operations in `cpp/`. Grease therefore uses
that existing seam:

```text
Grease / YSH program
        |
        v
native object in builtin/func_native.py
        |
        v
pyext/libc.pyi boundary
        |
        v
existing Oils cpp/libc.h + cpp/libc.cc native layer
        |
        v
libc (Bionic on Android) -> kernel
```

There is no raw syscall-number table and no general C FFI. Grease does not get
`dlsym`, arbitrary pointer calls, variadic calls, callbacks, or general struct
marshalling from this work.

## Public actions

The built-in `native` object exposes these operating-system actions:

- `mmap`
- `munmap`
- `mprotect`
- `msync`
- `openat`
- `linkat`
- `symlinkat`
- `unlinkat`

Three small support actions make those resources usable without exposing raw C
values:

- `close` closes a descriptor returned by `openat`;
- `readMapping` reads a bounded byte range from a live mapping;
- `writeMapping` writes a bounded byte range to a live mapping.

`native.cwd` is a borrowed directory descriptor representing `AT_FDCWD`. It can
be used as the directory argument to the `*at` actions, but it cannot be closed.

## Resource values

The public language boundary does not expose a C pointer or kernel file
descriptor as an integer.

`mmap` returns a `Mapping` object. A mapping contains an opaque `Address`, its
mapped length, and live/inactive state. The native C++ registry owns the actual
`void *` and length. `munmap`, `mprotect`, `msync`, `readMapping`, and
`writeMapping` resolve the opaque handle through that registry.

`openat` returns a `FileDescriptor` object. Its opaque token resolves to a real
file descriptor in a separate native registry. The object records whether it is
a directory descriptor, whether it is borrowed, and whether it has been closed.

These are runtime distinctions in current Grease/YSH, not a claim that YSH has
a new static nominal type system. Lengths, offsets, and modes use the existing
YSH `Int` value at the language surface. Lengths and offsets cross the native
boundary as decimal text and are range-checked before conversion to `size_t` or
`off_t`, avoiding an accidental narrowing through a C `int`.

## Errors

Native calls return a Grease result object rather than requiring code to inspect
C sentinels such as `-1` or `MAP_FAILED`.

A result has:

- `ok`: boolean success status;
- `value`: the result value on success;
- `error`: a `NativeError` on failure.

A `NativeError` contains the errno number, its symbolic name when known, and the
platform error message. A failed `mmap` never becomes a usable `Address`.

## Flags

Grease uses stable text names instead of exporting libc's numeric constants.
The C++ boundary translates those names' internal bit masks to the constants of
the platform being built.

Memory protection names are `none`, `read`, `write`, and `execute`.
Mapping names are `private`, `shared`, and `anonymous`; exactly one of `private`
or `shared` is required. Synchronization names are `sync`, `async`, and
`invalidate`; exactly one of `sync` or `async` is required.

`openat` accepts `read-only`, `write-only`, `read-write`, `create`, `exclusive`,
`truncate`, `append`, `directory`, `no-follow`, and `close-on-exec`, with exactly
one access mode. `linkat` has a `followSymlink` boolean and `unlinkat` has a
`removeDirectory` boolean.

## Implementation boundary

The native implementation calls libc directly:

```text
mmap      munmap      mprotect      msync
openat    close       linkat        symlinkat       unlinkat
```

On Android these resolve through Bionic. The current phone build targets Android
API 28, which is above the API boundary needed by the selected `*at` and mapping
interfaces. No ARM syscall numbers are part of the Grease API or implementation.

The Python reference execution path is not claimed as an implementation of
these actions. `pyext/libc.pyi` describes the translated boundary, while the
actual new operations are supplied by `cpp/libc.cc` in the native Grease/Oils
build. A Python-only YSH run can construct the `native` object but is not an
acceptance target for invoking these new actions.

## Relationship to ish

`ish` is the separate Odriç successor line described in `CURRENT-GREASE.md`.
Its direct `execve` milestone is useful design evidence, but it is not the
runtime underneath current Grease. This work therefore does not manufacture a
second `ish` bridge merely to duplicate the Oils native boundary.

Existing Oils process execution remains inherited behavior and is checked by
the normal native shell test suite.

## Representative IB use

[`../examples/ib-mapped-index.ysh`](../examples/ib-mapped-index.ysh) is the
small end-to-end proof. It opens a prepared 4096-byte index file, maps it shared,
reads `fragment`, writes `pensieve`, synchronizes the mapping, reads the changed
value back, unmaps it, and closes the descriptor. The receipt then checks the
file bytes outside the Grease process to prove that the shared mapping really
persisted the change.

The focused C++ tests additionally cover anonymous mappings, protection changes,
out-of-bounds access, deliberate error cases, file-backed mappings, hard links,
symbolic links, relative `openat`, and `unlinkat`.

## Extending the vocabulary

A later native action should stay explicit and small. Add its declaration to the
translated libc boundary, implement the libc/Bionic call in `cpp/libc.cc`, add a
Grease method that converts readable values to that boundary, and exercise both
success and error behavior. If this repeated shape grows large enough to justify
a declaration-driven generator, that can be introduced from demonstrated
repetition rather than turning this first vocabulary into a general-purpose
FFI.
