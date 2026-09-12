#!/bin/sh

set -eu

here=$(CDPATH= cd "$(dirname "$0")" && pwd)
program="$here/linkfs.sh"
state=${TMPDIR:-/tmp}/grease-linkfs-ib-shape.$$
strand=${TMPDIR:-/tmp}/grease-linkfs-ib-strand.$$
window=${TMPDIR:-/tmp}/grease-linkfs-ib-window.$$
trap 'rm -rf "$state" "$strand" "$window"' EXIT HUP INT TERM

# Mirror the current IB prepaint upper block count and the 64-fragment window
# used in the fragment-link design note. The topology is the contract here,
# not the current names of the prototype's directories.
fragment_count=4096
window_start=500
window_count=64

sh "$program" init "$state"

# Build one long document-order strand with sparse side edges. Side edges must
# remain directly queryable without disturbing document-order materialization.
awk -v count="$fragment_count" 'BEGIN {
  for (i = 1; i <= count; i++) {
    if (i < count) {
      printf "doc-%06d\tdocument-order\tdoc-%06d\n", i, i + 1
    }
    if (i % 64 == 0) {
      reference = ((i / 64 - 1) % 8) + 1
      printf "doc-%06d\tcitation\tcitation-%03d\n", i, reference
    }
    if (i % 257 == 0) {
      printf "doc-%06d\tannotation\tnote-%03d\n", i, i / 257
    }
  }
}' | sh "$program" links "$state"

expected_links=$((4095 + 64 + 15))
projection_links=$(find "$state" -type l | wc -l | tr -d ' ')
[ "$projection_links" -eq $((expected_links * 2)) ] || {
  printf 'expected %s bidirectional projection links, got %s\n' "$((expected_links * 2))" "$projection_links" >&2
  exit 1
}

# Exercise source- and destination-oriented queries through the generated
# projections, including fan-out and reverse fan-in.
[ "$(sh "$program" from "$state" doc-002048 document-order)" = "$(printf 'document-order\tdoc-002049')" ]
[ "$(sh "$program" from "$state" doc-002048 citation)" = "$(printf 'citation\tcitation-008')" ]
[ "$(sh "$program" to "$state" doc-002049 document-order)" = "$(printf 'doc-002048\tdocument-order')" ]
[ "$(sh "$program" to "$state" citation-008 citation | wc -l | tr -d ' ')" -eq 8 ]

# Compile the document-order walk once. Sparse citation/annotation edges must
# not leak into the ordered reading strand.
sh "$program" strand "$state" doc-000001 document-order > "$strand"
[ "$(wc -l < "$strand" | tr -d ' ')" -eq "$fragment_count" ]
[ "$(sed -n '1p' "$strand")" = doc-000001 ]
[ "$(sed -n '4096p' "$strand")" = doc-004096 ]

first=$((window_start + 1))
last=$((window_start + window_count))
sed -n "${first},${last}p" "$strand" > "$window"
[ "$(wc -l < "$window" | tr -d ' ')" -eq "$window_count" ]
[ "$(sed -n '1p' "$window")" = doc-000501 ]
[ "$(sed -n '64p' "$window")" = doc-000564 ]

directories=$(find "$state" -type d | wc -l | tr -d ' ')
kilobytes=$(du -sk "$state" | awk '{print $1}')
strand_bytes=$(wc -c < "$strand" | tr -d ' ')

# A materialized journey is reader input in its own right. Delete the graph
# state and prove the selected sequence and its window remain consumable.
# This intentionally pins no state-directory vocabulary.
rm -rf "$state"
[ "$(wc -l < "$strand" | tr -d ' ')" -eq "$fragment_count" ]
[ "$(sed -n '501p' "$strand")" = doc-000501 ]

printf 'ib-shaped linkfs receipt: fragments=%s links=%s projection_symlinks=%s projection_directories=%s state_kib=%s strand_bytes=%s window=%s PASS\n' \
  "$fragment_count" "$expected_links" "$projection_links" "$directories" "$kilobytes" "$strand_bytes" "$window_count"
