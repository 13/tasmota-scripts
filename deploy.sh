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
#      device if the backup fails (nothing is uploaded).
#   2. unless --no-verify, clears the retained muh/berry/<KEY>/status
#      message BEFORE anything is uploaded; aborts (nothing uploaded) if
#      that fails.
#   3. uploads muh_lib.be, then the device's own script(s) (unless
#      --autoexec-only), then autoexec.be LAST: old loaders ignore
#      muh_lib.be, and the new canonical loader only takes over once
#      autoexec.be lands, so autoexec.be must be the final file written. A
#      failure here after at least one file has already landed prints
#      "PARTIAL: replaced <files>" plus a rollback hint and stops that
#      device.
#   4. restarts, then (unless --no-verify) polls (up to
#      $DEPLOY_VERIFY_TIMEOUT, default 90s) for a fresh status showing
#      ok:true and the repo's AUTOEXEC_VERSION.
# Device name matching against devices.tsv is case-insensitive; an argument
# matching no row is reported as "unknown device <name>".
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

deploy_device() {
  local name=$1 ip=$2 scripts=$3
  if [[ $ip == "?" ]]; then
    echo "SKIP $name: no IP in $TSV"
    return 0
  fi
  echo "$name ($ip):"

  local inv_out
  if ! inv_out=$(tools/berry-inventory.sh "$name" 2>&1); then
    echo "  BACKUP FAILED, skipping $name:"
    echo "$inv_out" | sed 's/^/    /'
    return 1
  fi
  # berry-inventory.sh backs a device up under the DeviceName it reports
  # live, which may differ in case from the devices.tsv row name (e.g. tsv
  # "BAD" vs. reported "Bad") -- so match on the "backup: " prefix only and
  # take whatever path follows it, rather than requiring $name to match.
  local backup_line backup_path backup_ts
  backup_line=$(grep -m1 "^backup: " <<<"$inv_out" || true)
  if [[ -z $backup_line ]]; then
    echo "  BACKUP produced no backup dir, skipping $name:"
    echo "$inv_out" | sed 's/^/    /'
    return 1
  fi
  echo "  $backup_line"
  backup_path=${backup_line#backup: * -> }
  backup_ts=${backup_path##*/}
  local rollback_hint="  rollback: tools/rollback.sh $name $backup_ts"

  local key=${name^^}
  if [[ $no_verify -eq 0 ]]; then
    if ! clear_retained_status "$key"; then
      echo "  ABORTING $name: could not clear retained status (nothing uploaded)"
      echo "$rollback_hint"
      return 1
    fi
  fi

  local device_files=()
  if [[ $autoexec_only -eq 0 ]]; then
    IFS=',' read -ra device_files <<<"$scripts"
  fi
  local files=(muh_lib.be)
  for f in "${device_files[@]}"; do [[ -n $f ]] && files+=("$f"); done
  files+=(autoexec.be)

  local replaced=()
  for f in "${files[@]}"; do
    [[ -z $f ]] && continue
    if ! upload_one "$ip" "MUH/$f" "$f"; then
      if [[ ${#replaced[@]} -gt 0 ]]; then
        echo "  PARTIAL: replaced ${replaced[*]}"
      fi
      echo "$rollback_hint"
      return 1
    fi
    replaced+=("$f")
  done

  if ! curl -sf --connect-timeout 5 --max-time 30 "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null; then
    echo "  FAILED restarting $name"
    echo "  PARTIAL: replaced ${replaced[*]}"
    echo "$rollback_hint"
    return 1
  fi
  echo "  restarted"

  if [[ $no_verify -eq 1 ]]; then
    return 0
  fi

  wait_for_load "$name" "$key" "$backup_ts" "$AUTOEXEC_VERSION"
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
  local -A matched=()
  while IFS=$'\t' read -r name ip scripts; do
    [[ $name == \#* || -z $name ]] && continue
    if [[ $1 == "--all" ]]; then
      deploy_device "$name" "$ip" "$scripts" || rc=1
    else
      for want in "$@"; do
        if [[ ${want^^} == "${name^^}" ]]; then
          matched[$want]=1
          deploy_device "$name" "$ip" "$scripts" || rc=1
        fi
      done
    fi
  done < "$TSV"

  if [[ $1 != "--all" ]]; then
    for want in "$@"; do
      if [[ -z ${matched[$want]:-} ]]; then
        echo "unknown device $want" >&2
        rc=1
      fi
    done
  fi
  exit $rc
}

main "$@"
