# ish design receipt 1: one incantation

This note records the decisions embodied by the first executable slice. It is
a receipt for a deliberately small experiment, not a commitment to a complete
shell language.

## Vocabulary and representation

An **incantation** is what Unix literature ordinarily calls a command. An
**action** will be the reusable language-level concept ordinarily called a
function, though milestone 0 has none. An incantation's positional textual
values are its **inputs**. Behavior modifiers may later be called **options**.

Normal source, names, inputs, paths, environment values, and data are text.
This implementation uses Idriç `String`, whose Chez foreign boundary encodes
text as UTF-8. Source bytes are validated before decoding so malformed UTF-8
cannot silently become replacement characters. NUL is rejected because a Unix
process input cannot contain it.
Non-text Unix filenames are outside this chosen model; that is a deliberate
limit, not a claim that every Unix filename is text.

`argv` remains useful only when describing the foreign Unix ABI. The Idriç
program works with an input list.

## The first concrete source spelling

The runner receives exactly one source filename. Within that file, whitespace
separates nonempty words. The first word is the incantation name and every
later word is one input. Whitespace has no other meaning. There is no quoting,
escaping, interpolation, splitting, globbing, substitution, comment syntax,
or second incantation.

This spelling is intentionally provisional. It exists so that the semantic
and operating-system boundaries can run end to end; it does not settle the
eventual word language.

Spans are half-open character offsets into decoded source text. Byte offsets at
the UTF-8 decoding boundary remain byte offsets rather than masquerading as
source spans. The scanner retains a
span for the name and each input. Empty or whitespace-only source is represented
as an incomplete incantation awaiting a name, rather than discarded as a
generic parse error. That distinction is the first small hook for a future
type-guided interactive editor.

## Semantic path

| Boundary | Before | After | Information deliberately changed |
|---|---|---|---|
| Scan | source text | located source words | word boundaries become explicit |
| Parse | located words | incantation name and inputs | positional roles become explicit |
| Prepare replacement | incantation name | current-process replacement | the name becomes an exact executable path, input spans are dropped, and no `PATH` search occurs |
| Foreign call | path and input list | `execve` path and `argv` | text is UTF-8 encoded; the final null pointers are constructed |
| Success | current process | invoked program | process image is replaced; environment, directory, and descriptors are inherited |
| Failure | operating-system errno | process-replacement failure | path, source span, operation, and error text remain available for diagnosis |

The private Idriç/C call uses length-framed bytes because the foreign interface
cannot pass `List Text` directly. That encoding is neither source syntax nor a
public value. The C primitive knows nothing about whitespace or incantations.

The Chez backend normally emits a `/bin/sh` launcher that adds library-path
variables. `ish` instead uses a small native launcher. It saves the caller's
prior loader environment, starts the compiled Chez program directly, and the
execution primitive restores that environment before `execve`. Backend
packaging is therefore absent from the invoked program's environment.

## Type guidance without premature rejection

The first parser distinguishes source text, spans, an incantation name, inputs,
an incomplete incantation, an executable path, a description of replacing the
current process, and a replacement failure. These distinctions either preserve
information or restrict a real operation. Plain text, numbers, booleans, and
lists remain plain where they are honest representations.

The Idriç source uses `Number` for nonnegative counts and locations. Its one
signed foreign-machine representation is named `Positive_or_negative_number`
instead of leaking `Int` into the semantic model. Source octets are named
`Source_byte`; `Bits8` is only that type's compiler representation. UTF-8 byte
ranges are named, and the exceptional bounds are documented where they prevent
overlong encodings, surrogate values, or values beyond U+10FFFF.

The readable program entry remains in top-level `Ish.idric`. Supporting
implementations are grouped beneath `Ish/`; build and foreign-runtime machinery
remain beneath `_` and reach the top-level source through `_/src`.

There is no catalogue of known incantations and no signature checking yet. Any
nonempty name can prepare a current-process replacement, so ordinary Unix
programs remain interoperable. Later descriptions can add semantic completion
and guidance without changing that fallback. Types should help the user
discover what can come next; they need not turn every unknown or incomplete
interaction into a hard error.

## Deliberately absent

There is no `PATH`, process creation, waiting, pipeline, redirection, builtin,
action, variable, environment editing, expansion, pattern, prompt, line editor,
completion engine, job control, or compatibility mode. The first feature that
needs one of those facilities should expose its own semantic boundary rather
than widening this slice pre-emptively.
