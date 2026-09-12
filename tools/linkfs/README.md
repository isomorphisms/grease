# Grease filesystem link/index draft

This is a Grease-side shell prototype for the fragment/link/index idea. It has no Idriç dependency.

The current working projection is:

```text
root-cellar/ -> fragments/ -> cauldron/ -> pensive/strands/
```

Those names are not an architecture or compatibility contract. The prototype is testing four semantic roles: durable source material, stable fragment identities, rebuildable query projections, and materialized ordered strands. A later implementation may rename, collapse, or compile any of the current directories while preserving those roles.

## Root cellar

`root-cellar/` is the current prototype landing place for whole source ingredients before chopping. The raw source stays intact. A source may carry a `knife/` receipt recording whether it has been chopped, which chopping program/version did it, and which fragment identities were produced.

## Fragments

`fragments/` currently contains the chopped pieces. Fragment identities are the stable things that participate in graph links, projections, reading observations, and strands.

## Multiply indexed projections

`cauldron/` is the current multiply indexed layer over fragments. It deliberately materializes the same relationships many ways when that makes an important query cheap or inspectable.

`links.tsv` is the current durable logical fragment graph. Every graph edge gets forward and reverse symlink projections such as:

```text
cauldron/from/231/next/232 -> fragments/232
cauldron/to/232/next/231   -> fragments/231
```

The `from` and `to` commands enumerate these generated endpoint projections instead of rescanning the complete durable link table. The path spelling is an implementation detail of this prototype.

`indexes.tsv` describes additional caller-defined projections. Examples include:

```text
cauldron/authors/...
cauldron/titles/...
cauldron/arxiv/math.HO/...
cauldron/themes/...
cauldron/tf-idf/...
cauldron/pmi/...
cauldron/lsi/...
cauldron/bm25/...
```

These are indexes, not one ontology or ownership tree. The same fragment can appear in as many of them as useful. Directory names and symlink names are themselves another indexing layer.

For a multi-author arXiv paper, a caller may create one projection under each author and each arXiv category. Poetry Foundation themes can become another independent projection. Statistical and retrieval passes can independently emit later projections without rewriting the fragments.

`rebuild` deletes and recreates the generated projection tree from the durable tables.

## Strands

A strand is an ordered sequence of fragment identities chosen for reading or work. It is not the full graph and it is not another copy of fragment contents.

```sh
linkfs.sh strand ./state 231 next > ./reading-1.strand
```

The output location is deliberately chosen by the caller; the command does not make the current `pensive/strands/` spelling part of its interface.

The strand operation reads the durable link table once and follows the selected relation in memory, avoiding one filesystem or graph lookup per hop. The resulting file is independently consumable after the graph representation is gone. This proves the sequential materialization boundary; it does not yet prove a final mmap format or constant-time positional window lookup. A later implementation can compile the same semantics into compact strand and adjacency indexes.

## Commands

```sh
linkfs.sh init ROOT
linkfs.sh link ROOT FROM KIND TO
linkfs.sh links ROOT < links.tsv
linkfs.sh index ROOT INDEX_PATH ENTRY TARGET
linkfs.sh from ROOT FRAGMENT [KIND]
linkfs.sh to ROOT FRAGMENT [KIND]
linkfs.sh strand ROOT START KIND
linkfs.sh rebuild ROOT
```

`links` is the batched path for a graph-shaped input stream. It validates three tab-separated fields per row, merges duplicate logical edges, and rebuilds the projections once rather than launching or scanning once per edge.

A caller-defined projection targets a path relative to `ROOT`, normally a fragment in the current prototype:

```sh
linkfs.sh index ./state authors/Emmy-Noether 2609.01234 fragments/2609.01234
linkfs.sh index ./state arxiv/math.HO 2609.01234 fragments/2609.01234
```

## IB-shaped receipt

`ib-shape-acceptance.sh` uses 4,096 document-order fragments, matching the current IB prepaint block ceiling, plus sparse citation and annotation edges. It materializes the full document-order strand and checks the 64-fragment window used in the IB fragment-link design note. It also reports the number of symlinks, directories, state KiB, and materialized-strand bytes instead of turning one runner's filesystem costs into a brittle pass/fail threshold.

The receipt intentionally tests topology and access boundaries, not today's directory vocabulary. It is not an Android latency benchmark. Literal filesystem projections remain a shell/query representation to measure against compact adjacency indexes, not a claim that the reader should traverse pathname components on its hot path.

## URL identity

The convenient filesystem index does not need to preserve `http` versus `https` in every path. Exact requested/resolved URLs can remain source metadata. A URL projection may use a domain/path hierarchy and add a scheme-specific projection only if some source actually requires that distinction.

## Boundary

This is not a database server and not an OS/filesystem rewrite. It is intended to establish the semantics with ordinary files and symlinks on Android first. Hot readers do not need to traverse those symlinks one by one: the durable relationships can be compiled into compact adjacency indexes or materialized strands.
