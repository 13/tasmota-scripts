#!/usr/bin/env bash
# Shared Tasmota web-upload + MQTT load-status helpers. Sourced by deploy.sh
# and tools/rollback.sh (not meant to be run directly). Every function here
# checks command exit codes explicitly rather than relying on `set -e`:
# callers invoke these (and the functions that wrap them) as
# `deploy_device ... || rc=1`, and bash exempts an entire function body from
# -e once its call site is itself protected by `||` — so a bare failing
# command inside would silently be ignored instead of aborting.
#
# upload_one <ip> <local-path> <remote-name>
#   local-path's basename must equal remote-name (curl -F infers the upload
#   filename from it). Prints "  upload/verified/FAILED ..." lines and
#   returns non-zero on any failure, without exiting the caller (callers run
#   under `set -e` and are expected to check the return value themselves,
#   e.g. via `|| return 1`).
upload_one() {
  local ip=$1 local_path=$2 remote_name=$3
  echo "  upload $remote_name"
  # Tasmota only stores an /ufsu upload if the /ufsd page was requested
  # first (that sets Web.upload_file_type, and every upload resets it), so
  # prime it before each file. A bare POST is answered with HTTP 200 even
  # when nothing was written, so read the file back and compare bytes.
  curl -sf --connect-timeout 5 --max-time 30 -o /dev/null \
    "http://$ip/ufsd${TASMOTA_AUTH:+?$TASMOTA_AUTH}" \
    || { echo "  FAILED priming upload of $remote_name on $ip (device not restarted)"; return 1; }
  curl -sf --connect-timeout 5 --max-time 60 -F "ufsu=@$local_path" \
    "http://$ip/ufsu${TASMOTA_AUTH:+?$TASMOTA_AUTH}" >/dev/null \
    || { echo "  FAILED uploading $remote_name to $ip (device not restarted)"; return 1; }
  if ! curl -sf --connect-timeout 5 --max-time 30 \
      "http://$ip/ufsd?download=/$remote_name${TASMOTA_AUTH:+&$TASMOTA_AUTH}" \
      | cmp -s - "$local_path"; then
    echo "  FAILED: $remote_name on $ip does not match after upload (device not restarted)"
    return 1
  fi
  echo "  verified $remote_name"
}

# clear_retained_status <key>
# Clears the retained muh/berry/<key>/status message so a later poll only
# ever sees a fresh publish from the next boot. Returns non-zero if the
# broker rejects the publish (checked explicitly, see file header).
clear_retained_status() {
  local key=$1
  echo "  clearing retained status"
  if ! mosquitto_pub -h "$MQTT_HOST" $MOSQ_ARGS -t "muh/berry/$key/status" -r -n; then
    echo "  FAILED clearing retained status for $key"
    return 1
  fi
}

# wait_for_load <name> <key> <rollback_ts> [want_version]
# Polls muh/berry/<key>/status (retained, so this only works once it has
# been cleared first) until it shows ok:true -- and, if want_version is
# given, autoexec == want_version (deploy.sh's use: the repo's
# AUTOEXEC_VERSION; rollback.sh leaves it empty since a restored backup may
# be an older version). Prints "LOAD ok (<script>)" / "LOAD FAILED: <err>" /
# a timeout message, each followed by a rollback hint, and returns non-zero
# on anything but a clean "ok" match.
wait_for_load() {
  local name=$1 key=$2 backup_ts=$3 want_version=${4:-}
  echo "  waiting for LOAD status (up to ${DEPLOY_VERIFY_TIMEOUT}s)..."
  local start=$SECONDS payload result status detail extra last_ok="" last_autoexec=""
  while (( SECONDS - start < DEPLOY_VERIFY_TIMEOUT )); do
    # `timeout 10` is a belt-and-braces guard: mosquitto_sub's own -W 5
    # should always return, but an unreachable/hanging broker must never be
    # able to wedge a deploy forever.
    payload=$(timeout 10 mosquitto_sub -h "$MQTT_HOST" $MOSQ_ARGS -t "muh/berry/$key/status" -C 1 -W 5 2>/dev/null || true)
    if [[ -n $payload ]]; then
      result=$(python3 - "$payload" "$want_version" <<'PYEOF'
import json
import sys

payload, want = sys.argv[1], sys.argv[2]
try:
    data = json.loads(payload)
except Exception:
    data = None
if not isinstance(data, dict):
    # Non-object (or unparseable) payload: keep waiting, don't crash.
    print("WAIT\t\t")
else:
    ok = data.get("ok")
    autoexec = data.get("autoexec")
    err = data.get("err", "")
    script = data.get("script", "")
    if ok is True and (not want or autoexec == want):
        print(f"OK\x1f{script}\x1f{autoexec}")
    elif ok is False:
        print(f"FAILED\x1f{err}\x1f{autoexec}")
    else:
        print(f"WAIT\x1f{ok}\x1f{autoexec}")
PYEOF
)
      IFS=$'\x1f' read -r status detail extra <<<"$result"
      case $status in
        OK)
          echo "  LOAD ok (${detail:-library only})"
          return 0
          ;;
        FAILED)
          echo "  LOAD FAILED: $detail"
          echo "  rollback: tools/rollback.sh $name $backup_ts"
          return 1
          ;;
        *)
          last_ok=$detail
          last_autoexec=$extra
          ;;
      esac
    fi
    sleep 2
  done
  echo "  LOAD status not received within ${DEPLOY_VERIFY_TIMEOUT}s (last seen: ok=${last_ok:-none} autoexec=${last_autoexec:-none})"
  echo "  rollback: tools/rollback.sh $name $backup_ts"
  return 1
}
