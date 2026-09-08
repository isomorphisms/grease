# Grease and ish

Grease is a shell-language project that began from Oils and YSH. The
Oils-derived tree remains pinned under `source/` as reference material. The
maintained `ish` implementation is fresh Idriç at the repository root and under
`Ish/`; it is not a compatibility layer over that reference tree.

## ish

`ish` currently implements one deliberately small executable slice: receive one
source file, understand one source-identified incantation, and cast it by
replacing the shell process with the exact executable path named in that
incantation.

The top-level program is intentionally the shortest useful description of that
behavior:

```idris
main : IO ()
main = do
  source ← receive_incantation_source
  incantation ← understand_incantation source
  cast_incantation incantation
```

The current source spelling is whitespace-separated words. The first word is
the exact executable path and the remaining words are literal inputs. There is
no `PATH` search, quoting, escaping, interpolation, expansion, globbing,
redirection, pipeline, builtin, job control, or interactive editor in this
slice.

Source identity and decoded text survive parsing. Source spans are decoded
character offsets; UTF-8 validation uses separate byte offsets. Malformed UTF-8
and NUL fail before execution. On successful `execve`, `ish` is replaced, so the
requested program naturally inherits the environment, current directory,
standard descriptors, and eventual process status.

## Repository shape

- `Ish.idric` — purpose-ordered maintained program.
- `Ish/` — shell meanings and their implementations, organized by purpose.
- `_` — package/build descriptions, the narrow C/Unix boundary, tests, probes,
  compiler pin, generated output, and the source link used by the package.
- `docs/000-one-command.md` — current milestone specification.
- `docs/001-one-incantation-design.md` — design and acceptance receipt for this
  slice.
- `docs/research/` — historical research/background, explicitly non-authoritative
  for current behavior.
- `source/` — pinned Oils-derived Grease reference submodule, not maintained
  `ish` source.

[`STYLE.md`](STYLE.md) records the repository-specific Idriç source rules.
[`_/idric.lock`](_/idric.lock) records the exact Idriç revision against which
this slice is accepted.

## Build and acceptance

Build Idriç at the exact revision in `_/idric.lock`, then run the clean
acceptance target with the stage-2 compiler produced by that checkout:

```sh
IDRIS2_PREFIX=/path/to/Idric/_/bootstrap-build \
make -C _ acceptance IDRIC=/path/to/Idric/_/build/exec/idris2 \
  CHEZ=/path/to/Idric/_/.tools/bin/scheme
```

The acceptance gate rebuilds from a clean generated state and proves the
runtime source-to-process path, exact UTF-8/literal inputs, inherited bytes and
environment, standard descriptors, process status, deterministic malformed
source failures, exact-path execution without `PATH` lookup, source-aware
missing-executable diagnostics, and absence of an accidental existing-shell
invocation when `strace` is available.

The implementation uses the Chez backend, a native launcher, and one small C
`execve` boundary. The launcher bypasses the backend's generated shell wrapper
and restores its temporary loader environment before entering the requested
program. The maintained shell semantics do not expose that framing or raw Unix
representation.

## Grease reference source

The Oils-derived Grease implementation is pinned under `source/` as a git
submodule. Clone with submodules when that historical/reference tree is needed:

```sh
git clone --recurse-submodules https://github.com/isomorphisms/grease.git
```

The exact submodule revision is repository state; the README does not duplicate
it as a second mutable source of truth.
