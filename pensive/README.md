# Pensive

`pensive/` owns assembled reading state produced from the fragment graph and Cauldron indexes.

The first concrete subdirectory is `strands/`. A strand is an ordered sequence of fragment identities chosen for presentation or work. It is not the full graph and it is not another copy of the fragment contents.

```text
pensive/
  strands/
    <strand-id>
```

A viewer can request a window of a strand, prefetch/layout/prepaint the nearby fragments, and report exposure observations back to Pensive.
