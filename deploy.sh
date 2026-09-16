#!/usr/bin/env bash
# Deploy Berry scripts to Tasmota devices via the web file-system upload.
#
# Usage:
#   ./deploy.sh WC FL2                 # deploy to specific devices
#   ./deploy.sh --autoexec-only FL3    # upload only autoexec.be + muh_lib.be
#   ./deploy.sh --no-verify BAD        # skip retained-status verification (no MQTT)
#   DEPLOY_ALL=yes ./deploy.sh --all   # deploy to every device with a known IP
#   ./deploy.sh --list                 # show the device map
#
# Reads devices.tsv (name, ip, scripts). Every deploy:
#   1. backs the device up first (tools/berry-inventory.sh); aborts that
#      device if the backup fails.
#   2. uploads autoexec.be and muh_lib.be, plus the device's own script(s)
#      unless --autoexec-only.
#   3. clears the retained muh/berry/<KEY>/status message, restarts, then
#      polls (up to $DEPLOY_VERIFY_TIMEOUT, default 90s) for a fresh status
#      showing ok:true and the repo's AUTOEXEC_VERSION. --no-verify skips
#      this (for devices without MQTT).
# If a device has a web password, export TASMOTA_AUTH="user=admin&pass=xxx".
# Once MQTT credentials are needed, export MOSQ_ARGS (e.g. "-u u -P p").
set -euo pipefail
cd "$(dirname "$0")"
source tools/lib-upload.sh

TSV=devices.tsv
MQTT_HOST=${MQTT_HOST:-192.168.22.5}
MOSQ_ARGS=${MOSQ_ARGS:-}
DEPLOY_VERIFY_TIMEOUT=${DEPLOY_VERIFY_TIMEOUT:-90}
AUTOEXEC_VERSION=$(grep -oE 'AUTOEXEC_VERSION[[:space:]]*=[[:space:]]*"[^"]+"' MUH/autoexec.be \
  | sed -E 's/.*"([^"]+)"/\1/')

autoexec_only=0
no_verify=0

# clear_retained_status <key>
# Clears the retained muh/berry/<key>/status message so a later poll only
# ever sees a fresh publish from the post-restart boot.
clear_retained_status() {
  local key=$1
  echo "  clearing retained status"
  mosquitto_pub -h "$MQTT_HOST" $MOSQ_ARGS -t "muh/berry/$key/status" -r -n
}

# wait_for_load <name> <key> <backup_ts>
wait_for_load() {
  local name=$1 key=$2 backup_ts=$3
  echo "  waiting for LOAD status (up to ${DEPLOY_VERIFY_TIMEOUT}s)..."
  local waited=0 payload result status detail
  while (( waited < DEPLOY_VERIFY_TIMEOUT )); do
    payload=$(mosquitto_sub -h "$MQTT_HOST" $MOSQ_ARGS -t "muh/berry/$key/status" -C 1 -W 5 2>/dev/null || true)
    if [[ -n $payload ]]; then
      result=$(python3 - "$payload" "$AUTOEXEC_VERSION" <<'PYEOF'
import json
import sys

payload, want = sys.argv[1], sys.argv[2]
try:
    data = json.loads(payload)
except Exception:
    print("WAIT\t")
    sys.exit()
ok = data.get("ok")
autoexec = data.get("autoexec")
err = data.get("err", "")
script = data.get("script", "")
if ok is True and autoexec == want:
    print(f"OK\t{script}")
elif ok is False:
    print(f"FAILED\t{err}")
else:
    print(f"WAIT\t{autoexec}")
PYEOF
)
      status=${result%%$'\t'*}
      detail=${result#*$'\t'}
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
          : # still on an old/mismatched version, or unparseable — keep polling
          ;;
      esac
    fi
    (( waited += 5 ))
  done
  echo "  LOAD status not received within ${DEPLOY_VERIFY_TIMEOUT}s"
  echo "  rollback: tools/rollback.sh $name $backup_ts"
  return 1
}

deploy_device() {
  local name=$1 ip=$2 scripts=$3
  if [[ $ip == "?" ]]; then
    echo "SKIP $name: no IP in $TSV"
    return
  fi
  echo "$name ($ip):"

  local inv_out
  if ! inv_out=$(tools/berry-inventory.sh "$name" 2>&1); then
    echo "  BACKUP FAILED, skipping $name:"
    echo "$inv_out" | sed 's/^/    /'
    return 1
  fi
  local backup_line backup_ts
  backup_line=$(grep -m1 "^backup: $name -> " <<<"$inv_out" || true)
  if [[ -z $backup_line ]]; then
    echo "  BACKUP produced no backup dir, skipping $name:"
    echo "$inv_out" | sed 's/^/    /'
    return 1
  fi
  echo "  $backup_line"
  backup_ts=${backup_line##*/}

  local files=(autoexec.be muh_lib.be)
  if [[ $autoexec_only -eq 0 ]]; then
    IFS=',' read -ra extra <<<"$scripts"
    files+=("${extra[@]}")
  fi
  for f in "${files[@]}"; do
    [[ -z $f ]] && continue
    upload_one "$ip" "MUH/$f" "$f" || return 1
  done

  local key=${name^^}
  if [[ $no_verify -eq 1 ]]; then
    curl -sf --connect-timeout 5 --max-time 30 "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null \
      || { echo "  FAILED restarting $name"; return 1; }
    echo "  restarted"
    return 0
  fi

  clear_retained_status "$key"

  curl -sf --connect-timeout 5 --max-time 30 "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null \
    || { echo "  FAILED restarting $name"; return 1; }
  echo "  restarted"

  wait_for_load "$name" "$key" "$backup_ts"
}

main() {
  local args=()
  for a in "$@"; do
    case $a in
      --autoexec-only) autoexec_only=1 ;;
      --no-verify) no_verify=1 ;;
      *) args+=("$a") ;;
    esac
  done
  set -- "${args[@]}"

  if [[ $# -lt 1 ]]; then
    echo "usage: $0 [--autoexec-only] [--no-verify] <device...> | --all | --list" >&2
    exit 1
  fi

  if [[ $1 == "--list" ]]; then
    column -t "$TSV"
    exit 0
  fi

  if [[ $1 == "--all" ]]; then
    [[ ${DEPLOY_ALL:-} == yes ]] || { echo "refusing --all without DEPLOY_ALL=yes"; exit 1; }
  fi

  local rc=0
  while IFS=$'\t' read -r name ip scripts; do
    [[ $name == \#* || -z $name ]] && continue
    if [[ $1 == "--all" ]]; then
      deploy_device "$name" "$ip" "$scripts" || rc=1
    else
      for want in "$@"; do
        [[ $want == "$name" ]] && { deploy_device "$name" "$ip" "$scripts" || rc=1; }
      done
    fi
  done < "$TSV"
  exit $rc
}

main "$@"
