#!/usr/bin/env bash
# Deploy Berry scripts to Tasmota devices via the web file-system upload.
#
# Usage:
#   ./deploy.sh WC FL2       # deploy to specific devices
#   DEPLOY_ALL=yes ./deploy.sh --all   # deploy to every device with a known IP
#   ./deploy.sh --list       # show the device map
#
# Reads devices.tsv (name, ip, scripts). Every deploy uploads autoexec.be
# and muh_lib.be plus the device's own scripts, then restarts the device.
# If a device has a web password, export TASMOTA_AUTH="user=admin&pass=xxx".
set -euo pipefail
cd "$(dirname "$0")"

TSV=devices.tsv

deploy_device() {
  local name=$1 ip=$2 scripts=$3
  if [[ $ip == "?" ]]; then
    echo "SKIP $name: no IP in $TSV"
    return
  fi
  echo "$name ($ip):"
  local files=(autoexec.be muh_lib.be)
  IFS=',' read -ra extra <<<"$scripts"
  files+=("${extra[@]}")
  for f in "${files[@]}"; do
    echo "  upload $f"
    # Tasmota only stores an /ufsu upload if the /ufsd page was requested
    # first (that sets Web.upload_file_type, and every upload resets it), so
    # prime it before each file. A bare POST is answered with HTTP 200 even
    # when nothing was written, so read the file back and compare bytes.
    curl -sf --connect-timeout 5 --max-time 30 -o /dev/null \
      "http://$ip/ufsd${TASMOTA_AUTH:+?$TASMOTA_AUTH}" \
      || { echo "  FAILED priming upload of $f on $name (device not restarted)"; return 1; }
    curl -sf --connect-timeout 5 --max-time 60 -F "ufsu=@MUH/$f" \
      "http://$ip/ufsu${TASMOTA_AUTH:+?$TASMOTA_AUTH}" >/dev/null \
      || { echo "  FAILED uploading $f to $name (device not restarted)"; return 1; }
    if ! curl -sf --connect-timeout 5 --max-time 30 \
        "http://$ip/ufsd?download=/$f${TASMOTA_AUTH:+&$TASMOTA_AUTH}" \
        | cmp -s - "MUH/$f"; then
      echo "  FAILED: $f on $name does not match the repo after upload (device not restarted)"
      return 1
    fi
    echo "  verified $f"
  done
  curl -sf --connect-timeout 5 --max-time 30 "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null \
    || { echo "  FAILED restarting $name"; return 1; }
  echo "  restarted"
}

main() {
  if [[ $# -lt 1 ]]; then
    echo "usage: $0 <device...> | --all | --list" >&2
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
