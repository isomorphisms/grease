# grease

a language to smooth the friction between things that come in contact with another ("shell")

based on oil, thickened up with my own bubbles

## Source

The Grease implementation is pinned under `source/` as a git submodule. It points at the `grease/main` line of `isomorphisms/oils`, currently commit `e9a54ad727d89cd593d0bfe56136046808ea81d2`.

Clone with submodules to obtain the complete source tree:

```sh
git clone --recurse-submodules https://github.com/isomorphisms/grease.git
```

Keeping the Oils-derived tree as a pinned submodule avoids copying the full upstream repository while giving Grease one stable, reproducible source location for CI and local builds.

## Service glue

Filesystem-oriented service runners live under `services/`.  The first one is
the [inspectable SMS service](services/sms/README.md): deterministic Idriç
request parsing, durable one-time reminders, explicit consent provenance,
`CANCEL`/`STOP`, and a fake outbox.
