# Grease and ish source style

Grease is a shell-language project. The Oils-derived repository under
`source/` is a pinned reference, while the maintained `ish` implementation is
fresh Idriç at the repository root and under `Ish/`. These strata have different
style obligations and must not be blurred.

## Describe the shell before its machinery

A shell receives source describing an incantation, understands the incantation
and its inputs, and casts it so an action occurs. Top-level `Ish.idric` states
that purpose in that order. Source decoding, parsing, path interpretation,
process replacement, foreign calls, and failure reporting live below it in
descriptively named files.

`cast_incantation` is the shell operation; `execve` is only the current concrete
mechanism. The one-incantation slice uses an exact path and replaces the current
process. It must not imply that PATH search, process creation, waiting, pipes,
builtins, or signal supervision already exists.

Compiler policy is not shell intent. `.idric` is total by default and source
does not begin with `%default total`. Do not use `covering` when a small
structurally decreasing implementation can establish totality. Use `public
export` only when transitive API re-export is deliberate.

## Vocabulary and semantic types

- Use `snake_case` for names under our control and descriptive names rather
  than inherited Haskell abbreviations.
- Use canonical Idriç vocabulary directly rather than recreating local aliases.
  `Text` is decoded text. `Number` means a positive whole number beginning at
  one. `Cardinality` is the zero-capable whole-number type for counts, lengths,
  and offsets. `±Number` is for genuinely signed integer meanings.
- Do not relabel an ABI integer as a semantic number merely to hide `Int`.
  Consume raw signed representations at the Unix/foreign boundary and carry a
  shell meaning upward.
- An `Incantation` retains its source identity, decoded source text, complete
  span, name, and list of inputs. Do not pass loose source counts/text beside
  it or reconstruct and reparse source.
- Keep source bytes, decoded source text, filesystem paths, incantation names,
  executable paths, one input, input lists, process replacements, failures, and
  exit representations distinct where their operations differ.
- A raw source byte remains `Source_byte` at the decoder boundary. Do not call a
  byte value `Number` or `Cardinality`; only byte counts and offsets are
  Cardinalities.
- Use `Bool` for predicates, not as a premature projection of source analysis,
  launch failure, process completion, or protocol state.
- Prefer named records over heterogeneous tuples. Do not create an unrestricted
  wrapper merely to disguise a primitive.

The eventual public replacements for `argv` and `stdin`, `data` versus
`stream`, `option` versus `choice`, and the exact `cast`/`summon` vocabulary are
still unresolved. `argv` and `execve` remain exact names only at the Unix ABI
boundary. This milestone uses `input` internally without claiming that it is
the permanent public term.

## Syntax, constants, and boundaries

Use canonical `→`, `←`, and `⇒` in `.idric`. Use `$` when it removes pointless
nesting, not to erase readable grouping. Avoid gratuitous currying,
constructor-led top-level code, and monadic or foreign plumbing in the program
description.

Name numeric statuses, byte ranges, UTF-8 widths, and other protocol constants.
Explain why an exact number or conversion matters. Comments document why a
foreign boundary exists and what it guarantees.

The high-level shell must not expose `%foreign`, raw pointers, C framing, or
backend launcher state. The `execve` wrapper remains narrow and restores the
caller's loader environment before entering the requested program. External
POSIX/C spellings stay exact at that boundary and are translated immediately
beyond it.

## Files and provenance

Keep the readable Idriç entry point at repository top level and supporting
implementations under `Ish/`. Build descriptions, generated build output, the C
runtime boundary, probes, and acceptance machinery live under `_`. `.idric`
means maintained Idriç source; `.idr` is reserved for Idris/bootstrap or
upstream compatibility material.

Do not restyle the `source/` submodule as maintained ish. Preserve its pinned
revision and provenance. Keep `.gitattributes` accurate for Idriç, generated,
foreign-support, vendored, and submodule content.

## Acceptance

Compilation alone is insufficient. The one-incantation gate must build from
the exact Idriç revision in `_/idric.lock`, execute a runtime-provided source
file, preserve exact argument and byte boundaries, preserve the inherited
environment and standard descriptors, and prove that no existing shell was
invoked. It must also exercise invalid UTF-8, NUL source, incomplete source, no
PATH search, and failed process replacement while retaining source identity in
diagnostics.

Receipts name the exact code tested and use `PASS`, `FAIL`, `SKIP`, or
`BLOCKED` accurately. Future signal, wait, job-control, and hardware claims need
acceptance at their actual operating-system or device boundary.
