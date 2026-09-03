# Current Grease

This document records the evidence-backed Grease state after reconciling the August 2026 conversation history with `isomorphisms/grease`, the Grease branches of `isomorphisms/oils`, and the later `ish` / Odriç split.

It is intentionally narrower than a language design document. A branch name is not treated as a decision, and an old experiment is not promoted merely because it exists.

## Current model

Grease is the working Oils/YSH-derived shell-language line. Oils/YSH behavior remains the inherited reference unless Grease deliberately changes it.

The implemented Grease-specific language change on the current Oils line is readable boolean syntax:

- `⟦ ... ⟧` enters the inherited `[[ ... ]]` condition path;
- `∧` uses the inherited `&&` token path;
- `∨` uses the inherited `||` token path;
- `¬` uses the inherited `!` token path.

These spellings are lexer-level aliases in the present implementation, not a new independent semantic layer. They are separated operators: quoted glyphs stay literal, and a glyph glued into an ordinary word is not promised to behave like punctuation with shell-specific whitespace rules.

Grease also carries three conservative runtime/startup cleanups that remove work when the corresponding feature is disabled. They do not define new language semantics.

`ish` is now the intended new shell written in Odriç. It descends from the experience of Oils/YSH and Grease but does not inherit a compatibility contract. Grease therefore remains useful as the executable/reference predecessor and as an oracle for shell behavior while `ish` grows feature by feature. The plan to make Grease itself become the new Odriç-written shell is superseded by the separate `ish` line.

## Decision ledger

| Class | Decision | Provenance |
| --- | --- | --- |
| CURRENT | Grease remains Oils/YSH-derived rather than a from-scratch shell. | Repository source is a submodule of `isomorphisms/oils`; current implementation line is `oils:grease/main`. |
| CURRENT | `⟦ ... ⟧`, `∧`, `∨`, `¬` are Grease-readable spellings for inherited boolean token paths. | `isomorphisms/oils` PR #1, merged as `8052868773077602266d80bf39aad6998e2da749`, with focused spec coverage. |
| CURRENT | Remove dead completion timing, disabled debug construction, and disabled multi-trace argv accounting. | Integrated line `7d5a723` -> `4ab053f` -> `e9a54ad`; all are ancestors of `grease/main`. |
| CURRENT | `ish` is the separate descendant to be written in Odriç; Grease is a predecessor/reference, not the Odriç implementation itself. | `isomorphisms/grease:ish` commits `78ffc75` and `00160a3`; Odriç begins at `isomorphisms/Idric:Odriç` commit `0476044`. |
| SUPERSEDED | Evolving Grease itself into the Idriç/Odriç-written future shell. | The later `ish` branch explicitly assigns that role to `ish` and says compatibility with Grease/Oils/YSH is reference material rather than a contract. |
| EXPERIMENTAL | Ithon/Python migration work using `←`, `→`, `×`, `÷`, and `λ` / `ƒ`. | Recovered Ithon experiment treated the migration as a separate compatibility project and rejected mechanical glyph replacement such as rewriting `*args` / `**kwargs`. It never became the current Oils Grease implementation. |
| EXPERIMENTAL | ICKY as a Grease parser bridge. | Recovered parser experiment kept ICKY syntax-only: preserve glyphs/source order, do not assign Grease meaning or precedence. It was not integrated into `oils:grease/main`. |
| UNDECIDED | Whether the Ithon spellings `←`, `→`, `×`, `÷`, and `λ` / `ƒ` should still be added to Oils-derived Grease. | The experiment established useful spellings, but the later `ish` / Odriç split changed the implementation roadmap without a conversation decision that ports these spellings into current Grease. `λ` versus `ƒ` also remained an alternative. |
| UNDECIDED | Environment-cache, direct command-substitution slurp, control-flow-result, lazy grammar/builtin/readline/history, LTO, regex caching, and getline-buffer ideas. | The corresponding branches were created as independent experiments from the Oils reference commit but contain no implementation, and recovered conversation history does not record a final semantic or performance decision. |

## Python / Ithon boundary

The old Oils machinery on this fork is Python-2-era. The recovered Ithon work explicitly treated moving that machinery to current Ithon/CPython as a compatibility migration, not a glyph-only rewrite. Mechanical replacement of `*` was rejected because multiplication, `*args`, `**kwargs`, unpacking, and other uses are not the same construct.

A lowered Ithon smoke using `←`, `→`, `×`, and `λ` executed and printed `grease:ithon:42`, but native Ithon execution was unavailable because no built `ithon` executable existed. That is useful experiment evidence, not a receipt for current Oils-derived Grease.

After the `ish` split, completing this migration is not a prerequisite for the new shell: Odriç owns the new native implementation path. The experiment may still inform readable syntax, but it is not current Grease semantics by default.

## ICKY boundary

ICKY was explored as a parser front end only. Its job was to retain glyph identity and source order. Meaning and precedence remained downstream language decisions. The experiment therefore does not justify claiming that ICKY owns Grease semantics or that every glyph in its vocabulary belongs to Grease.

The recovered ICKY build remained blocked by unavailable `idris2`, so there is no current executable ICKY receipt to promote.

## Oils branch archaeology

Reference baseline: `15de8fd779569e6e3a9f5fcbfc00e7df0ebe0380`.

| Branch | Head | Disposition |
| --- | --- | --- |
| `master` | `15de8fd` | Frozen Oils reference baseline. |
| `grease/reference/oils-2026-08-14` | `15de8fd` | Explicit reference label. |
| `grease/idea/control-flow-results` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/direct-command-sub-slurp` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/exported-env-cache` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/lazy-builtin-registry` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/lazy-completion-history` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/lazy-readline` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/lazy-ysh-grammar` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/lto-build` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/regex-compile-once` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/reuse-getline-buffer` | `15de8fd` | Label only; UNDECIDED experiment. |
| `grease/idea/completion-no-dead-timing` | `aa1b324` | Implemented patch; same patch replayed into the integrated line as `7d5a723`. Historical topology, not missing work. |
| `grease/idea/disabled-debug-no-work` | `8d3179c` | Implemented experiment; promoted into the integrated quick-wins line as `4ab053f`. |
| `grease/idea/disabled-tracing-no-work` | `e9cb7d4` | Implemented experiment; promoted into the integrated quick-wins line culminating at `e9a54ad`. |
| `grease/quick-wins` | `e9a54ad` | Three accepted performance cleanups. Ancestor of current Grease. |
| `grease/readable-tests` | `ac8d766` | Code-bearing PR head for readable boolean syntax; merged, now historical. |
| `grease/main` | `8052868` | Current Oils-derived Grease implementation: quick wins plus readable boolean syntax. |

The ten label-only idea branches are not latent commits waiting to be merged. No implementation exists on them beyond the baseline. They should remain historical/undecided evidence unless a later decision turns one into a real issue.

## Top-level Grease archaeology

Before this convergence pass, `isomorphisms/grease:main` was still pinned to Oils commit `e9a54ad`, even though `oils:grease/main` had advanced to `8052868`. The convergence branch corrects that reproducibility mismatch.

Other top-level branches are deliberately not folded into current Grease:

- `source-layout` is the merged head of Grease PR #1 and is historical after merge;
- `ish` is two commits ahead of the old main and contains the successor-language design, `odric.lock`, and the one-command native milestone;
- `sms-server-filesystem-foundation` is unrelated application/service work and is outside Grease language convergence.

## `ish` / Odriç boundary

The `ish` branch says explicitly that `ish` inherits experience and examples from Grease/YSH/Oils without a compatibility contract. Its first native milestone is one parsed simple command becoming one process with exact argv and status through direct `execve`; quoting, variables, command substitution, pipelines, conditions, loops, builtins, and job control are deliberately later work.

The branch locks Odriç to `isomorphisms/Idric` branch `Odriç`, revision `0476044583fc8aef897cefeaeb1d0f2e976f3230`, whose commit message is `Begin Odriç as ish co-design line`.

This gives a clean responsibility split:

- Grease: working Oils/YSH-derived shell, readable Grease aliases, inherited shell behavior, and reference/oracle value;
- `ish`: the new shell whose features are pulled into existence by small real programs;
- Odriç: the native language/compiler line co-designed with `ish`.

## Executable receipts

### PASS — canonical pinned current Grease source

`isomorphisms/grease` PR #3 runs `.github/workflows/grease-receipt.yml` from the top-level repository. It checks out the pinned `source/` submodule at `8052868` and runs the inherited substantive Oils command `soil/github-actions.sh run-job cpp-spec podman` without the unrelated publishing step. Run `33708983086` completed successfully on convergence head `4de2e036788e8c9a6a959ae72ccc1786bdb5f1d5`.

This is the canonical current receipt for the reconciled source pin. It does not replace Oils/YSH as the wider behavioral oracle; it makes that oracle reproducible from the Grease repository itself.

### PASS — readable Grease boolean syntax

The code-bearing `grease/readable-tests` head `ac8d766` ran GitHub Actions run `32572974720`. In the `cpp-spec` job, the substantive `cpp-spec` step completed successfully. The job became red only in the later `publish-html` step.

The tested head and merged `grease/main` commit `8052868` have identical blobs for the Grease lexer (`frontend/lexer_def.py`, blob `3bb10cff589df52772638e80b85c892a05b738a8`) and focused Grease spec (`spec/grease-readable-operators.test.sh`, blob `0ec3f74e398e8cae28697ab3ffe0400f357ccd9c`). The executable result therefore applies to the current implementation content for this feature.

The focused spec exercises condition brackets, conjunction, disjunction, negation in command and condition contexts, and quoted literal glyphs.

### PASS — integrated quick wins

Recovered test records for the quick-wins work reported structural checks passing, and the three commits are ancestors of current `grease/main`. These changes remove disabled/dead work rather than alter language results.

### PASS / SKIP — Ithon migration experiment

PASS: the lowered Ithon smoke executed and printed `grease:ithon:42`.

SKIP: native Ithon execution was unavailable because no built `ithon` executable existed. This is experiment evidence, not the current Grease runtime.

### SKIP — ICKY bridge

No current executable receipt is claimed. The recovered environment lacked `idris2`, and the ICKY bridge was never integrated into `oils:grease/main`.

### FAIL — historical publishing infrastructure, not Grease semantics

The older readable-syntax Actions run is globally red because `publish-html` failed after substantive jobs such as `cpp-spec` had passed. The top-level canonical receipt deliberately runs the same substantive `cpp-spec` job without that publishing step and is green. Do not treat the old publisher failure as a language-test failure.

## Remaining questions

1. Should any of `←`, `→`, `×`, `÷`, `λ`, or `ƒ` be implemented in Oils-derived Grease now, or should those experiments survive only as design input to `ish` / Odriç?
2. If anonymous-function notation remains relevant to Grease, is the spelling `λ`, `ƒ`, both, or neither?
3. Are any of the ten unimplemented performance/runtime idea branches still wanted strongly enough to become real issues? Conversation history does not currently distinguish them from archived experiments.
4. How much new behavior should Grease receive after the split, beyond maintaining a useful executable/reference shell while `ish` catches up? The evidence establishes the roles but not a feature-freeze policy.

## Next material implementation step

Give the pinned current source a small named Grease entrypoint and direct smoke test that invokes that entrypoint on Grease-readable source. The new CI receipt proves the pinned implementation and inherited spec suite run together; the remaining execution seam is that Grease is still represented primarily as an Oils source line rather than as a clearly named executable built from that exact pin. Do this without inventing new language semantics: build or wrap the existing current implementation, run a small `⟦ ... ⟧` / `∧` / `∨` / `¬` program through it, and retain Oils/YSH behavior as the oracle.
