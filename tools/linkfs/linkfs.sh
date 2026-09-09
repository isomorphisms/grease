#!/bin/sh

set -eu

program_name=${0##*/}
tab=$(printf '\t')

fail() {
  printf '%s: %s\n' "$program_name" "$1" >&2
  exit 1
}

usage() {
  fail "usage: $program_name init ROOT | link ROOT FROM KIND TO | index ROOT INDEX_PATH ENTRY TARGET | rebuild ROOT | from ROOT FRAGMENT [KIND] | to ROOT FRAGMENT [KIND] | strand ROOT START KIND"
}

safe_field() {
  case "$1" in
    *"$tab"*) return 1 ;;
  esac
  case "$1" in
    *'
'*) return 1 ;;
    *) return 0 ;;
  esac
}

safe_component() {
  safe_field "$1" || return 1
  case "$1" in
    ''|*/*|.|..) return 1 ;;
    *) return 0 ;;
  esac
}

safe_relative_path() {
  path=$1
  [ -n "$path" ] || return 1
  case "$path" in
    /*|../*|*/../*|*/..|..|.|./*|*/./*|*/.) return 1 ;;
    *) return 0 ;;
  esac
}

require_state() {
  root=$1
  [ -d "$root" ] || fail "state does not exist: $root"
  [ -f "$root/links.tsv" ] || fail "missing link table: $root/links.tsv"
  [ -f "$root/indexes.tsv" ] || fail "missing index table: $root/indexes.tsv"
}

initialize() {
  root=$1
  mkdir -p "$root/root-cellar" "$root/fragments" "$root/cauldron" "$root/pensive/strands"
  [ -f "$root/links.tsv" ] || : > "$root/links.tsv"
  [ -f "$root/indexes.tsv" ] || : > "$root/indexes.tsv"
}

append_unique() {
  file=$1
  line=$2
  if ! grep -F -x -e "$line" "$file" >/dev/null 2>&1; then
    printf '%s\n' "$line" >> "$file"
  fi
}

relative_target() {
  index_path=$1
  target=$2

  # The symlink lives below cauldron/INDEX_PATH. Walk back to the state root,
  # then descend to TARGET.
  prefix=..
  rest=$index_path
  while :; do
    prefix="$prefix/.."
    case "$rest" in
      */*) rest=${rest#*/} ;;
      *) break ;;
    esac
  done
  printf '%s/%s\n' "$prefix" "$target"
}

materialize_index_in() {
  cauldron_root=$1
  index_path=$2
  entry=$3
  target=$4

  safe_relative_path "$index_path" || fail "unsafe index path: $index_path"
  safe_relative_path "$target" || fail "unsafe target path: $target"
  safe_component "$entry" || fail "index entry must be one safe filename: $entry"

  directory="$cauldron_root/$index_path"
  mkdir -p "$directory"
  link_target=$(relative_target "$index_path" "$target")
  temporary="$directory/.${entry}.tmp.$$"
  rm -f "$temporary"
  ln -s "$link_target" "$temporary"
  mv -f "$temporary" "$directory/$entry"
}

materialize_link_in() {
  cauldron_root=$1
  from=$2
  kind=$3
  to=$4

  materialize_index_in "$cauldron_root" "from/$from/$kind" "$to" "fragments/$to"
  materialize_index_in "$cauldron_root" "to/$to/$kind" "$from" "fragments/$from"
}

set_index_record() {
  root=$1
  index_path=$2
  entry=$3
  target=$4
  temporary="$root/.indexes.tsv.tmp.$$"

  awk -F '\t' -v index_path="$index_path" -v entry="$entry" '
    !($1 == index_path && $2 == entry) { print }
  ' "$root/indexes.tsv" > "$temporary"
  printf '%s\t%s\t%s\n' "$index_path" "$entry" "$target" >> "$temporary"
  mv "$temporary" "$root/indexes.tsv"
}

add_link() {
  root=$1
  from=$2
  kind=$3
  to=$4
  require_state "$root"
  safe_component "$from" || fail "FROM must be one safe fragment id: $from"
  safe_component "$kind" || fail "KIND must be one safe link name: $kind"
  safe_component "$to" || fail "TO must be one safe fragment id: $to"
  append_unique "$root/links.tsv" "$(printf '%s\t%s\t%s' "$from" "$kind" "$to")"
  materialize_link_in "$root/cauldron" "$from" "$kind" "$to"
}

add_index() {
  root=$1
  index_path=$2
  entry=$3
  target=$4
  require_state "$root"
  safe_field "$index_path" && safe_field "$entry" && safe_field "$target" || fail "index fields may not contain tabs or newlines"
  safe_relative_path "$index_path" || fail "unsafe index path: $index_path"
  safe_component "$entry" || fail "index entry must be one safe filename: $entry"
  safe_relative_path "$target" || fail "unsafe target path: $target"
  set_index_record "$root" "$index_path" "$entry" "$target"
  materialize_index_in "$root/cauldron" "$index_path" "$entry" "$target"
}

rebuild() {
  root=$1
  require_state "$root"
  rm -rf "$root/cauldron.new"
  mkdir -p "$root/cauldron.new"

  if [ -s "$root/links.tsv" ]; then
    while IFS="$tab" read -r from kind to; do
      [ -n "$from" ] || continue
      materialize_link_in "$root/cauldron.new" "$from" "$kind" "$to"
    done < "$root/links.tsv"
  fi

  if [ -s "$root/indexes.tsv" ]; then
    while IFS="$tab" read -r index_path entry target; do
      [ -n "$index_path" ] || continue
      materialize_index_in "$root/cauldron.new" "$index_path" "$entry" "$target"
    done < "$root/indexes.tsv"
  fi

  rm -rf "$root/cauldron.old"
  if [ -e "$root/cauldron" ]; then
    mv "$root/cauldron" "$root/cauldron.old"
  fi
  mv "$root/cauldron.new" "$root/cauldron"
  rm -rf "$root/cauldron.old"
}

query_from() {
  root=$1
  fragment=$2
  kind=${3-}
  require_state "$root"
  awk -F '\t' -v source="$fragment" -v kind="$kind" '
    $1 == source && (kind == "" || $2 == kind) { print $2 "\t" $3 }
  ' "$root/links.tsv"
}

query_to() {
  root=$1
  fragment=$2
  kind=${3-}
  require_state "$root"
  awk -F '\t' -v destination="$fragment" -v kind="$kind" '
    $3 == destination && (kind == "" || $2 == kind) { print $1 "\t" $2 }
  ' "$root/links.tsv"
}

make_strand() {
  root=$1
  start=$2
  kind=$3
  require_state "$root"

  # Read the table once. Following the strand happens in awk memory rather
  # than one filesystem lookup per hop. The caller may persist this sequence
  # under pensive/strands/.
  awk -F '\t' -v start="$start" -v wanted="$kind" '
    $2 == wanted {
      if ($1 in next_fragment && next_fragment[$1] != $3) {
        ambiguous[$1] = 1
      }
      next_fragment[$1] = $3
    }
    END {
      current = start
      while (current != "") {
        if (seen[current]++) {
          print "cycle at " current > "/dev/stderr"
          exit 2
        }
        print current
        if (ambiguous[current]) {
          print "ambiguous " wanted " edge from " current > "/dev/stderr"
          exit 3
        }
        current = next_fragment[current]
      }
    }
  ' "$root/links.tsv"
}

[ "$#" -gt 0 ] || usage
command=$1
shift

case "$command" in
  init)
    [ "$#" -eq 1 ] || usage
    initialize "$1"
    ;;
  link)
    [ "$#" -eq 4 ] || usage
    add_link "$1" "$2" "$3" "$4"
    ;;
  index)
    [ "$#" -eq 4 ] || usage
    add_index "$1" "$2" "$3" "$4"
    ;;
  rebuild)
    [ "$#" -eq 1 ] || usage
    rebuild "$1"
    ;;
  from)
    [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || usage
    query_from "$@"
    ;;
  to)
    [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || usage
    query_to "$@"
    ;;
  strand)
    [ "$#" -eq 3 ] || usage
    make_strand "$1" "$2" "$3"
    ;;
  *) usage ;;
esac
