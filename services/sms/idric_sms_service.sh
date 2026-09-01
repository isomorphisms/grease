#!/bin/sh

set -eu

program_name=${0##*/}

die() {
  printf '%s: %s\n' "$program_name" "$1" >&2
  exit 1
}

usage() {
  die "usage: $program_name init STATE | inbound STATE FROM RECEIVED_AT INBOUND_ID BODY | run_due STATE NOW"
}

write_file() {
  write_destination=$1
  write_value=$2
  write_temporary="${write_destination}.tmp.$$"
  umask 077
  printf '%s\n' "$write_value" > "$write_temporary"
  mv "$write_temporary" "$write_destination"
}

safe_id() {
  case "$1" in
    ''|*[!A-Za-z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_phone() {
  case "$1" in
    +*) digits=${1#+} ;;
    *) return 1 ;;
  esac
  case "$digits" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_instant() {
  case "$1" in
    ????-??-??T??:??:??Z) ;;
    *) return 1 ;;
  esac
  date -u -d "$1" '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1
}

initialize_state() {
  state=$1
  umask 077
  mkdir -p \
    "$state/addresses" \
    "$state/principals" \
    "$state/inbound" \
    "$state/consent" \
    "$state/scheduled" \
    "$state/sent" \
    "$state/cancelled" \
    "$state/fake_outbox" \
    "$state/opt_out" \
    "$state/counters" \
    "$state/locks"
  if [ ! -f "$state/counters/next_principal" ]; then
    write_file "$state/counters/next_principal" 1
  fi
}

acquire_principal_lock() {
  state=$1
  attempt=0
  while ! mkdir "$state/locks/principal" 2>/dev/null; do
    attempt=$((attempt + 1))
    [ "$attempt" -lt 50 ] || die "principal allocator remained locked"
    sleep 0.1
  done
}

resolve_principal() {
  state=$1
  phone=$2
  address_record="$state/addresses/$phone"
  if [ -f "$address_record" ]; then
    principal=$(sed -n '1p' "$address_record")
    safe_id "$principal" || die "invalid principal mapping for $phone"
    printf '%s\n' "$principal"
    return
  fi

  acquire_principal_lock "$state"
  if [ -f "$address_record" ]; then
    principal=$(sed -n '1p' "$address_record")
    rmdir "$state/locks/principal"
    printf '%s\n' "$principal"
    return
  fi

  next=$(sed -n '1p' "$state/counters/next_principal")
  case "$next" in
    ''|*[!0-9]*)
      rmdir "$state/locks/principal"
      die "invalid next principal counter"
      ;;
  esac
  principal=$(printf '%06d' "$next")
  principal_dir="$state/principals/$principal"
  mkdir -p "$principal_dir/addresses" "$principal_dir/consent" "$principal_dir/stop"
  write_file "$principal_dir/kind" public_correspondent
  write_file "$principal_dir/addresses/phone" "$phone"
  write_file "$address_record" "$principal"
  write_file "$state/counters/next_principal" $((next + 1))
  rmdir "$state/locks/principal"
  printf '%s\n' "$principal"
}

record_inbound() {
  state=$1
  phone=$2
  received_at=$3
  inbound_id=$4
  body=$5
  principal=$6
  final="$state/inbound/$inbound_id"
  [ ! -e "$final" ] || die "inbound id already exists: $inbound_id"
  temporary="$state/inbound/.${inbound_id}.tmp.$$"
  mkdir "$temporary"
  write_file "$temporary/from" "$phone"
  write_file "$temporary/received_at" "$received_at"
  write_file "$temporary/body" "$body"
  write_file "$temporary/principal" "$principal"
  mv "$temporary" "$final"
}

record_authorization() {
  state=$1
  event_id=$2
  principal=$3
  phone=$4
  requested_at=$5
  inbound_id=$6
  original_request=$7
  scheduled_for=$8
  message=$9
  final="$state/consent/$event_id"
  [ ! -e "$final" ] || die "authorization already exists: $event_id"
  temporary="$state/consent/.${event_id}.tmp.$$"
  mkdir "$temporary"
  write_file "$temporary/principal" "$principal"
  write_file "$temporary/destination" "$phone"
  write_file "$temporary/requested_at" "$requested_at"
  write_file "$temporary/inbound_id" "$inbound_id"
  write_file "$temporary/original_request" "$original_request"
  write_file "$temporary/scheduled_for" "$scheduled_for"
  write_file "$temporary/message" "$message"
  mv "$temporary" "$final"
  : > "$state/principals/$principal/consent/$event_id"
}

make_event() {
  destination=$1
  event_id=$2
  principal=$3
  phone=$4
  message=$5
  authorization=$6
  scheduled_for=$7
  temporary="${destination}/.${event_id}.tmp.$$"
  final="$destination/$event_id"
  [ ! -e "$final" ] || die "event already exists: $event_id"
  mkdir "$temporary"
  write_file "$temporary/principal" "$principal"
  write_file "$temporary/destination" "$phone"
  write_file "$temporary/message" "$message"
  write_file "$temporary/authorization" "$authorization"
  write_file "$temporary/scheduled_for" "$scheduled_for"
  mv "$temporary" "$final"
}

derive_due() {
  received_at=$1
  clock=$2
  received_epoch=$(date -u -d "$received_at" '+%s') || die "invalid received time: $received_at"
  received_date=${received_at%%T*}
  candidate="${received_date}T${clock}:00Z"
  candidate_epoch=$(date -u -d "$candidate" '+%s') || die "invalid reminder time: $clock"
  if [ "$candidate_epoch" -le "$received_epoch" ]; then
    next_date=$(date -u -d "$received_date + 1 day" '+%Y-%m-%d') || die "could not advance reminder date"
    candidate="${next_date}T${clock}:00Z"
  fi
  printf '%s\n' "$candidate"
}

fake_deliver() {
  state=$1
  event_dir=$2
  sent_at=$3
  event_id=${event_dir##*/}
  receipt="fake_$event_id"
  outbox="$state/fake_outbox/$receipt"
  [ ! -e "$outbox" ] || die "fake receipt already exists: $receipt"
  mkdir "$outbox"
  write_file "$outbox/event_id" "$event_id"
  write_file "$outbox/to" "$(sed -n '1p' "$event_dir/destination")"
  write_file "$outbox/body" "$(sed -n '1p' "$event_dir/message")"
  write_file "$outbox/sent_at" "$sent_at"
  write_file "$event_dir/transport" fake
  write_file "$event_dir/transport_receipt" "$receipt"
  write_file "$event_dir/sent_at" "$sent_at"
  mv "$event_dir" "$state/sent/$event_id"
}

cancel_event() {
  state=$1
  principal=$2
  event_id=$3
  cancelled_at=$4
  cancellation_inbound=$5
  reason=$6
  found=
  for candidate in "$state"/scheduled/*/"$event_id"; do
    [ -d "$candidate" ] || continue
    event_principal=$(sed -n '1p' "$candidate/principal")
    [ "$event_principal" = "$principal" ] || die "event is not owned by this principal: $event_id"
    write_file "$candidate/cancelled_at" "$cancelled_at"
    write_file "$candidate/cancellation_inbound_id" "$cancellation_inbound"
    write_file "$candidate/cancellation_reason" "$reason"
    mv "$candidate" "$state/cancelled/$event_id"
    due_dir=${candidate%/*}
    rmdir "$due_dir" 2>/dev/null || true
    found=yes
    break
  done
  [ -n "$found" ] || die "scheduled event not found: $event_id"
}

handle_echo() {
  state=$1
  principal=$2
  phone=$3
  received_at=$4
  inbound_id=$5
  original=$6
  message=$7
  [ ! -e "$state/opt_out/$principal" ] || die "principal has opted out"
  event_id="echo_$inbound_id"
  record_authorization "$state" "$event_id" "$principal" "$phone" "$received_at" "$inbound_id" "$original" immediate "$message"
  make_event "$state/scheduled" "$event_id" "$principal" "$phone" "$message" "consent/$event_id" immediate
  fake_deliver "$state" "$state/scheduled/$event_id" "$received_at"
  printf 'echoed %s\n' "$event_id"
}

handle_remind() {
  state=$1
  principal=$2
  phone=$3
  received_at=$4
  inbound_id=$5
  original=$6
  clock=$7
  [ ! -e "$state/opt_out/$principal" ] || die "principal has opted out"
  event_id="evt_$inbound_id"
  due=$(derive_due "$received_at" "$clock")
  due_dir="$state/scheduled/$due"
  mkdir -p "$due_dir"
  record_authorization "$state" "$event_id" "$principal" "$phone" "$received_at" "$inbound_id" "$original" "$due" hey
  make_event "$due_dir" "$event_id" "$principal" "$phone" hey "consent/$event_id" "$due"
  printf 'scheduled %s %s\n' "$event_id" "$due"
}

handle_stop() {
  state=$1
  principal=$2
  received_at=$3
  inbound_id=$4
  : > "$state/opt_out/$principal"
  stop_dir="$state/principals/$principal/stop/$inbound_id"
  mkdir "$stop_dir"
  write_file "$stop_dir/requested_at" "$received_at"
  cancelled=0
  for candidate in "$state"/scheduled/*/*; do
    [ -d "$candidate" ] || continue
    event_principal=$(sed -n '1p' "$candidate/principal")
    [ "$event_principal" = "$principal" ] || continue
    event_id=${candidate##*/}
    cancel_event "$state" "$principal" "$event_id" "$received_at" "$inbound_id" STOP
    cancelled=$((cancelled + 1))
  done
  printf 'stopped %s cancelled=%s\n' "$principal" "$cancelled"
}

handle_inbound() {
  [ "$#" -eq 5 ] || usage
  state=$1
  phone=$2
  received_at=$3
  inbound_id=$4
  body=$5
  valid_phone "$phone" || die "telephone address must be '+' followed by digits"
  valid_instant "$received_at" || die "received time must be UTC YYYY-MM-DDTHH:MM:SSZ"
  safe_id "$inbound_id" || die "inbound id may contain only letters, digits, '-' or '_'"
  initialize_state "$state"
  principal=$(resolve_principal "$state" "$phone")
  record_inbound "$state" "$phone" "$received_at" "$inbound_id" "$body" "$principal"

  parser=${IDRIC_SMS_REQUEST:-idric-sms-request}
  if ! normalized=$($parser "$body"); then
    printf '%s\n' "$normalized" >&2
    exit 1
  fi

  case "$normalized" in
    'ECHO '*)
      message=${normalized#ECHO }
      handle_echo "$state" "$principal" "$phone" "$received_at" "$inbound_id" "$body" "$message"
      ;;
    'REMIND '*)
      clock=${normalized#REMIND }
      handle_remind "$state" "$principal" "$phone" "$received_at" "$inbound_id" "$body" "$clock"
      ;;
    'CANCEL '*)
      event_id=${normalized#CANCEL }
      cancel_event "$state" "$principal" "$event_id" "$received_at" "$inbound_id" CANCEL
      printf 'cancelled %s\n' "$event_id"
      ;;
    STOP)
      handle_stop "$state" "$principal" "$received_at" "$inbound_id"
      ;;
    *) die "Idriç parser returned an unknown request" ;;
  esac
}

run_due() {
  [ "$#" -eq 2 ] || usage
  state=$1
  now=$2
  valid_instant "$now" || die "run time must be UTC YYYY-MM-DDTHH:MM:SSZ"
  initialize_state "$state"
  for event_dir in "$state"/scheduled/*/*; do
    [ -d "$event_dir" ] || continue
    due_dir=${event_dir%/*}
    due=${due_dir##*/}
    [ "$due" \> "$now" ] || {
      event_id=${event_dir##*/}
      principal=$(sed -n '1p' "$event_dir/principal")
      if [ -e "$state/opt_out/$principal" ]; then
        cancel_event "$state" "$principal" "$event_id" "$now" scheduler STOP
        printf 'cancelled %s opted_out\n' "$event_id"
      else
        fake_deliver "$state" "$event_dir" "$now"
        rmdir "$due_dir" 2>/dev/null || true
        printf 'sent %s\n' "$event_id"
      fi
    }
  done
}

[ "$#" -ge 1 ] || usage
command=$1
shift

case "$command" in
  init)
    [ "$#" -eq 1 ] || usage
    initialize_state "$1"
    ;;
  inbound) handle_inbound "$@" ;;
  run_due) run_due "$@" ;;
  *) usage ;;
esac
