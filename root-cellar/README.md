# Root cellar

`root-cellar/` is the durable landing place for whole source material before it is chopped into fragments.

Keep the received or otherwise chosen source representation intact here. A paper, poem, web page, book section, image bundle, or other large ingredient belongs here before fragmentation.

A stored source may carry a **knife receipt** recording whether it has been chopped and, when it has, which chopping program/version produced which fragment identities. The receipt is metadata beside the source; it does not modify the raw source.

Conceptually:

```text
root-cellar/<source-id>/
  source
  source-metadata
  knife/
    status
    program
    version
    fragments
```

The exact receipt grammar is still open. The invariant is that raw storage, chopping, later indexing, and reading strands are separate stages.
