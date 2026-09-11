# ish milestone 0: one incantation becomes one process

> **Current milestone specification.** This document describes the maintained
> executable slice. Historical exploration lives under `docs/research/`.

The smallest thing that counts as `ish` is not a prompt, a built-in `echo`, or
a program that prints a hard-coded byte. It is a piece of shell-language source
that names an external program and some inputs, followed by the correct
operating-system process transition.

## Semantic source form

The first source form denotes exactly one incantation:

```text
Incantation
  source:
    file path
    decoded text
  span
  name:   IncantationName
  inputs: sequence of Input
```

The incantation retains the identity and decoded text of the source that
produced it, and every source word retains its source span. In milestone 0,
each input produces exactly one process input: there is no interpolation,
splitting, joining, globbing, or substitution. Source text and the UTF-8 bytes
passed to the operating system are distinct values; the probe exercises both
ASCII and non-ASCII text.

The concrete spelling of a word and its quoting rules are deliberately not
fixed by this document. That is a language decision, not something to inherit
accidentally from POSIX shell tokenization.

## Execution

The shell:

1. receives and decodes one source unit;
2. understands it as one source-identified `Incantation`;
3. casts that incantation by converting the program and inputs at the Unix
   boundary to an argument vector whose first entry is the program name and
   whose final machine entry is null;
4. preserves the inherited environment, current directory, and file
   descriptors 0, 1, and 2;
5. calls `execve` on an explicit absolute or relative program path.

On success, `execve` replaces `ish`; milestone 0 therefore needs neither
`fork` nor `wait`. The invoked program's exit status is automatically the
status observed by `ish`'s caller. On failure, `ish` reports the operation,
path, source span, and operating-system error, then exits nonzero.

There is no `PATH` search in this milestone.

## The boring green gate

One small native probe receives two distinct process inputs, writes their exact
length-delimited bytes, and exits with a distinctive nonzero status. The gate
passes only when:

- the `ish` runner was compiled from maintained `.idric` source by the exact
  Idriç revision in `_/idric.lock` through the Chez target without RefC;
- the incantation is obtained from source at runtime rather than recognized by
  name in the compiler or baked into generated assembly;
- the probe sees exactly `argv[0]` followed by the two requested process inputs
  and no extra or merged words;
- stdout bytes and exit status match exactly;
- no existing shell, including `/bin/sh`, is invoked;
- malformed source and a missing executable fail deterministically at their
  own boundaries.

This is the shell analogue of the first tiny ELF gate: one real source unit,
one complete path through the implementation, one exact observable result.

## Not in milestone 0

Quoting syntax, variables, expansions, multiple incantations, `fork`, `wait`,
redirections, pipelines, `PATH`, built-ins, actions, conditions, loops,
signals, a prompt, and job control are absent. This milestone does not specify
their eventual design.
