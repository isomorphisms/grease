# Grease filesystem link/index draft

This is a Grease-side shell prototype for the fragment/link/index idea. It has no Idriç dependency.

The concrete pipeline is:

```text
root-cellar/ -> fragments/ -> cauldron/ -> pensive/strands/
```

## Root cellar

`root-cellar/` is where whole source ingredients land before chopping. The raw source stays intact. A source may carry a `knife/` receipt recording whether it has been chopped, which chopping program/version did it, and which fragment identities were produced.

## Fragments

`fragments/` contains the chopped pieces. Fragment identities are the stable things that participate in graph links, Cauldron projections, reading observations, and Pensive strands.

## Cauldron

`cauldron/` is the multiply indexed layer over fragments. It deliberately materializes the same relationships many ways when that makes an important query cheap or inspectable.

`links.tsv` is the logical fragment graph. Every graph edge automatically gets forward and reverse symlink projections:

```text
cauldron/from/231/next/232 -> fragments/232
cauldron/to/232/next/231   -> fragments/231
```

`indexes.tsv` describes additional caller-defined projections. Examples include:

```text
cauldron/authors/...
cauldron/titles/...
cauldron/arxiv/math.HO/...
cauldron/arxiv/math.CO/...
cauldron/themes/...
cauldron/tf-idf/...
cauldron/pmi/...
cauldron/lsi/...
cauldron/bm25/...
```

These are indexes, not one ontology or ownership tree. The same fragment can appear in as many of them as useful. Directory names and symlink names are themselves another indexing layer.

For a multi-author arXiv paper, a caller may create one projection under each author and each arXiv category. Poetry Foundation themes can become another independent projection. Later TF-IDF, mutual-information/PMI feature scoring, LSI, BM25, or other retrieval passes can emit their own trees without rewriting fragments.

`rebuild` deletes and recreates the generated Cauldron tree from `links.tsv` and `indexes.tsv`.

## Pensive strands

A strand is an ordered sequence of fragment identities chosen for reading or work. It is not the full graph and it is not another copy of fragment contents.

```sh
linkfs.sh strand ./state 231 next > ./state/pensive/strands/reading-1
```

The strand operation reads `links.tsv` once and follows the selected relation in memory, avoiding one disk lookup per hop. A later implementation can compile the same graph into source-sorted and destination-sorted binary adjacency arrays for mmap/range reads without changing the shell-facing model.

## Commands

```sh
linkfs.sh init ROOT
linkfs.sh link ROOT FROM KIND TO
linkfs.sh index ROOT INDEX_PATH ENTRY TARGET
linkfs.sh from ROOT FRAGMENT [KIND]
linkfs.sh to ROOT FRAGMENT [KIND]
linkfs.sh strand ROOT START KIND
linkfs.sh rebuild ROOT
```

A caller-defined projection targets a path relative to `ROOT`, normally a fragment:

```sh
linkfs.sh index ./state authors/Emmy-Noether 2609.01234 fragments/2609.01234
linkfs.sh index ./state arxiv/math.HO 2609.01234 fragments/2609.01234
```

## URL identity

The convenient filesystem index does not need to preserve `http` versus `https` in every path. Exact requested/resolved URLs can remain source metadata in the root cellar. A URL projection may use a domain/path hierarchy such as:

```text
cauldron/url/arxiv.org/abs/2609.01234
```

and add a scheme-specific projection only if some source actually requires that distinction.

## Boundary

This is not a database server and not an OS/filesystem rewrite. It is intended to establish the semantics with ordinary files and symlinks on Android first. Hot readers do not need to traverse those symlinks one by one: the durable tables can be compiled into compact adjacency indexes or strands.
