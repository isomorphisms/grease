# Fragments

`fragments/` contains the chopped pieces produced from whole material in `root-cellar/`.

Fragments are the units that later participate in link graphs, Cauldron indexes, reading telemetry, and Pensive strands. A fragment keeps enough source identity and range information to trace it back to the whole ingredient and to the knife receipt that produced it.

Conceptually:

```text
fragments/<fragment-id>/
  content
  source
  source-range
  knife-receipt
```

The content representation may vary with the source and view. Fragment identity should survive rebuilding Cauldron indexes and Pensive strands.
