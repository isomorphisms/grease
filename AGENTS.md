# Agent instructions

Apply the shared evidence and acceptance guardrails in
`isomorphisms/ai-ci/AGENTS.md`. Before changing Grease, read
[`docs/CURRENT-GREASE.md`](docs/CURRENT-GREASE.md); it is the evidence-backed
statement of the current line.

## Do not promote archaeology into current design

A branch name, label-only idea branch, old experiment, or earlier roadmap is not
by itself a current decision. Do not manufacture missing implementation from an
experiment branch or promote it merely because it exists.

Current Grease is the Oils/YSH-derived line pinned through this repository's
`source/` submodule. `ish`/Odriç is a separate successor line. Ithon and ICKY
experiments are evidence and design input, not current Grease semantics unless a
later explicit decision promotes them.

## Do not masquerade another runtime as Grease

Do not call Bash, POSIX shell, Python/Ithon, a lowered smoke, or a wrapper around
another implementation a Grease execution receipt.

A Grease receipt must identify the exact source revision and exercise the
current Grease/Oils/YSH implementation that is being claimed. If the required
runtime is unavailable, report that boundary as unverified rather than
substituting a familiar shell or interpreter.

## Preserve exact source provenance

Treat the `source/` submodule revision as material provenance. A successful run
against another Oils revision, an old experiment, or a different pin is
historical evidence only.

Keep semantic tests distinct from unrelated publishing/infrastructure stages; a
publisher failure does not retroactively make a passed language test fail, and
a language-test pass does not prove later packaging or publishing stages.
