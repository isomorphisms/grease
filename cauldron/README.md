# Cauldron

`cauldron/` is the multiply indexed working layer over material that has already been chopped into `fragments/`.

The storage pipeline is:

```text
root-cellar/ -> fragments/ -> cauldron/ -> pensive/strands/
```

- `root-cellar/` keeps whole source ingredients and chopping receipts.
- `fragments/` keeps the chopped pieces.
- `cauldron/` adds many rebuildable index projections over those fragments.
- `pensive/strands/` keeps ordered sequences of fragment identities chosen for viewing or work.

Cauldron does not own another canonical copy of the content. Its entries should normally be symlinks or other rebuildable index records pointing back to `../fragments/`.

Tracked projection roots:

```text
cauldron/
  authors/
  titles/
  arxiv/
  themes/
  tf-idf/
  pmi/
  lsi/
  bm25/
```

These names are indexes, not one ontology or ownership tree. Additional projections may be added freely. `themes/` may later coexist with or be renamed to `topoi/`, `facets/`, or another corpus-specific vocabulary.

For arXiv material, category projections can include `arxiv/math.HO/`, `arxiv/math.CO/`, and so on. Author and title projections can index every applicable fragment from the same paper. Poetry Foundation themes can project fragments under every applicable theme. Statistical and retrieval passes can independently add TF-IDF, PMI, LSI, BM25, or later projections without rewriting the fragments.

Directory names and symlink names are themselves useful index dimensions. Redundant projections are intentional.

The Grease `tools/linkfs/` prototype creates and rebuilds these filesystem projections from durable index records. No Idriç dependency is required.
