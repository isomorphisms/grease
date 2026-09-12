# ish design receipt 2: filesystem names and handles

> **Design sketch.** This note records the first filesystem model underneath the
> shell-argument layer. It is deliberately smaller than POSIX and does not claim
> to model storage allocation, every `openat` flag, mounts, namespaces, or every
> kind of filesystem object. It also does not claim that ish currently executes
> these filesystem requests.

## Three different meanings of location

`Address` is too vague for this work. Three unrelated notions must stay
separate:

1. a **memory address** identifies a place in a process virtual address space;
2. a **filesystem location** tells pathname resolution where to begin and what
   pathname text to resolve;
3. a **storage location** identifies blocks, clusters, extents, sectors, or
   other allocation units on a storage device.

The current filesystem sketch models only the second meaning. A
`Filesystem_location` is a resolution instruction, not proof that resolution
succeeds and not the identity of an already-resolved object. `mmap` belongs to
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
semantic layer therefore wraps a raw descriptor as an `Open_handle`. A
`Directory` contains that same generic handle only after the operating system
has verified the opened object is a directory. The narrower value is therefore
a refinement of the opened handle, not a second descriptor identity.

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

A future ish Unix adapter can lower `Working_directory` to `AT_FDCWD` and an
opened `Directory` to its underlying file descriptor. An absolute location does
not carry a meaningless directory argument merely because the C function
signature has one.

This is also why `Directory` is more useful than exposing a naked integer file
descriptor: directory-relative resolution can state what kind of handle it
requires. A generic `Open_handle` is not silently accepted as a pathname base.

The constructors state the intended absolute or relative interpretation. This
first semantic slice does not yet attempt a type-level proof of pathname text
shape; an eventual adapter must validate rather than silently reinterpret a
mis-formed value.

## Opening

The common open arguments separate four questions:

- **where**: `Filesystem_location`;
- **access**: read, write, or read-and-write;
- **presence**: existing only, create if missing, or create new;
- **choices**: named choices such as append, truncate, close-on-exec, rejection
  of a final symbolic link, nonblocking, or synchronous writes.

Creation reuses Idriç's existing `Permissions` record: user, group, and others
each carry named read/write/execute modes. A future ish Unix adapter may lower
that value to `mode_t`, and the process umask may still restrict the effective
mode. Neither fact requires the shell layer to expose an unexplained integer.

`Open_choice` is deliberately a collection of semantic names rather than a
public integer bit mask. Repeating a choice has no additional semantic meaning;
if a future adapter encounters an incompatible combination, validation belongs
at that boundary rather than in shell source.

Whether the operating system must verify a directory is not a phantom parameter
on `Open_request`. It is the actual filesystem operation:

```text
Open_object request      → Open_handle
Open_directory request   → Directory
```

The second operation must reject a non-directory before constructing
`Directory`. This keeps the useful result distinction without making the common
open arguments pretend to carry runtime evidence they do not contain.

`Reject_final_symbolic_link` means a final symbolic link makes the open fail. It
does not mean that the symbolic-link object itself is opened. That distinction
matches the intended no-follow semantics without exporting `O_NOFOLLOW`.

## Hard links, symbolic links, and removal

A hard-link request contains an existing namespace location and a destination
namespace location. It also names the unusual `linkat` choice between linking
the object named by the source path and following a final symbolic link first.
No numeric `AT_SYMLINK_FOLLOW` flag appears in the shell meaning.

A symbolic-link request contains target `Text` and the namespace location where
the new symbolic link will be created. The target remains text because dangling
symbolic links are valid.

Removal distinguishes ordinary nondirectory-name removal from directory
removal. A future ish Unix adapter can lower the latter to `AT_REMOVEDIR`; the
semantic layer does not expose that integer flag.

## Errors

The shared `Operating_system_error` type is used by this lower system model and
by the existing process-replacement boundary. Sentinel return values stay below
the shell-facing meaning. The error retains the raw signed error-number
representation and explanatory text, while semantic classification and a
platform symbolic name are each optional.

That optional classification matters now: the existing ish process-replacement
boundary retains the returned error number and `strerror` text but does not yet
claim a complete errno-to-semantic-kind classifier. It therefore records
`Nothing` rather than manufacturing an `Unclassified_operating_system_error`
kind. A later filesystem adapter may classify common failures when that is
useful without losing the original platform evidence.

This name deliberately avoids `NativeError`: “native” says nothing about what
failed or which boundary reported it.

## Allocation is a separate layer

The namespace model does not assume FAT. A FAT-family filesystem may represent
file allocation as a chain of clusters. Another filesystem may use extents,
trees, copy-on-write structures, or something else:

```text
namespace name
    → filesystem object
    → logical byte range
    → allocation description
    → storage blocks / clusters / extents
    → storage device
```

That lower allocation model may become useful later, especially for inspection,
recovery, or filesystem tools. It should be added as its own layer rather than
making every ordinary shell pathname pretend to be a disk address.

## Intended surface direction

The following is design notation, not accepted ish parser syntax yet:

```text
directory ← open directory "/tmp"
file ← open "notes" at directory for reading and writing

link "notes" at directory
    to "notes-copy" at directory

link symbolically to "../target"
    at "shortcut" at directory

remove file "notes-copy" at directory
```

The prepositions are not decoration. `at` identifies pathname-resolution
context, `to` distinguishes link destination from source, and `with`/`for` can
identify named operating choices without exposing bit masks.

## Relationship to the Grease/Oils libc work

The separate `native/linux-libc-vocabulary` Grease/Oils branch is implementation
evidence for some of these distinctions: its current Grease/YSH runtime has
exercised `openat`, `linkat`, `symlinkat`, and `unlinkat` through the inherited
Oils native boundary, including Bionic work. None of that code is the ish
runtime, none of those runs accept this ish model, and this PR does not import
that implementation.

A later ish implementation can use the same semantic distinctions at its own
system boundary. Until such an implementation and its own acceptance exist,
this PR claims only the typed ish meanings plus the existing ish acceptance
slice that happens to compile them.
