# ish design receipt 1: one incantation

> **Design and acceptance receipt.** This note records the decisions embodied
> by the maintained first executable slice. It is not the general shell
> specification; historical exploration lives under `docs/research/`.

## Vocabulary and representation

An **incantation** is what Unix literature ordinarily calls a command. An
**action** is reserved for a reusable language-level operation; milestone 0 has
none. An incantation's positional textual values are its **inputs**.

Normal source, names, inputs, paths, environment values, and data are text.
Idriç calls decoded character text `Text`; its inherited Chez boundary encodes
that text as UTF-8. Source bytes are validated before decoding so malformed
UTF-8 cannot silently become replacement characters. NUL is rejected because a
Unix process input cannot contain it. Non-text Unix filenames are outside this
chosen model; that is a deliberate limit, not a claim that every Unix filename
is text.

`argv` remains useful only when describing the foreign Unix ABI. The Idriç
program works with an input list.

## The first concrete source spelling

The runner receives exactly one source filename. Within that file, whitespace
separates nonempty words. The first word is the incantation name and every
later word is one input. Whitespace has no other meaning. There is no quoting,
escaping, interpolation, splitting, globbing, substitution, comment syntax,
or second incantation.

This spelling is intentionally provisional. It exists so that the semantic
and operating-system boundaries can run end to end; it does not settle a
future word language.

Spans are half-open `Cardinality` character offsets into decoded source text.
Byte offsets at the UTF-8 decoding boundary are also Cardinalities, but remain
byte offsets rather than masquerading as source spans. The scanner retains a
span for the name and each input. The resulting incantation retains its source
file identity and decoded source text rather than receiving loose source
counts or text later. Empty or whitespace-only source is represented as an
incomplete incantation awaiting a name rather than discarded as a generic parse
error.

## Semantic path

| Boundary | Before | After | Information deliberately changed |
|---|---|---|---|
| Scan | source text | located source words | word boundaries become explicit |
| Parse | source identity and located words | source-identified incantation, name, and inputs | positional roles become explicit |
| Prepare replacement | incantation | current-process replacement | the name becomes an exact executable path, input spans are dropped, source identity is retained for failure, and no `PATH` search occurs |
| Foreign call | path and input list | `execve` path and `argv` | text is UTF-8 encoded; the final null pointers are constructed |
| Success | current process | invoked program | process image is replaced; environment, directory, and descriptors are inherited |
| Failure | raw operating-system errno | process-replacement failure | the raw integer is consumed at the foreign boundary while path, source span, operation, and operating-system error text remain available for diagnosis |

The private Idriç/C call uses length-framed bytes because the foreign interface
cannot pass `List Text` directly. That encoding is neither source syntax nor a
public value. The C primitive knows nothing about whitespace or incantations.

The Chez backend normally emits a `/bin/sh` launcher that adds library-path
variables. `ish` instead uses a small native launcher. It saves the caller's
prior loader environment, starts the compiled Chez program directly, and the
execution primitive restores that environment before `execve`. Backend
packaging is therefore absent from the invoked program's environment.

## Type guidance without premature rejection

The parser distinguishes a source-file path, validated decoded source text,
their combined source identity, spans, an incantation name, inputs, an
incomplete incantation, an executable path, a description of replacing the
current process, and a replacement failure. These distinctions either preserve
information or restrict a real operation. Plain values remain plain where they
are honest representations.

The maintained source uses canonical Idriç vocabulary directly. `Text` is
ordinary decoded text. `Cardinality` is used for zero-capable source lengths,
character offsets, byte offsets, and UTF-8 sequence widths. `Number` is reserved
for genuinely positive whole-number meanings; this slice currently needs no
such programmer-facing value. `±Number` is likewise not used merely to disguise
raw ABI integers. Source octets are named `Source_byte` and remain raw bytes
inside the decoder; `Bits8` is only that boundary type's compiler
representation. UTF-8 byte ranges are named, and the exceptional bounds are
documented where they prevent overlong encodings, surrogate values, or values
beyond U+10FFFF.

The readable program entry remains in top-level `Ish.idric`: receive source,
understand an incantation, and cast it. Source receipt, understanding, casting,
failure reporting, and foreign execution are grouped beneath `Ish/`; build and
foreign-runtime machinery remain beneath `_` and reach the top-level source
through `_/src`. Idriç makes `.idric` source total by default, so the program
does not begin with an inherited `%default total` directive. Its byte reader is
structurally decreasing and does not require a `covering` escape.

There is no catalogue of known incantations and no signature checking in this
slice. Any nonempty name can prepare a current-process replacement, so ordinary
Unix programs remain interoperable.

## Deliberately absent

There is no `PATH` search, process creation, waiting, pipeline, redirection,
builtin, action, variable, environment editing, expansion, pattern, prompt,
line editor, completion engine, job control, or compatibility mode. This
receipt makes no design claim about those absent features.
