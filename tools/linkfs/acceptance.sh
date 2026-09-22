#!/bin/sh

set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)
program="$here/linkfs.sh"
state=${TMPDIR:-/tmp}/grease-linkfs-test.$$
trap 'rm -rf "$state"' EXIT HUP INT TERM

sh "$program" init "$state"

mkdir -p "$state/root-cellar/paper-a/knife"
printf '%s\n' 'whole paper' > "$state/root-cellar/paper-a/source"
printf '%s\n' chopped > "$state/root-cellar/paper-a/knife/status"
printf '%s\n' '231 232 240 paper-a' > "$state/root-cellar/paper-a/knife/fragments"

mkdir -p "$state/fragments/231" "$state/fragments/232" "$state/fragments/240" "$state/fragments/paper-a"
printf '%s\n' alpha > "$state/fragments/231/text"
printf '%s\n' beta > "$state/fragments/232/text"
printf '%s\n' gamma > "$state/fragments/240/text"
printf '%s\n' paper > "$state/fragments/paper-a/text"

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

sh "$program" strand "$state" 231 next > "$state/pensive/strands/reading-1"
strand=$(cat "$state/pensive/strands/reading-1")
expected=$(printf '231\n232\n240')
[ "$strand" = "$expected" ] || {
  printf 'unexpected strand:\n%s\n' "$strand" >&2
  exit 1
}

# `from` and `to` are derived directly from links.tsv and point to fragments.
[ "$(cat "$state/cauldron/from/231/next/232/text")" = beta ]
[ "$(cat "$state/cauldron/to/232/next/231/text")" = alpha ]
[ "$(cat "$state/cauldron/from/231/citation/paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/to/paper-a/citation/231/text")" = alpha ]

# Arbitrary Cauldron projections are independent of link kinds.
sh "$program" index "$state" authors/Example_Author paper-a fragments/paper-a
sh "$program" index "$state" titles 'An Example Paper' fragments/paper-a
sh "$program" index "$state" arxiv/math.HO paper-a fragments/paper-a
sh "$program" index "$state" themes/Example_Theme paper-a fragments/paper-a
sh "$program" index "$state" tf-idf/example-term 000001-paper-a fragments/paper-a
sh "$program" index "$state" pmi/example-term 000001-paper-a fragments/paper-a
sh "$program" index "$state" lsi/component-001 000001-paper-a fragments/paper-a
sh "$program" index "$state" bm25/example-query 000001-paper-a fragments/paper-a

[ "$(cat "$state/cauldron/authors/Example_Author/paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/titles/An Example Paper/text")" = paper ]
[ "$(cat "$state/cauldron/arxiv/math.HO/paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/themes/Example_Theme/paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/tf-idf/example-term/000001-paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/pmi/example-term/000001-paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/lsi/component-001/000001-paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/bm25/example-query/000001-paper-a/text")" = paper ]

# Destroy every symlink projection and reconstruct it from the two durable tables.
rm -rf "$state/cauldron"
mkdir "$state/cauldron"
sh "$program" rebuild "$state"

[ "$(cat "$state/cauldron/from/231/next/232/text")" = beta ]
[ "$(cat "$state/cauldron/to/paper-a/citation/231/text")" = alpha ]
[ "$(cat "$state/cauldron/authors/Example_Author/paper-a/text")" = paper ]
[ "$(cat "$state/cauldron/bm25/example-query/000001-paper-a/text")" = paper ]

# Reassigning one arbitrary index key replaces its projection and durable row.
sh "$program" index "$state" themes/Example_Theme paper-a fragments/240
[ "$(cat "$state/cauldron/themes/Example_Theme/paper-a/text")" = gamma ]
[ "$(awk -F '\t' '$1 == "themes/Example_Theme" && $2 == "paper-a" { count++ } END { print count + 0 }' "$state/indexes.tsv")" -eq 1 ]

# init is non-destructive once the tables exist.
sh "$program" init "$state"
[ -s "$state/links.tsv" ]
[ -s "$state/indexes.tsv" ]
[ "$(cat "$state/root-cellar/paper-a/source")" = 'whole paper' ]
[ "$(cat "$state/pensive/strands/reading-1")" = "$expected" ]

printf '%s\n' 'grease linkfs acceptance: PASS'
