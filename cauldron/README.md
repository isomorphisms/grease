# Cauldron

`cauldron/` is the concrete corpus root for the multiply indexed filesystem experiment.

The corpus keeps canonical objects separate from rebuildable index projections. One object may appear under many projections at once through symlinks.

Tracked projection roots:

```text
cauldron/
  objects/
  authors/
  titles/
  arxiv/
  themes/
  tf-idf/
  pmi/
  lsi/
  bm25/
```

These names are filesystem indexes, not an ontology or ownership tree. Additional projections may be added freely. `themes/` may later be renamed or supplemented by `topoi/`, `facets/`, or another corpus-specific vocabulary.

For arXiv material, examples include category projections such as `arxiv/math.HO/` and `arxiv/math.CO/`. Author and title indexes point to the same canonical object. Statistical and retrieval indexes such as TF-IDF, PMI, LSI, and BM25 likewise project the same corpus rather than copying it.

The Grease `tools/linkfs/` prototype is responsible for creating and rebuilding these symlink projections from durable index records. No Idriç dependency is required.
