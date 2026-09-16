#!/usr/bin/env bash
# Roll a device back to a tools/berry-inventory.sh backup: upload every
# *.be from backups/<Name>/<timestamp>/ (same prime + readback logic as
# deploy.sh), delete any .be file on the device that is not part of that
# backup, then restart.
#
# Usage: tools/rollback.sh <name|ip> [timestamp]
#   name|ip     as in devices.tsv, or a bare IP
#   timestamp   selects backups/<Name>/<timestamp>; default is the newest
# If a device has a web password, export TASMOTA_AUTH="user=admin&pass=xxx".
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/lib-upload.sh

TSV=devices.tsv

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <name|ip> [timestamp]" >&2
  exit 1
fi
name=$1
ts=${2:-}

ip=$(awk -F'\t' -v n="$name" '$1==n{print $2}' "$TSV")
ip=${ip:-$name}
if [[ -z $ip || $ip == "?" ]]; then
  echo "no IP for $name in $TSV" >&2
  exit 1
fi

backup_root="backups/$name"
if [[ -z $ts ]]; then
  ts=$(ls -1 "$backup_root" 2>/dev/null | sort | tail -1)
fi
backup_dir="$backup_root/$ts"

if [[ -z $ts || ! -d $backup_dir ]]; then
  echo "no backup found at $backup_dir" >&2
  exit 1
fi

backup_files=()
while IFS= read -r f; do
  [[ -n $f ]] && backup_files+=("$f")
done < <(cd "$backup_dir" && ls -1 -- *.be 2>/dev/null)

if [[ ${#backup_files[@]} -eq 0 ]]; then
  echo "backup $backup_dir is empty, refusing to roll back" >&2
  exit 1
fi

echo "$name ($ip): rolling back to $backup_dir"
for f in "${backup_files[@]}"; do
  upload_one "$ip" "$backup_dir/$f" "$f" || { echo "  ABORTING rollback of $name (device not restarted)"; exit 1; }
done
echo "  restored: ${backup_files[*]}"

# Delete any .be file on the device that is not part of this backup.
listing=$(curl -sf --connect-timeout 3 --max-time 8 "http://$ip/ufsd?dir=/${TASMOTA_AUTH:+?$TASMOTA_AUTH}") || listing=""
device_files=()
while IFS= read -r f; do
  [[ -n $f ]] && device_files+=("$f")
done < <(grep -oE "file='[^']*\.be'" <<<"$listing" | sed -E "s/file='([^']*)'/\1/")

deleted=()
for f in "${device_files[@]}"; do
  keep=0
  for b in "${backup_files[@]}"; do
    [[ $f == "$b" ]] && { keep=1; break; }
  done
  if [[ $keep -eq 0 ]]; then
    if curl -sf --connect-timeout 5 --max-time 15 "http://$ip/ufsd?delete=/$f${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null; then
      deleted+=("$f")
    else
      echo "  FAILED deleting $f from $name"
    fi
  fi
done

if [[ ${#deleted[@]} -gt 0 ]]; then
  listing2=$(curl -sf --connect-timeout 3 --max-time 8 "http://$ip/ufsd?dir=/${TASMOTA_AUTH:+?$TASMOTA_AUTH}") || listing2=""
  for f in "${deleted[@]}"; do
    if grep -q "file='$f'" <<<"$listing2"; then
      echo "  WARNING: $f still present on device after delete"
    fi
  done
  echo "  deleted: ${deleted[*]}"
else
  echo "  deleted: (none)"
fi

curl -sf --connect-timeout 5 --max-time 30 "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null \
  || { echo "  FAILED restarting $name"; exit 1; }
echo "  restarted"
