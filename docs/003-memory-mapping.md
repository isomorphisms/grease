# ish design receipt 3: memory mappings

This slice gives ish its own typed memory-mapping boundary. It is separate from
the filesystem namespace model: a pathname tells name resolution where to look,
an opened handle names a kernel object, and a mapping represents bytes in the
process virtual address space.

The public meanings are intentionally smaller than POSIX. A mapping request
states:

- anonymous memory or an already-opened file plus a nonnegative byte offset;
- a nonnegative mapping length;
- named read, write, and execute permissions;
- private or shared mapping semantics.

No numeric `PROT_*` or `MAP_*` constants cross the Idriç boundary. Lengths and
offsets remain `Number` values and cross the foreign boundary as decimal text,
so a large value is range-checked by the platform adapter rather than silently
narrowed through a C `int`.

## A mapping is not an address

`Mapping` carries an opaque registry token and its logical extent. The C
adapter owns the actual `void *` returned by `mmap`. The token therefore cannot
be used as a pointer, and a released mapping becomes invalid even if its old
Idriç value is retained.

The first execution slice provides:

- `map_memory` → libc/Bionic `mmap`;
- bounded byte reads and writes through the live mapping;
- `synchronize_mapping` → `msync(..., MS_SYNC)`;
- `release_mapping` → `munmap`.

The byte accessors exist to make the mapped resource usable and testable without
inventing a general pointer API. They operate on `Byte`, an uninterpreted
octet, rather than pretending mapped storage is decoded text.

## Acceptance boundary

Host acceptance prepares a 4096-byte file beginning with `fragment`. The Idriç
acceptance executable opens it, maps it shared, verifies those bytes through the
mapping, writes `pensieve`, synchronizes and releases the mapping, and closes
the file. The surrounding shell then reads the file independently and requires
the persisted bytes to be `pensieve`.

The same executable also exercises an anonymous private mapping, rejects a write
through a read-only mapping, rejects a zero-length map, and verifies that a
released token is refused.

The Android package workflow compiles the same `memory.c` adapter for ARMv7 and
AArch64. A green package build is cross-build evidence only; physical-device
execution remains a separate acceptance boundary.

## Deliberate limits

This slice does not add `mprotect`, asynchronous `msync`, fixed-address
mapping, huge-page flags, raw pointers, a general C FFI, or filesystem
block-allocation/fallocate semantics. Those are separate operations and should
be added only with their own meanings and acceptance.
