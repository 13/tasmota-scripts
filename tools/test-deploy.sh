#!/usr/bin/env bash
# Offline tests for deploy.sh and tools/rollback.sh: builds a scratch copy
# of the repo, replaces curl / mosquitto_pub / mosquitto_sub /
# berry-inventory.sh with fakes, and asserts the documented behaviour of
# --autoexec-only, backup-first, safe upload order, retained-status
# verification, --no-verify, name/case handling and rollback. Never touches
# a real device or broker. All scratch dirs are removed on exit.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
FAILED=0
SCRATCH_DIRS=()

# Fakes shell out through PATH-resolved bash; the sandbox's BASH_ENV prints
# an escape sequence on shell start, so make sure it's cleared for every
# fake and every invocation of deploy.sh/rollback.sh below.
unset BASH_ENV

cleanup() {
  local d
  for d in "${SCRATCH_DIRS[@]:-}"; do
    [[ -n $d && -d $d ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

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

assert_eq() {
  local got=$1 want=$2 msg=$3
  [[ $got == "$want" ]] || fail "$msg (got [$got], want [$want])"
}

# new_scratch: fresh scratch copy of the repo + fakes on PATH, echoes its dir.
new_scratch() {
  local dir
  dir=$(mktemp -d)
  SCRATCH_DIRS+=("$dir")
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
      echo "<a href='ufsd?download=/$(basename "$f")' file='$(basename "$f")'>$(basename "$f")</a>"
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
  */cm\?cmnd=DeviceName*)
    echo "{\"DeviceName\":\"${FAKE_DEVICENAME:-FL3}\"}"
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

  cat >"$dir/bin/timeout" <<'FAKE_TIMEOUT'
#!/usr/bin/env bash
# Real `timeout` may not exist everywhere the suite runs; a bare passthrough
# is enough since every fake mosquitto_sub above returns instantly anyway.
shift
exec "$@"
FAKE_TIMEOUT

  cat >"$dir/tools/berry-inventory.sh" <<'FAKE_INV'
#!/usr/bin/env bash
unset BASH_ENV
echo "$*" >>"$FAKE_STATE/berry-inventory.log"
name=$1
if [[ ${FAKE_BACKUP_FAIL:-} == "$name" ]]; then
  echo "simulated backup failure for $name" >&2
  exit 1
fi
# berry-inventory.sh backs a device up under the DeviceName it queries live,
# which can differ in case from the devices.tsv row name it was called
# with (FAKE_BACKUP_NAME lets a test simulate that).
dn=${FAKE_BACKUP_NAME:-$name}
ts=${FAKE_BACKUP_TS:-20260101-000000}
mkdir -p "backups/$dn/$ts"
if [[ ${FAKE_EMPTY:-} == 1 ]]; then
  : >"backups/$dn/$ts/.EMPTY"
else
  : >"backups/$dn/$ts/autoexec.be"
fi
echo "backup: $dn -> backups/$dn/$ts" >&2
exit 0
FAKE_INV

  chmod +x "$dir/bin/curl" "$dir/bin/mosquitto_pub" "$dir/bin/mosquitto_sub" "$dir/bin/timeout" "$dir/tools/berry-inventory.sh"
  echo "$dir"
}

# run_deploy <scratch> <deploy.sh args...>
run_deploy() {
  local scratch=$1
  shift
  (
    cd "$scratch"
    export PATH="$scratch/bin:$PATH"
    export FAKE_STATE="$scratch/state"
    export MQTT_HOST=127.0.0.1
    export DEPLOY_VERIFY_TIMEOUT=${DEPLOY_VERIFY_TIMEOUT:-4}
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
    export MQTT_HOST=127.0.0.1
    export DEPLOY_VERIFY_TIMEOUT=${DEPLOY_VERIFY_TIMEOUT:-4}
    export BASH_ENV=
    tools/rollback.sh "$@"
  )
}

VERSION=$(grep -oE 'AUTOEXEC_VERSION[[:space:]]*=[[:space:]]*"[^"]+"' "$REPO/MUH/autoexec.be" | sed -E 's/.*"([^"]+)"/\1/')

# --- (a) --autoexec-only uploads exactly muh_lib.be + autoexec.be (in that
#     order, autoexec.be LAST), clears retained status before any upload,
#     succeeds on a matching ok status.
echo "=== (a) --autoexec-only success, safe order ==="
s=$(new_scratch)
echo "{\"ok\":true,\"autoexec\":\"$VERSION\",\"script\":\"fl3.be\"}" >"$s/state/sub_queue"
out=$(run_deploy "$s" --autoexec-only FL3); rc=$?
assert_contains "$out" "LOAD ok (fl3.be)" "(a) expected LOAD ok"
assert_eq "$rc" 0 "(a) expected exit 0"
calls=$(cat "$s/state/curl-calls.log")
up_count=$(grep -c 'ufsu=@MUH/' "$s/state/curl-calls.log" || true)
assert_eq "$up_count" 2 "(a) expected 2 uploads"
assert_contains "$calls" "ufsu=@MUH/autoexec.be" "(a) expected autoexec.be uploaded"
assert_contains "$calls" "ufsu=@MUH/muh_lib.be" "(a) expected muh_lib.be uploaded"
assert_not_contains "$calls" "ufsu=@MUH/fl3.be" "(a) fl3.be must not be uploaded with --autoexec-only"
# muh_lib.be's *upload* line must precede autoexec.be's *upload* line.
lib_line=$(grep -n 'ufsu=@MUH/muh_lib.be' "$s/state/curl-calls.log" | head -1 | cut -d: -f1)
auto_line=$(grep -n 'ufsu=@MUH/autoexec.be' "$s/state/curl-calls.log" | head -1 | cut -d: -f1)
[[ $lib_line -lt $auto_line ]] || fail "(a) muh_lib.be must upload before autoexec.be (lib@$lib_line auto@$auto_line)"
pub_log=$(cat "$s/state/mosquitto_pub.log")
assert_contains "$pub_log" "muh/berry/FL3/status" "(a) expected retained status cleared for FL3"
assert_contains "$pub_log" "-r -n" "(a) expected -r -n clear"
order=$(cat "$s/state/order.log")
assert_eq "$order" "$(printf 'PUB\nRESTART')" "(a) expected retained status cleared before restart"

# --- (b) ok:false with err -> LOAD FAILED + rollback hint, exit 1
echo "=== (b) LOAD FAILED ==="
s=$(new_scratch)
echo '{"ok":false,"err":"x.be: boom"}' >"$s/state/sub_queue"
out=$(run_deploy "$s" --autoexec-only FL3); rc=$?
assert_eq "$rc" 1 "(b) expected exit 1"
assert_contains "$out" "LOAD FAILED: x.be: boom" "(b) expected LOAD FAILED message"
assert_contains "$out" "rollback: tools/rollback.sh FL3 20260101-000000" "(b) expected rollback hint"

# --- (c) mismatched version then correct version -> waits and succeeds
echo "=== (c) waits for matching version ==="
s=$(new_scratch)
printf '{"ok":true,"autoexec":"old-version","script":"fl3.be"}\n{"ok":true,"autoexec":"%s","script":"fl3.be"}\n' "$VERSION" >"$s/state/sub_queue"
out=$(DEPLOY_VERIFY_TIMEOUT=20 run_deploy "$s" --autoexec-only FL3); rc=$?
assert_eq "$rc" 0 "(c) expected exit 0"
assert_contains "$out" "LOAD ok (fl3.be)" "(c) expected eventual LOAD ok"
sub_calls=$(grep -c 'muh/berry/FL3/status' "$s/state/mosquitto_sub.log" || true)
[[ $sub_calls -ge 2 ]] || fail "(c) expected at least 2 poll attempts, got $sub_calls"

# --- (d) no status ever -> timeout, exit 1, last-seen version reported
echo "=== (d) timeout ==="
s=$(new_scratch)
printf '{"ok":true,"autoexec":"old-version","script":"fl3.be"}\n' >"$s/state/sub_queue"
out=$(DEPLOY_VERIFY_TIMEOUT=3 run_deploy "$s" --autoexec-only FL3); rc=$?
assert_eq "$rc" 1 "(d) expected exit 1"
assert_contains "$out" "LOAD status not received within 3s" "(d) expected timeout message"
assert_contains "$out" "last seen: ok=True autoexec=old-version" "(d) expected last-seen status in timeout message"
assert_contains "$out" "rollback: tools/rollback.sh FL3" "(d) expected rollback hint on timeout"

# --- (e) backup failure -> device skipped, nothing uploaded, exit 1
echo "=== (e) backup failure ==="
s=$(new_scratch)
out=$(FAKE_BACKUP_FAIL=FL3 run_deploy "$s" --autoexec-only FL3); rc=$?
assert_eq "$rc" 1 "(e) expected exit 1"
assert_contains "$out" "BACKUP FAILED" "(e) expected backup failure message"
if [[ -f "$s/state/curl-calls.log" ]]; then
  fail "(e) expected no curl calls after backup failure, found $(wc -l <"$s/state/curl-calls.log") lines"
fi

# --- (f) rollback restores backup files, deletes files not in backup
#     (including verifying non-.be files are left alone), restarts, then
#     clears+waits for a fresh status like deploy does.
echo "=== (f) rollback ==="
s=$(new_scratch)
mkdir -p "$s/backups/FL3/t1"
echo a >"$s/backups/FL3/t1/autoexec.be"
echo x >"$s/backups/FL3/t1/muh_lib.be"
echo a >"$s/state/store/autoexec.be"
echo x >"$s/state/store/muh_lib.be"
echo s >"$s/state/store/fl3.be"          # stray .be, not in backup -> delete
echo p >"$s/state/store/_persist.json"   # not .be -> keep
echo c >"$s/state/store/.settings"       # not .be -> keep
echo z >"$s/state/store/autoexec.bec"    # not exactly .be -> keep
echo "{\"ok\":true,\"autoexec\":\"old\",\"script\":\"\"}" >"$s/state/sub_queue"
out=$(DEPLOY_VERIFY_TIMEOUT=10 run_rollback "$s" FL3 t1); rc=$?
assert_eq "$rc" 0 "(f) expected exit 0"
assert_contains "$out" "restored: autoexec.be muh_lib.be" "(f) expected restored file list"
assert_contains "$out" "deleted: fl3.be" "(f) expected fl3.be deleted"
[[ -f "$s/state/store/fl3.be" ]] && fail "(f) fl3.be should have been removed from the device store"
[[ -f "$s/state/store/_persist.json" ]] || fail "(f) _persist.json must survive rollback delete pass"
[[ -f "$s/state/store/autoexec.bec" ]] || fail "(f) autoexec.bec (not exactly .be) must survive rollback delete pass"
grep -q RESTART "$s/state/order.log" || fail "(f) expected a restart"
assert_contains "$out" "LOAD ok" "(f) expected rollback to also wait for a fresh status"

# --- (g) --no-verify never calls mosquitto (deploy and rollback)
echo "=== (g) --no-verify skips mosquitto ==="
s=$(new_scratch)
out=$(run_deploy "$s" --no-verify --autoexec-only FL3); rc=$?
assert_eq "$rc" 0 "(g) expected exit 0"
if [[ -f "$s/state/mosquitto_pub.log" || -f "$s/state/mosquitto_sub.log" ]]; then
  fail "(g) deploy --no-verify must never call mosquitto_pub/mosquitto_sub"
fi
s=$(new_scratch)
mkdir -p "$s/backups/FL3/t1"; echo a >"$s/backups/FL3/t1/autoexec.be"
out=$(run_rollback "$s" --no-verify FL3 t1); rc=$?
assert_eq "$rc" 0 "(g) expected rollback --no-verify exit 0"
if [[ -f "$s/state/mosquitto_pub.log" || -f "$s/state/mosquitto_sub.log" ]]; then
  fail "(g) rollback --no-verify must never call mosquitto_pub/mosquitto_sub"
fi

# --- (h) C1: partial upload. muh_lib.be lands, the device script fails to
#     upload -> PARTIAL: replaced muh_lib.be, rollback hint, exit 1, and
#     autoexec.be must never be attempted (it's ordered last).
echo "=== (h) partial upload reports PARTIAL + never reaches autoexec.be ==="
s=$(new_scratch)
sed -i "s|^  \\*/ufsu\\*)|  */ufsu*)\n    [[ \$upload_src == *fl3.be ]] \&\& exit 22|" "$s/bin/curl"
out=$(run_deploy "$s" FL3); rc=$?
assert_eq "$rc" 1 "(h) expected exit 1"
assert_contains "$out" "FAILED uploading fl3.be" "(h) expected fl3.be upload failure"
assert_contains "$out" "PARTIAL: replaced muh_lib.be" "(h) expected PARTIAL report naming only muh_lib.be"
assert_contains "$out" "rollback: tools/rollback.sh FL3 20260101-000000" "(h) expected rollback hint"
assert_not_contains "$(cat "$s/state/curl-calls.log")" "ufsu=@MUH/autoexec.be" "(h) autoexec.be must never be uploaded after an earlier failure"

# --- (h2) restart failure after a full upload is also PARTIAL (device not
#     yet running the new files).
echo "=== (h2) restart failure reports PARTIAL with everything replaced ==="
s=$(new_scratch)
sed -i "s|^  \\*/cm\\\\?cmnd=Restart\\*)|  */cm\\\\?cmnd=Restart*)\n    exit 28|" "$s/bin/curl"
out=$(run_deploy "$s" --autoexec-only FL3); rc=$?
assert_eq "$rc" 1 "(h2) expected exit 1"
assert_contains "$out" "FAILED restarting FL3" "(h2) expected restart failure message"
assert_contains "$out" "PARTIAL: replaced muh_lib.be autoexec.be" "(h2) expected PARTIAL report naming both files"

# --- (i) I1: DeviceName-case backup dir (tsv "BAD" -> backups/Bad/...):
#     deploy still finds/prints the backup and rollback resolves it
#     case-insensitively.
echo "=== (i) BAD tsv row / Bad backup dir name ==="
s=$(new_scratch)
echo "{\"ok\":true,\"autoexec\":\"$VERSION\",\"script\":\"\"}" >"$s/state/sub_queue"
out=$(FAKE_BACKUP_NAME=Bad run_deploy "$s" --autoexec-only BAD); rc=$?
assert_eq "$rc" 0 "(i) expected exit 0 despite Bad/BAD case mismatch"
assert_contains "$out" "backup: Bad -> backups/Bad/20260101-000000" "(i) expected the real backup line to show through"
out2=$(run_rollback "$s" --no-verify BAD 20260101-000000); rc2=$?
assert_eq "$rc2" 0 "(i) expected rollback to resolve backups/Bad from tsv name BAD"
assert_contains "$out2" "restored:" "(i) expected rollback to restore something"

# --- (j) I2: unknown device name is reported and fails; case-insensitive
#     matches (e.g. ANNAUHR -> AnnaUhr) succeed.
echo "=== (j) unknown device name / case-insensitive match ==="
s=$(new_scratch)
out=$(run_deploy "$s" --autoexec-only NOPE_DEVICE 2>&1); rc=$?
assert_eq "$rc" 1 "(j) expected exit 1 for an unknown device"
assert_contains "$out" "unknown device NOPE_DEVICE" "(j) expected unknown device message"
if [[ -f "$s/state/curl-calls.log" || -f "$s/state/berry-inventory.log" ]]; then
  fail "(j) unknown device must not touch backup or upload machinery"
fi
s=$(new_scratch)
echo "{\"ok\":true,\"autoexec\":\"$VERSION\",\"script\":\"\"}" >"$s/state/sub_queue"
out=$(run_deploy "$s" --autoexec-only ANNAUHR); rc=$?
assert_eq "$rc" 0 "(j) expected ANNAUHR to match devices.tsv row AnnaUhr"
assert_contains "$(cat "$s/state/berry-inventory.log")" "AnnaUhr" "(j) expected the canonical tsv-cased name to be used"

# --- (k) I3: clear-retained-status failure aborts before any upload.
echo "=== (k) clear failure aborts before upload ==="
s=$(new_scratch)
printf '#!/usr/bin/env bash\necho PUBFAIL >>"$FAKE_STATE/order.log"\nexit 5\n' >"$s/bin/mosquitto_pub"
echo "{\"ok\":true,\"autoexec\":\"$VERSION\",\"script\":\"fl3.be\"}" >"$s/state/sub_queue"
out=$(run_deploy "$s" --autoexec-only FL3); rc=$?
assert_eq "$rc" 1 "(k) expected exit 1"
assert_contains "$out" "ABORTING FL3" "(k) expected an abort message"
assert_contains "$out" "could not clear retained status" "(k) expected the clear-failure reason"
if [[ -f "$s/state/curl-calls.log" ]]; then
  fail "(k) nothing should be uploaded when the clear fails"
fi

# --- (l) I4: a backup with the .EMPTY marker rolls back to "no .be files"
#     (deletes everything currently on the device) instead of being refused.
echo "=== (l) .EMPTY marker backup ==="
s=$(new_scratch)
mkdir -p "$s/backups/PV_A/e1"
: >"$s/backups/PV_A/e1/.EMPTY"
echo a >"$s/state/store/autoexec.be"
echo b >"$s/state/store/muh_lib.be"
out=$(run_rollback "$s" --no-verify PV_A e1); rc=$?
assert_eq "$rc" 0 "(l) expected exit 0 for a marked-empty backup"
assert_contains "$out" "restored: (none" "(l) expected a 'nothing to restore' message"
assert_contains "$out" "deleted: autoexec.be muh_lib.be" "(l) expected every device .be file deleted"
[[ -z $(ls -A "$s/state/store" 2>/dev/null) ]] || fail "(l) device store should be empty after an .EMPTY rollback"

# --- (l2) an empty backup dir WITHOUT the marker is still refused.
echo "=== (l2) empty backup dir without marker is refused ==="
s=$(new_scratch)
mkdir -p "$s/backups/PV_A/e2"
out=$(run_rollback "$s" PV_A e2 2>&1); rc=$?
assert_eq "$rc" 1 "(l2) expected exit 1"
assert_contains "$out" "refusing to roll back" "(l2) expected a refusal message"
if [[ -f "$s/state/curl-calls.log" ]]; then
  fail "(l2) an unmarked empty backup must not touch the device at all"
fi

# --- (m) I5: berry-inventory.sh itself must fail closed (no backup: line,
#     rc 1) if the device's file listing can't be fetched. This exercises
#     the *real* berry-inventory.sh, not the deploy-test fake.
echo "=== (m) berry-inventory.sh fails closed on a bad listing ==="
s=$(new_scratch)
cp "$REPO/tools/berry-inventory.sh" "$s/tools/berry-inventory.sh"
cat >"$s/bin/curl" <<'FAKE_CURL2'
#!/usr/bin/env bash
unset BASH_ENV
for a in "$@"; do url=$a; done
case "$*" in
  *cmnd=DeviceName*) echo '{"DeviceName":"FL3"}'; exit 0 ;;
  *cmnd=Status%202*) echo '{"StatusFWR":{"Hardware":"ESP32"}}'; exit 0 ;;
  *cmnd=Status%204*) echo '{"StatusSTS":{"Drivers":"1,52,"}}'; exit 0 ;;
  *ufsd?dir=*) exit 22 ;;
  *) exit 1 ;;
esac
FAKE_CURL2
chmod +x "$s/bin/curl"
out=$(cd "$s" && PATH="$s/bin:$PATH" BASH_ENV= tools/berry-inventory.sh FL3 2>&1); rc=$?
assert_eq "$rc" 1 "(m) expected berry-inventory.sh to exit non-zero"
assert_not_contains "$out" "backup:" "(m) expected no backup: line when the listing fails"
assert_contains "$out" "FAILED" "(m) expected a failure message"

# --- (n) I7: rollback without a timestamp lists what's on disk and exits 1.
echo "=== (n) rollback with no timestamp lists backups ==="
s=$(new_scratch)
mkdir -p "$s/backups/FL3/20260101-000000" "$s/backups/FL3/20260202-000000"
: >"$s/backups/FL3/20260101-000000/autoexec.be"
: >"$s/backups/FL3/20260202-000000/autoexec.be"
out=$(run_rollback "$s" FL3 2>&1); rc=$?
assert_eq "$rc" 1 "(n) expected exit 1 without a timestamp"
assert_contains "$out" "20260101-000000" "(n) expected the older timestamp listed"
assert_contains "$out" "20260202-000000" "(n) expected the newer timestamp listed"
older_pos=$(grep -n 20260101-000000 <<<"$out" | head -1 | cut -d: -f1)
newer_pos=$(grep -n 20260202-000000 <<<"$out" | head -1 | cut -d: -f1)
[[ $older_pos -lt $newer_pos ]] || fail "(n) expected timestamps oldest first"
if [[ -f "$s/state/curl-calls.log" ]]; then
  fail "(n) listing backups must not touch the device"
fi

# --- (o) I1: rollback given a bare IP (not a devices.tsv row) resolves the
#     backup dir by asking the device for its DeviceName.
echo "=== (o) rollback by bare IP asks the device for its DeviceName ==="
s=$(new_scratch)
mkdir -p "$s/backups/FL3/t1"; echo a >"$s/backups/FL3/t1/autoexec.be"
out=$(FAKE_DEVICENAME=FL3 run_rollback "$s" --no-verify 192.168.23.186 t1); rc=$?
assert_eq "$rc" 0 "(o) expected exit 0 resolving backups/FL3 via a live DeviceName query"
assert_contains "$out" "restored: autoexec.be" "(o) expected the FL3 backup to be restored via IP"

if [[ $FAILED -eq 0 ]]; then
  echo "test-deploy.sh: all tests passed"
else
  echo "test-deploy.sh: FAILURES ABOVE" >&2
fi
exit $FAILED
