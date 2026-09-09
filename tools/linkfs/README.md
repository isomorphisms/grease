# Grease filesystem link/index draft

This is a Grease-side shell prototype for the fragment/link/index idea.  It has no Idriç dependency.

The design keeps ordinary files as the durable representation and deliberately materializes the same relationships in many filesystem indexes when that makes an important query cheap or inspectable.

## State

```text
ROOT/
  links.tsv          source, relation, destination
  indexes.tsv        index path, entry name, target
  objects/           objects/fragments/documents chosen by the caller
  view/              rebuildable symlink projections
  strands/           optional materialized ordered traversals
```

`links.tsv` is the logical graph.  `indexes.tsv` describes filesystem projections.  `view/` can be deleted and rebuilt from `indexes.tsv`.

The program does not prescribe one ontology.  Directory names are index keys chosen by the application.

## Small graph

```sh
linkfs.sh init ./state

linkfs.sh link ./state 231 next 232
linkfs.sh link ./state 232 next 240
linkfs.sh link ./state 231 citation 804

linkfs.sh from ./state 231
linkfs.sh to ./state 804 citation
linkfs.sh strand ./state 231 next
```

The `strand` operation reads `links.tsv` once and follows the selected relation in memory.  It does not perform one disk lookup for each hop.

A later implementation can compile the same table into source-sorted and destination-sorted binary adjacency arrays for mmap/range reads without changing the shell-facing model.

## Filesystem projections

A projection is just an arbitrary relative index path plus an entry name and a target relative to the state root:

```sh
linkfs.sh index ./state from/231/next 232 objects/232
linkfs.sh index ./state to/232/next 231 objects/231
```

which produces, conceptually:

```text
view/from/231/next/232 -> ../../../../../objects/232
view/to/232/next/231   -> ../../../../../objects/231
```

The same object can appear in as many projections as useful.  The directory hierarchy is an index, not ownership.

## Cauldron-style document indexes

A document corpus can use the same mechanism without changing `linkfs.sh`.

For an arXiv paper, the application can keep one canonical document object and project it independently by author, title, arXiv subject, themes, or later statistical indexes:

```text
objects/<document-id>/

view/authors/<author>/<document-id>             -> object
view/titles/<title>                             -> object
view/arxiv/math.HO/<document-id>                -> object
view/arxiv/math.CO/<document-id>                -> object
view/themes/love/<document-id>                  -> object
view/themes/nature/<document-id>                -> object
view/tf-idf/<term>/<ranked-entry>               -> object
view/pmi/<term>/<ranked-entry>                  -> object
view/lsi/<concept-or-component>/<ranked-entry>  -> object
view/bm25/<query-or-term>/<ranked-entry>         -> object
```

`themes` is only an example application name; the link/index engine does not reserve it.  A corpus may instead call that projection `topoi`, `facets`, `subjects`, or something else.

For Poetry Foundation material, one projection can mirror each theme in the source list and place symlinks to the poems/documents under every applicable theme.  For arXiv, another projection can use the source categories such as `math.HO` and `math.CO`.  These projections can coexist with author and title indexes because they all point to the same canonical objects.

Likewise, later corpus scans can add new projections for distinguishing terms or retrieval models without rewriting the objects.  TF-IDF, mutual-information/PMI features, latent semantic indexing, BM25, or another scorer can each emit its own directory tree.  Sortable score/rank prefixes may be put in entry names when directory enumeration should already be ranking order.

## URL identity

A POSIX filename cannot literally contain `/`, so a complete `https://...` URL cannot be one raw filename.  The application may choose either:

- a reversible filename encoding of the URL; or
- a URL-shaped directory hierarchy.

`linkfs.sh` deliberately does not impose either choice.  The important invariant is that all projections ultimately point to the same chosen canonical object.

## Why symlinks

An empty marker file can record membership, but a symlink carries both membership and a traversable target.  The containing directories and symlink filename remain free to encode additional index dimensions.

For example:

```text
view/authors/Emmy-Noether/2609.01234 -> ../../../objects/...
```

says both "this object appears under this author index" and "follow this entry to the object."  Another directory can independently index the same object by title, subject, theme, score, or strand position.

## Boundary

This is not a database server and it is not an OS/filesystem rewrite.  It is intended to establish the semantics with ordinary files on Android first.

Hot paths need not traverse symlinks one by one.  Durable tables and filesystem projections can be compiled into compact source/destination indexes or materialized strands.  Redundant indexes are expected: the semantic-system goal is to make useful relationships cheap from several directions rather than preserve one normalized physical representation.
