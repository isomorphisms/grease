# Agent instructions

These instructions apply to the current `ish` line. Read the branch README before changing architecture or layout.

## Preserve the readable source surface

`Ish.idric` stays readable at the repository top level and its maintained implementation is factored under `Ish/`. Compiler/package/runtime/test/generated/build machinery belongs under `_`.

Do not scatter build instructions, generated output, receipts, compiler plumbing, package files, or test machinery through the source-facing tree. Before adding such a file, inspect the existing `_` layout and put it with the corresponding machinery.

Do not replace the readable source surface with generated copies. Where the repository exposes a maintained source entry through a soft link, preserve one canonical source and the link rather than creating divergent duplicates.

## Purpose before mechanism

Keep the top-level program purpose-ordered. Express shell actions in terms of what the program does before exposing buffer management, byte decoding, FFI calls, process tables, or transport details.

Preserve stage boundaries such as receive/acquire, understand/decode, and cast/execute. Do not collapse them into one monolithic evaluator or generic state object merely because the implementation can share plumbing.

Bytes, UTF-8 mechanics, OS records, and primitive return codes belong at explicit lower boundaries. Do not make them the public ontology of a shell operation.

## References are not architecture

Oils/YSH/Grease source is evidence and reference material, not a compatibility contract for `ish`. Do not restore an upstream abstraction, object model, runtime convention, or terminology merely because the pinned source uses it.

Current human corrections and the current `ish` design outrank stale generated code, old branches, upstream naming, and conventional shell implementation practice. Do not reintroduce a rejected semantic abstraction under a renamed wrapper.

## Preserve the intended execution path

Use the exact Idriç revision pinned by `_/idric.lock` for acceptance. Do not silently substitute RefC, an existing shell, an unpinned compiler, or a different launcher to make a check pass.

A successful compile is not executable acceptance. Refusal tests and process/status semantics remain part of the contract; repair the implementation rather than weakening them.