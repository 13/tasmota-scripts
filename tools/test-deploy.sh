#!/usr/bin/env bash
# Offline tests for deploy.sh and tools/rollback.sh: builds a scratch copy
# of the repo, replaces curl / mosquitto_pub / mosquitto_sub /
# berry-inventory.sh with fakes, and asserts the documented behaviour of
# --autoexec-only, backup-first, retained-status verification, --no-verify
# and rollback. Never touches a real device or broker.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
FAILED=0

# Fakes shell out through PATH-resolved bash; the sandbox's BASH_ENV prints
# an escape sequence on shell start, so make sure it's cleared for every
# fake and every invocation of deploy.sh/rollback.sh below.
unset BASH_ENV

fail() {
  echo "FAIL: $1" >&2
  FAILED=1
}

assert_contains() {
  local haystack=$1 needle=$2 msg=$3
  if [[ $haystack != *"$needle"* ]]; then
    fail "$msg (expected to find: $needle)"
    echo "--- output ---" >&2
    echo "$haystack" >&2
    echo "--------------" >&2
  fi
}

assert_not_contains() {
  local haystack=$1 needle=$2 msg=$3
  if [[ $haystack == *"$needle"* ]]; then
    fail "$msg (did not expect to find: $needle)"
  fi
}

# new_scratch: fresh scratch copy of the repo + fakes on PATH, echoes its dir.
new_scratch() {
  local dir
  dir=$(mktemp -d)
  cp -r "$REPO/deploy.sh" "$REPO/tools" "$REPO/MUH" "$REPO/devices.tsv" "$dir/"
  mkdir -p "$dir/bin" "$dir/state" "$dir/state/store"

  cat >"$dir/bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
unset BASH_ENV
log="$FAKE_STATE/curl-calls.log"
echo "$*" >>"$log"
store="$FAKE_STATE/store"
mkdir -p "$store"

url="" upload_src="" prev=""
for a in "$@"; do
  if [[ $prev == -F && $a == ufsu=@* ]]; then upload_src=${a#ufsu=@}; fi
  case $a in http://*) url=$a ;; esac
  prev=$a
done

case $url in
  */ufsd)
    exit 0
    ;;
  */ufsu*)
    [[ -n $upload_src ]] && cp "$upload_src" "$store/$(basename "$upload_src")"
    exit 0
    ;;
  */ufsd\?download=*)
    fname=${url#*download=/}
    fname=${fname%%&*}
    if [[ -f "$store/$fname" ]]; then
      cat "$store/$fname"
      exit 0
    fi
    exit 22
    ;;
  */ufsd\?dir=*)
    for f in "$store"/*; do
      [[ -e $f ]] || continue
      echo "<a file='$(basename "$f")'>$(basename "$f")</a>"
    done
    exit 0
    ;;
  */ufsd\?delete=*)
    fname=${url#*delete=/}
    fname=${fname%%&*}
    rm -f "$store/$fname"
    exit 0
    ;;
  */cm\?cmnd=Restart*)
    echo RESTART >>"$FAKE_STATE/order.log"
    echo '{"Restart":"OK"}'
    exit 0
    ;;
  *)
    echo "fake curl: unhandled url [$url] args: $*" >&2
    exit 1
    ;;
esac
FAKE_CURL

  cat >"$dir/bin/mosquitto_pub" <<'FAKE_PUB'
#!/usr/bin/env bash
unset BASH_ENV
echo "$*" >>"$FAKE_STATE/mosquitto_pub.log"
echo PUB >>"$FAKE_STATE/order.log"
exit 0
FAKE_PUB

  cat >"$dir/bin/mosquitto_sub" <<'FAKE_SUB'
#!/usr/bin/env bash
unset BASH_ENV
echo "$*" >>"$FAKE_STATE/mosquitto_sub.log"
queue="$FAKE_STATE/sub_queue"
if [[ -s $queue ]]; then
  line=$(head -1 "$queue")
  tail -n +2 "$queue" >"$queue.tmp" && mv "$queue.tmp" "$queue"
  [[ -n $line ]] && echo "$line"
fi
exit 0
FAKE_SUB

  cat >"$dir/tools/berry-inventory.sh" <<'FAKE_INV'
#!/usr/bin/env bash
unset BASH_ENV
echo "$*" >>"$FAKE_STATE/berry-inventory.log"
name=$1
if [[ ${FAKE_BACKUP_FAIL:-} == "$name" ]]; then
  echo "simulated backup failure for $name" >&2
  exit 1
fi
ts=${FAKE_BACKUP_TS:-20260101-000000}
mkdir -p "backups/$name/$ts"
: >"backups/$name/$ts/autoexec.be"
echo "backup: $name -> backups/$name/$ts" >&2
exit 0
FAKE_INV

  chmod +x "$dir/bin/curl" "$dir/bin/mosquitto_pub" "$dir/bin/mosquitto_sub" "$dir/tools/berry-inventory.sh"
  echo "$dir"
}

# run_deploy <scratch> <extra-env-assignments...> -- <deploy.sh args...>
run_deploy() {
  local scratch=$1
  shift
  (
    cd "$scratch"
    export PATH="$scratch/bin:$PATH"
    export FAKE_STATE="$scratch/state"
    export MQTT_HOST=127.0.0.1
    export DEPLOY_VERIFY_TIMEOUT=${DEPLOY_VERIFY_TIMEOUT:-6}
    export BASH_ENV=
    ./deploy.sh "$@"
  )
}

run_rollback() {
  local scratch=$1
  shift
  (
    cd "$scratch"
    export PATH="$scratch/bin:$PATH"
    export FAKE_STATE="$scratch/state"
    export BASH_ENV=
    tools/rollback.sh "$@"
  )
}

VERSION=$(grep -oE 'AUTOEXEC_VERSION[[:space:]]*=[[:space:]]*"[^"]+"' "$REPO/MUH/autoexec.be" | sed -E 's/.*"([^"]+)"/\1/')

# --- (a) --autoexec-only uploads exactly autoexec.be + muh_lib.be, clears
#     retained status before restart, succeeds on a matching ok status.
echo "=== (a) --autoexec-only success ==="
s=$(new_scratch)
echo "{\"ok\":true,\"autoexec\":\"$VERSION\",\"script\":\"fl3.be\"}" >"$s/state/sub_queue"
out=$(run_deploy "$s" --autoexec-only FL3); rc=$?
assert_contains "$out" "LOAD ok (fl3.be)" "(a) expected LOAD ok"
[[ $rc -eq 0 ]] || fail "(a) expected exit 0, got $rc"
calls=$(cat "$s/state/curl-calls.log")
up_count=$(grep -c 'ufsu=@MUH/' "$s/state/curl-calls.log" || true)
[[ $up_count -eq 2 ]] || fail "(a) expected 2 uploads, got $up_count"
assert_contains "$calls" "ufsu=@MUH/autoexec.be" "(a) expected autoexec.be uploaded"
assert_contains "$calls" "ufsu=@MUH/muh_lib.be" "(a) expected muh_lib.be uploaded"
assert_not_contains "$calls" "ufsu=@MUH/fl3.be" "(a) fl3.be must not be uploaded with --autoexec-only"
pub_log=$(cat "$s/state/mosquitto_pub.log")
assert_contains "$pub_log" "muh/berry/FL3/status" "(a) expected retained status cleared for FL3"
assert_contains "$pub_log" "-r -n" "(a) expected -r -n clear"
order=$(cat "$s/state/order.log")
[[ "$order" == "PUB
RESTART" ]] || fail "(a) expected retained status cleared before restart, got: $order"

# --- (b) ok:false with err -> LOAD FAILED + rollback hint, exit 1
echo "=== (b) LOAD FAILED ==="
s=$(new_scratch)
echo '{"ok":false,"err":"x.be: boom"}' >"$s/state/sub_queue"
out=$(run_deploy "$s" --autoexec-only FL3); rc=$?
[[ $rc -eq 1 ]] || fail "(b) expected exit 1, got $rc"
assert_contains "$out" "LOAD FAILED: x.be: boom" "(b) expected LOAD FAILED message"
assert_contains "$out" "rollback: tools/rollback.sh FL3 20260101-000000" "(b) expected rollback hint"

# --- (c) mismatched version then correct version -> waits and succeeds
echo "=== (c) waits for matching version ==="
s=$(new_scratch)
printf '{"ok":true,"autoexec":"old-version","script":"fl3.be"}\n{"ok":true,"autoexec":"%s","script":"fl3.be"}\n' "$VERSION" >"$s/state/sub_queue"
out=$(DEPLOY_VERIFY_TIMEOUT=30 run_deploy "$s" --autoexec-only FL3); rc=$?
[[ $rc -eq 0 ]] || fail "(c) expected exit 0, got $rc"
assert_contains "$out" "LOAD ok (fl3.be)" "(c) expected eventual LOAD ok"
sub_calls=$(grep -c 'muh/berry/FL3/status' "$s/state/mosquitto_sub.log" || true)
[[ $sub_calls -ge 2 ]] || fail "(c) expected at least 2 poll attempts, got $sub_calls"

# --- (d) no status ever -> timeout, exit 1 (fast via DEPLOY_VERIFY_TIMEOUT)
echo "=== (d) timeout ==="
s=$(new_scratch)
: >"$s/state/sub_queue"
out=$(DEPLOY_VERIFY_TIMEOUT=5 run_deploy "$s" --autoexec-only FL3); rc=$?
[[ $rc -eq 1 ]] || fail "(d) expected exit 1, got $rc"
assert_contains "$out" "LOAD status not received within 5s" "(d) expected timeout message"
assert_contains "$out" "rollback: tools/rollback.sh FL3" "(d) expected rollback hint on timeout"

# --- (e) backup failure -> device skipped, nothing uploaded, exit 1
echo "=== (e) backup failure ==="
s=$(new_scratch)
out=$(FAKE_BACKUP_FAIL=FL3 run_deploy "$s" --autoexec-only FL3); rc=$?
[[ $rc -eq 1 ]] || fail "(e) expected exit 1, got $rc"
assert_contains "$out" "BACKUP FAILED" "(e) expected backup failure message"
if [[ -f "$s/state/curl-calls.log" ]]; then
  fail "(e) expected no curl calls after backup failure, found $(wc -l <"$s/state/curl-calls.log") lines"
fi

# --- (f) rollback restores backup files, deletes files not in backup, restarts
echo "=== (f) rollback ==="
s=$(new_scratch)
mkdir -p "$s/backups/FL3/20260101-000000"
echo "autoexec-backup-content" >"$s/backups/FL3/20260101-000000/autoexec.be"
echo "muh_lib-backup-content" >"$s/backups/FL3/20260101-000000/muh_lib.be"
# Simulate the device's current state: same two files plus an extra script
# that is not part of the backup and must be deleted.
cp "$s/backups/FL3/20260101-000000/autoexec.be" "$s/state/store/autoexec.be"
cp "$s/backups/FL3/20260101-000000/muh_lib.be" "$s/state/store/muh_lib.be"
echo "stray" >"$s/state/store/fl3.be"
out=$(run_rollback "$s" FL3 20260101-000000); rc=$?
[[ $rc -eq 0 ]] || fail "(f) expected exit 0, got $rc"
assert_contains "$out" "restored: autoexec.be muh_lib.be" "(f) expected restored file list"
assert_contains "$out" "deleted: fl3.be" "(f) expected fl3.be deleted"
[[ -f "$s/state/store/fl3.be" ]] && fail "(f) fl3.be should have been removed from the device store"
grep -q RESTART "$s/state/order.log" || fail "(f) expected a restart"

# --- (g) --no-verify never calls mosquitto
echo "=== (g) --no-verify skips mosquitto ==="
s=$(new_scratch)
out=$(run_deploy "$s" --no-verify --autoexec-only FL3); rc=$?
[[ $rc -eq 0 ]] || fail "(g) expected exit 0, got $rc"
if [[ -f "$s/state/mosquitto_pub.log" || -f "$s/state/mosquitto_sub.log" ]]; then
  fail "(g) --no-verify must never call mosquitto_pub/mosquitto_sub"
fi

if [[ $FAILED -eq 0 ]]; then
  echo "test-deploy.sh: all tests passed"
else
  echo "test-deploy.sh: FAILURES ABOVE" >&2
fi
exit $FAILED
