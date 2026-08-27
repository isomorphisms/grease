# ish milestone 0: one command becomes one process

The smallest thing that counts as `ish` is not a prompt, a built-in `echo`, or
a program that prints a hard-coded byte. It is a piece of shell-language source
that names an external program and some arguments, followed by the correct
operating-system process transition.

## Semantic source form

The first source form denotes exactly one simple command:

```text
SimpleCommand
  span
  program:   SourceWord
  arguments: sequence of SourceWord
```

Every source word retains its source span. In milestone 0, each word produces
exactly one argument: there is no interpolation, splitting, joining, globbing,
or command substitution. Source text and the bytes passed to the operating
system are distinct values even while the first fixture is restricted to
ASCII.

The concrete spelling of a word and its quoting rules are deliberately not
fixed by this document. That is a language decision, not something to inherit
accidentally from POSIX shell tokenization.

## Execution

The runner:

1. parses one source unit into one `SimpleCommand`;
2. converts the program and words to an argument vector whose first entry is
   the program name and whose final machine entry is null;
3. preserves the inherited environment, current directory, and file
   descriptors 0, 1, and 2;
4. calls `execve` on an explicit absolute or relative program path.

On success, `execve` replaces `ish`; milestone 0 therefore needs neither
`fork` nor `wait`. The invoked program's exit status is automatically the
status observed by `ish`'s caller. On failure, `ish` reports the operation,
path, source span, and operating-system error, then exits nonzero.

There is no `PATH` search in this milestone.

## The boring green gate

One small native probe receives two distinct arguments, writes their exact
length-delimited bytes, and exits with a distinctive nonzero status. The gate
passes only when:

- the `ish` runner was compiled from `.idric` implementation source by Odriç
  to the native target without RefC;
- the command is obtained from source at runtime rather than recognized by
  name in the compiler or baked into generated assembly;
- the probe sees exactly `argv[0]` followed by the two requested arguments and
  no extra or merged words;
- stdout bytes and exit status match exactly;
- no existing shell, including `/bin/sh`, is invoked;
- malformed source and a missing executable fail deterministically at their
  own boundaries.

This is the shell analogue of the first tiny ELF gate: one real source unit,
one complete path through the implementation, one exact observable result.

## Not in milestone 0

Quoting syntax, variables, expansions, multiple commands, `fork`, `wait`,
redirections, pipelines, `PATH`, built-ins, functions, conditions, loops,
signals, a prompt, and job control all come later. The first feature that needs
one of them should force that facility into existence with its own boundary
test.
