# Grease and ish

Grease is a language for smoothing the friction between things that come in
contact with one another: a shell. It began with Oils and YSH, thickened with
its own bubbles.

This branch begins **ish**, the shell to be written in Odriç.

## ish

`ish` inherits experience, examples, and useful ideas from Grease, YSH, and
Oils. It does not inherit a contract to remain compatible with any of them.
Their syntax, runtime, object model, standard library, command behavior, and
implementation are references rather than constraints.

The direction is:

```text
Oils / YSH -> Grease -> ish
                         ↕
                       Odriç
```

The horizontal arrows mean descent, not compatibility. The vertical arrow
means that `ish` and Odriç may change one another.

Odriç is the deliberately unsettled branch of Idriç being born alongside the
shell. Its ANF, prelude, primitives, representations, runtime seams, and native
lowering are all open to pressure from `ish`. Idris supplied a useful starting
shape—a language with dependent types—but is not the specification. If `ish`,
IB, Android, mathematical programs, or direct machine targets expose a better
primitive or representation, Odriç may grow around that pressure.

[`odric.lock`](odric.lock) records the exact Odriç revision that defines the
current build boundary. Moving that revision is an explicit part of changing
`ish`, not an assumption that Odriç stands still.

Two language-shape requirements are already comparatively firm:

- mathematical and typographical notation should be designed for direct use,
  not treated as aliases pasted over an otherwise fixed language;
- vector-indexed function names, function families, and left-hand sides are
  first-class design material.

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
[`docs/000-one-command.md`](docs/000-one-command.md): one parsed simple command
becomes one process with exact arguments and status.

## Grease source

The Grease implementation is pinned under `source/` as a git submodule. It points at the `grease/main` line of `isomorphisms/oils`, currently commit `e9a54ad727d89cd593d0bfe56136046808ea81d2`.

Clone with submodules to obtain the complete source tree:

```sh
git clone --recurse-submodules https://github.com/isomorphisms/grease.git
```

Keeping the Oils-derived tree as a pinned submodule avoids copying the full upstream repository while giving Grease one stable, reproducible source location for CI and local builds.
