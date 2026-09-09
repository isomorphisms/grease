# Agent instructions

## Cross-repository anti-patterns

These rules apply in addition to stricter repository-specific rules below.

- Claim only the boundary actually exercised. Source presence, fixtures, generation, compilation, packaging, installation, launch, smoke checks, semantic execution, backend execution, and physical-device execution are different evidence levels. If a stronger boundary was not exercised, report it as unverified.
- The named mechanism is part of acceptance. Do not substitute a fallback, oracle, mock, alternate backend, alternate executable, lookalike renderer, or conventional nearby toolchain and keep the original label.
- Do not weaken acceptance to obtain green. Repair the implementation. Change the contract only when the requirement itself is shown to be wrong or obsolete, and keep that semantic decision explicit. Targeted negative tests must fail for the intended reason when the distinction matters.
- Keep semantics independent of convenient representations. Mathematical, domain, and language objects are not defined by tuples, matrices, compiler nodes, ABI records, transport bytes, storage shapes, or UI payloads unless the semantics explicitly say so.
- Current explicit human corrections and current architecture outrank stale source, generated code, upstream conventions, older branches, bootstrap precedent, and familiar practice. Do not restore a rejected abstraction under its old name or a near-synonym.
- Acceptance belongs to an exact head and its material pins. An ancestor's, sibling branch's, or previous pin's green result is historical evidence only.
- Mocks, fixtures, harnesses, and today's platform adapter must cross replaceable interfaces; they do not get to define the permanent architecture merely because they are currently convenient.
- Preserve the repository's chosen implementation path and layout before introducing familiar infrastructure. Where `_` is an established machinery boundary, keep build/package/generated/test/compiler material there and preserve canonical source and intended soft links.

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