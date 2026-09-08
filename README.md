# Grease and ish

Grease is a language for smoothing the friction between things that come in
contact with one another: a shell. It began with Oils and YSH, thickened with
its own bubbles.

This branch begins **ish**, a small shell written in the current Idriç.

## ish

`ish` inherits experience, examples, and useful ideas from Grease, YSH, and
Oils. It does not inherit a contract to remain compatible with any of them.
Their syntax, runtime, object model, standard library, command behavior, and
implementation are references rather than constraints.

The Oils-derived Grease tree is evidence and reference material, not an
implementation base that `ish` must preserve. `ish` may put useful pressure on
Idriç and on future language work, but it does not depend on Adriç, Odriç, or
Oodriç. [`idric.lock`](idric.lock) records the exact current Idriç revision used
for the executable slice.

`ish` should initially take on the work Grease already performs well for IB:
process execution, pipes, HTTP and utility orchestration, files, temporary
paths, build commands, and other operating-system boundaries. Browser policy
does not belong in the shell merely because the shell performs an operation.
IB remains the application and one of the principal programs that shapes both
`ish` and Idriç.

There is no requirement to port all of Grease before `ish` becomes useful.
Small real programs should pull the required shell forms, primitives, and
runtime facilities into existence.

The first such program is specified in
[`docs/000-one-command.md`](docs/000-one-command.md), with concrete decisions
recorded in
[`docs/001-one-incantation-design.md`](docs/001-one-incantation-design.md): one
parsed incantation becomes one process with exact textual inputs and status.

## Build the first slice

Build current Idriç at the revision in `idric.lock`, then provide its compiler
to `make`:

```sh
make IDRIC=/path/to/Idric/idris2 \
  CHEZ=/path/to/Idric/_/.tools/bin/scheme
make test IDRIC=/path/to/Idric/idris2 \
  CHEZ=/path/to/Idric/_/.tools/bin/scheme
```

The implementation uses the Chez backend, a native launcher, and one small C
`execve` primitive. The launcher bypasses the backend's generated shell script
and restores its temporary loader environment before the requested program is
entered. The implementation does not use RefC or invoke an existing shell.

## Grease source

The Grease implementation is pinned under `source/` as a git submodule. It points at the `grease/main` line of `isomorphisms/oils`, currently commit `e9a54ad727d89cd593d0bfe56136046808ea81d2`.

Clone with submodules to obtain the complete source tree:

```sh
git clone --recurse-submodules https://github.com/isomorphisms/grease.git
```

Keeping the Oils-derived tree as a pinned submodule avoids copying the full upstream repository while giving Grease one stable, reproducible source location for CI and local builds.
