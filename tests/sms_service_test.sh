#!/bin/sh

set -eu

service=${SMS_SERVICE:-./services/sms/idric_sms_service.sh}
parser=${IDRIC_SMS_REQUEST:-idric-sms-request}
test_root=$(mktemp -d)
state="$test_root/state"

cleanup() {
  case "$test_root" in
    /tmp/*) rm -rf -- "$test_root" ;;
  esac
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing $1"
}

assert_value() {
  actual=$(sed -n '1p' "$1")
  [ "$actual" = "$2" ] || fail "$1: expected '$2', got '$actual'"
}

run_service() {
  IDRIC_SMS_REQUEST="$parser" "$service" "$@"
}

run_service init "$state"

imani=$(run_service inbound "$state" +15550000001 2026-09-01T14:00:00Z in_imani 'REMIND 15:00')
[ "$imani" = 'scheduled evt_in_imani 2026-09-01T15:00:00Z' ] || fail "Imani schedule receipt"
assert_value "$state/consent/evt_in_imani/inbound_id" in_imani
assert_value "$state/consent/evt_in_imani/destination" +15550000001
assert_value "$state/consent/evt_in_imani/original_request" 'REMIND 15:00'
assert_value "$state/scheduled/2026-09-01T15:00:00Z/evt_in_imani/message" hey

run_service run_due "$state" 2026-09-01T14:59:59Z >/dev/null
[ ! -e "$state/fake_outbox/fake_evt_in_imani" ] || fail "Imani reminder fired early"

# This is a separate process invocation: scheduled state survived the restart.
sent=$(run_service run_due "$state" 2026-09-01T15:00:00Z)
[ "$sent" = 'sent evt_in_imani' ] || fail "Imani send receipt"
assert_value "$state/fake_outbox/fake_evt_in_imani/body" hey
assert_value "$state/fake_outbox/fake_evt_in_imani/to" +15550000001
assert_file "$state/sent/evt_in_imani/transport_receipt"
[ ! -e "$state/scheduled/2026-09-01T15:00:00Z/evt_in_imani" ] || fail "sent event remained scheduled"
printf 'ok   durable REMIND sends hey with consent provenance\n'

felicity=$(run_service inbound "$state" +15550000002 2026-09-01T14:10:00Z in_felicity 'ECHO hey')
[ "$felicity" = 'echoed echo_in_felicity' ] || fail "Felicity echo receipt"
assert_value "$state/fake_outbox/fake_echo_in_felicity/body" hey
assert_value "$state/sent/echo_in_felicity/authorization" consent/echo_in_felicity
printf 'ok   ECHO crosses inbound and fake outbound boundaries\n'

run_service inbound "$state" +15550000003 2026-09-01T14:00:00Z in_hasan 'REMIND 15:00' >/dev/null
cancelled=$(run_service inbound "$state" +15550000003 2026-09-01T14:05:00Z in_hasan_cancel 'CANCEL evt_in_hasan')
[ "$cancelled" = 'cancelled evt_in_hasan' ] || fail "Hasan cancellation receipt"
assert_file "$state/cancelled/evt_in_hasan/cancelled_at"
run_service run_due "$state" 2026-09-01T15:00:00Z >/dev/null
[ ! -e "$state/fake_outbox/fake_evt_in_hasan" ] || fail "cancelled Hasan reminder was sent"
printf 'ok   CANCEL moves scheduled state and prevents delivery\n'

run_service inbound "$state" +15550000004 2026-09-01T14:00:00Z in_armani 'REMIND 16:00' >/dev/null
stopped=$(run_service inbound "$state" +15550000004 2026-09-01T14:01:00Z in_armani_stop STOP)
case "$stopped" in
  'stopped '*"cancelled=1") ;;
  *) fail "Armani STOP receipt" ;;
esac
assert_file "$state/opt_out/$(sed -n '1p' "$state/addresses/+15550000004")"
assert_file "$state/cancelled/evt_in_armani/cancellation_reason"
if run_service inbound "$state" +15550000004 2026-09-01T14:02:00Z in_armani_again 'REMIND 16:00' >/dev/null 2>&1; then
  fail "opted-out principal scheduled another message"
fi
printf 'ok   STOP is durable and cancels outstanding reminders\n'

run_service inbound "$state" +15550000005 2026-09-01T14:00:00Z in_gina 'REMIND 17:00' >/dev/null
run_service inbound "$state" +15550000006 2026-09-01T14:00:00Z in_moe 'REMIND 17:00' >/dev/null
assert_file "$state/scheduled/2026-09-01T17:00:00Z/evt_in_gina/message"
assert_file "$state/scheduled/2026-09-01T17:00:00Z/evt_in_moe/message"
run_service run_due "$state" 2026-09-01T17:00:00Z >/dev/null
assert_file "$state/fake_outbox/fake_evt_in_gina/body"
assert_file "$state/fake_outbox/fake_evt_in_moe/body"
printf 'ok   same-time reminders remain distinct across principals\n'

run_service inbound "$state" +15550000007 2026-09-01T14:00:00Z in_cash 'ECHO hey' >/dev/null
cash_principal=$(sed -n '1p' "$state/addresses/+15550000007")
assert_value "$state/principals/$cash_principal/kind" public_correspondent
printf 'ok   unknown caller becomes an unprivileged correspondent\n'

if run_service inbound "$state" +15550000008 2026-09-01T14:00:00Z in_paul 'remind me at 3' >/dev/null 2>&1; then
  fail "natural language bypassed deterministic parsing"
fi
assert_file "$state/inbound/in_paul/body"
printf 'ok   rejected natural language causes no scheduled effect\n'
