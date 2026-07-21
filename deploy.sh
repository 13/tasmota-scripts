#!/usr/bin/env bash
# Deploy Berry scripts to Tasmota devices via the web file-system upload.
#
# Usage:
#   ./deploy.sh WC FL2       # deploy to specific devices
#   ./deploy.sh --all        # deploy to every device with a known IP
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
    curl -sf --connect-timeout 5 -F "ufsu=@MUH/$f" \
      "http://$ip/ufsu${TASMOTA_AUTH:+?$TASMOTA_AUTH}" >/dev/null \
      || { echo "  FAILED uploading $f to $name"; return 1; }
  done
  curl -sf "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null \
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
