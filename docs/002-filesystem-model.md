# ish design receipt 2: filesystem names and handles

> **Design sketch.** This note records the first filesystem model underneath the
> shell-argument layer. It is deliberately smaller than POSIX and does not claim
> to model storage allocation, every `openat` flag, mounts, namespaces, or every
> kind of filesystem object.

## Three different meanings of location

`Address` is too vague for this work. Three unrelated notions must stay
separate:

1. a **memory address** identifies a place in a process virtual address space;
2. a **filesystem location** tells pathname resolution where to begin and what
   pathname text to resolve;
3. a **storage location** identifies blocks, clusters, extents, sectors, or
   other allocation units on a storage device.

The current filesystem sketch models only the second meaning. `mmap` belongs to
memory mapping and must not reuse filesystem-location vocabulary. Physical disk
allocation belongs below the filesystem namespace model and is not inferred
from a pathname.

## Namespace is a graph, not simply a tree of file bytes

A directory contains names. A name resolves to a filesystem object. More than
one directory entry may name the same object:

```text
Directory A -- name x --\
                         >-- File object
Directory B -- name y --/
```

That is the ordinary hard-link case. The namespace therefore cannot be modeled
as though each file object had exactly one parent path.

A symbolic link is different. Its object stores target text:

```text
Directory -- name --> Symbolic-link object -- stores --> "../target"
```

The stored text need not currently resolve to any object. This is why
`Symbolic_link_request` carries `Text`, not a pre-resolved filesystem object or
location.

An opened descriptor is different again. It is a process handle to an opened
kernel object, not the object's pathname and not its disk allocation. The ish
semantic layer therefore wraps a raw descriptor as an opened handle and gives a
directory-verified handle the narrower `Directory` type.

## Absolute and directory-relative resolution

The `*at` family makes the pathname base explicit. ish represents a filesystem
location as either:

```text
Absolute_location path_text
```

or:

```text
Relative_location Working_directory path_text
Relative_location (At_directory directory) path_text
```

The Unix adapter can lower `Working_directory` to `AT_FDCWD` and an opened
`Directory` to its file descriptor. An absolute location does not carry a
meaningless directory argument merely because the C function signature has one.

This is also why `Directory` is more useful than exposing a naked integer file
descriptor: directory-relative resolution can state what kind of handle it
requires.

## Opening

The first request separates four questions:

- **where**: `Filesystem_location`;
- **access**: read, write, or read-and-write;
- **presence**: existing only, create if missing, or create new;
- **behavior**: named choices such as append, truncate, close-on-exec, no-follow,
  nonblocking, or synchronous writes.

Creation permissions are named owner/group/others permissions rather than an
integer `mode_t` bit mask. The Unix adapter may still use `mode_t`; the process
umask may still restrict the effective mode. Neither fact requires the shell
layer to expose an unexplained integer.

The request is indexed by whether any opened object is acceptable or the
operating system must verify that the result is a directory. The result follows
that index:

```text
open any object      -> Open_handle
open directory       -> Directory
```

This is a small useful dependent relationship. It does not try to prove resource
lifetimes or require linear use of every descriptor.

## Hard links, symbolic links, and removal

A hard-link request contains an existing namespace location and a destination
namespace location. It also names the unusual `linkat` choice between linking
the object named by the source path and following a final symbolic link first.
No numeric `AT_SYMLINK_FOLLOW` flag appears in the shell meaning.

A symbolic-link request contains target `Text` and the namespace location where
the new symbolic link will be created. The target remains text because dangling
symbolic links are valid.

Removal distinguishes ordinary nondirectory-name removal from directory
removal. The Unix adapter can lower the latter to `AT_REMOVEDIR`; the semantic
layer does not expose that integer flag.

## Errors

The new `System_error` type is the first shared error meaning for this lower
system layer. An adapter consumes sentinel return values and `errno`, classifies
common failures when useful, and retains the operating system's explanatory
text. A failed C call returning `-1` therefore does not become the shell value
`-1`.

This name deliberately avoids `NativeError`: “native” says nothing about what
failed or which boundary reported it.

## Allocation is a separate layer

The namespace model does not assume FAT. A FAT-family filesystem may represent
file allocation as a chain of clusters. Another filesystem may use extents,
trees, copy-on-write structures, or something else:

```text
namespace name
    -> filesystem object
    -> logical byte range
    -> allocation description
    -> storage blocks / clusters / extents
    -> storage device
```

That lower allocation model may become useful later, especially for inspection,
recovery, or filesystem tools. It should be added as its own layer rather than
making every ordinary shell pathname pretend to be a disk address.

## Intended surface direction

The following is design notation, not accepted ish parser syntax yet:

```text
directory <- open directory "/tmp"
file <- open "notes" at directory for reading and writing

link "notes" at directory
    to "notes-copy" at directory

link symbolically to "../target"
    at "shortcut" at directory

remove file "notes-copy" at directory
```

The prepositions are not decoration. `at` identifies pathname-resolution
context, `to` distinguishes link destination from source, and `with`/`for` can
identify named operating choices without exposing bit masks.

The current Grease/Oils libc/Bionic branch is implementation evidence for these
meanings: it already exercises `openat`, `linkat`, `symlinkat`, and `unlinkat`
without exposing raw kernel values. It is not the runtime underneath ish. A
later ish implementation can adopt the same semantic distinctions at its own
system boundary without manufacturing a second bridge to the Oils runtime.
