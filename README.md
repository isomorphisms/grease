# grease

A language to smooth the friction between things that come in contact with one another ("shell"), based on Oils/YSH and thickened with Grease-specific changes.

Grease is currently the working Oils/YSH-derived implementation and reference predecessor to `ish`. `ish` is a separate Odriç-written descendant; it is not a rename of this source tree and it does not make Grease depend on Odriç.

See [`docs/CURRENT-GREASE.md`](docs/CURRENT-GREASE.md) for the reconciled language state, branch archaeology, superseded experiments, and executable receipts.

## Source

The Grease implementation is pinned under `source/` as a git submodule. It points at the `grease/main` line of `isomorphisms/oils`, currently commit `8052868773077602266d80bf39aad6998e2da749`.

Clone with submodules to obtain the complete source tree:

```sh
git clone --recurse-submodules https://github.com/isomorphisms/grease.git
```

Keeping the Oils-derived tree as a pinned submodule avoids copying the full upstream repository while giving Grease one stable, reproducible source location for CI and local builds.
