#!/bin/sh

set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)
program="$here/linkfs.sh"
state=${TMPDIR:-/tmp}/grease-linkfs-test.$$
trap 'rm -rf "$state"' EXIT HUP INT TERM

sh "$program" init "$state"

mkdir -p "$state/objects/231" "$state/objects/232" "$state/objects/240" "$state/objects/paper-a"
printf '%s\n' alpha > "$state/objects/231/text"
printf '%s\n' beta > "$state/objects/232/text"
printf '%s\n' gamma > "$state/objects/240/text"
printf '%s\n' paper > "$state/objects/paper-a/text"

sh "$program" link "$state" 231 next 232
sh "$program" link "$state" 232 next 240
sh "$program" link "$state" 231 citation paper-a

from=$(sh "$program" from "$state" 231 next)
expected_from=$(printf 'next\t232')
[ "$from" = "$expected_from" ] || {
  printf 'unexpected from query: %s\n' "$from" >&2
  exit 1
}

to=$(sh "$program" to "$state" paper-a citation)
expected_to=$(printf '231\tcitation')
[ "$to" = "$expected_to" ] || {
  printf 'unexpected to query: %s\n' "$to" >&2
  exit 1
}

strand=$(sh "$program" strand "$state" 231 next)
expected=$(printf '231\n232\n240')
[ "$strand" = "$expected" ] || {
  printf 'unexpected strand:\n%s\n' "$strand" >&2
  exit 1
}

# `from` and `to` are derived directly from links.tsv.
[ "$(cat "$state/view/from/231/next/232/text")" = beta ]
[ "$(cat "$state/view/to/232/next/231/text")" = alpha ]
[ "$(cat "$state/view/from/231/citation/paper-a/text")" = paper ]
[ "$(cat "$state/view/to/paper-a/citation/231/text")" = alpha ]

# Arbitrary corpus projections are independent of link kinds.
sh "$program" index "$state" authors/Example_Author paper-a objects/paper-a
sh "$program" index "$state" titles 'An Example Paper' objects/paper-a
sh "$program" index "$state" arxiv/math.HO paper-a objects/paper-a
sh "$program" index "$state" themes/Example_Theme paper-a objects/paper-a
sh "$program" index "$state" tf-idf/example-term 000001-paper-a objects/paper-a
sh "$program" index "$state" pmi/example-term 000001-paper-a objects/paper-a
sh "$program" index "$state" lsi/component-001 000001-paper-a objects/paper-a
sh "$program" index "$state" bm25/example-query 000001-paper-a objects/paper-a

[ "$(cat "$state/view/authors/Example_Author/paper-a/text")" = paper ]
[ "$(cat "$state/view/titles/An Example Paper/text")" = paper ]
[ "$(cat "$state/view/arxiv/math.HO/paper-a/text")" = paper ]
[ "$(cat "$state/view/themes/Example_Theme/paper-a/text")" = paper ]
[ "$(cat "$state/view/tf-idf/example-term/000001-paper-a/text")" = paper ]
[ "$(cat "$state/view/pmi/example-term/000001-paper-a/text")" = paper ]
[ "$(cat "$state/view/lsi/component-001/000001-paper-a/text")" = paper ]
[ "$(cat "$state/view/bm25/example-query/000001-paper-a/text")" = paper ]

# Destroy every symlink projection and reconstruct it from the two durable tables.
rm -rf "$state/view"
mkdir "$state/view"
sh "$program" rebuild "$state"

[ "$(cat "$state/view/from/231/next/232/text")" = beta ]
[ "$(cat "$state/view/to/paper-a/citation/231/text")" = alpha ]
[ "$(cat "$state/view/authors/Example_Author/paper-a/text")" = paper ]
[ "$(cat "$state/view/bm25/example-query/000001-paper-a/text")" = paper ]

# Reassigning one arbitrary index key replaces its projection and durable row.
sh "$program" index "$state" themes/Example_Theme paper-a objects/240
[ "$(cat "$state/view/themes/Example_Theme/paper-a/text")" = gamma ]
[ "$(awk -F '\t' '$1 == "themes/Example_Theme" && $2 == "paper-a" { count++ } END { print count + 0 }' "$state/indexes.tsv")" -eq 1 ]

# init is non-destructive once the tables exist.
sh "$program" init "$state"
[ -s "$state/links.tsv" ]
[ -s "$state/indexes.tsv" ]

printf '%s\n' 'grease linkfs acceptance: PASS'
