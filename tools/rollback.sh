#!/usr/bin/env bash
# Roll a device back to a tools/berry-inventory.sh backup: upload every
# *.be from backups/<Name>/<timestamp>/ (same prime + readback logic as
# deploy.sh, muh_lib.be/scripts before autoexec.be last), delete any .be
# file on the device that is not part of that backup, restart, then
# (unless --no-verify) clear the retained status and wait for a fresh one,
# same as deploy.sh.
#
# Usage: tools/rollback.sh [--no-verify] <name|ip> [timestamp]
#   name|ip     as in devices.tsv (case-insensitive), or a bare IP (its
#               DeviceName is queried live to find backups/<DeviceName>)
#   timestamp   selects backups/<Name>/<timestamp>; required -- omit it to
#               get a list of the timestamps actually on disk
# A backup with a ".EMPTY" marker (device genuinely had no *.be files) is
# valid and rolls back to "no .be files on the device" rather than being
# refused as an empty/incomplete backup.
# If a device has a web password, export TASMOTA_AUTH="user=admin&pass=xxx".
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/lib-upload.sh

TSV=devices.tsv
MQTT_HOST=${MQTT_HOST:-192.168.22.5}
MOSQ_ARGS=${MOSQ_ARGS:-}
DEPLOY_VERIFY_TIMEOUT=${DEPLOY_VERIFY_TIMEOUT:-90}

no_verify=0
args=()
for a in "$@"; do
  case $a in
    --no-verify) no_verify=1 ;;
    *) args+=("$a") ;;
  esac
done
set -- "${args[@]}"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 [--no-verify] <name|ip> [timestamp]" >&2
  exit 1
fi
name_arg=$1
ts=${2:-}

ip=$(awk -F'\t' -v n="${name_arg,,}" 'tolower($1)==n{print $2; exit}' "$TSV")
lookup_name=$name_arg
if [[ -z $ip ]]; then
  # Not a devices.tsv row -- try it as a bare IP and ask the device itself.
  ip=$name_arg
  lookup_name=$(curl -sf --connect-timeout 3 --max-time 6 "http://$ip/cm?cmnd=DeviceName" 2>/dev/null \
    | grep -o '"DeviceName":"[^"]*"' | cut -d'"' -f4) || true
  if [[ -z $lookup_name ]]; then
    echo "no device found for '$name_arg' (not in $TSV, and it did not answer as an IP)" >&2
    exit 1
  fi
fi
if [[ -z $ip || $ip == "?" ]]; then
  echo "no IP for $name_arg in $TSV" >&2
  exit 1
fi

# Backups are stored under the DeviceName the device reports live, which
# may differ in case from a devices.tsv row (tsv "BAD" -> backups/Bad/...),
# so resolve the directory case-insensitively.
backup_root=""
if [[ -d "backups/$lookup_name" ]]; then
  backup_root="backups/$lookup_name"
else
  shopt -s nocasematch
  for d in backups/*/; do
    d=${d%/}
    [[ -d $d && ${d##*/} == "$lookup_name" ]] && { backup_root=$d; break; }
  done
  shopt -u nocasematch
fi
if [[ -z $backup_root ]]; then
  echo "no backups found for $name_arg" >&2
  exit 1
fi

if [[ -z $ts ]]; then
  echo "specify a timestamp for $name_arg. Available (oldest first):" >&2
  ls -1 "$backup_root" 2>/dev/null | sort >&2
  exit 1
fi
backup_dir="$backup_root/$ts"

if [[ ! -d $backup_dir ]]; then
  echo "no backup found at $backup_dir" >&2
  exit 1
fi

has_empty_marker=0
[[ -f "$backup_dir/.EMPTY" ]] && has_empty_marker=1

backup_files=()
while IFS= read -r f; do
  [[ -n $f ]] && backup_files+=("$f")
done < <(cd "$backup_dir" && { ls -1 -- *.be 2>/dev/null | grep -vx 'autoexec.be' || true; [[ ! -f autoexec.be ]] || echo autoexec.be; })

if [[ ${#backup_files[@]} -eq 0 && $has_empty_marker -eq 0 ]]; then
  echo "backup $backup_dir is empty (no .EMPTY marker), refusing to roll back" >&2
  exit 1
fi

rc=0
echo "$name_arg ($ip): rolling back to $backup_dir"
restored=()
if [[ ${#backup_files[@]} -gt 0 ]]; then
  for f in "${backup_files[@]}"; do
    upload_one "$ip" "$backup_dir/$f" "$f" || { echo "  ABORTING rollback of $name_arg (device not restarted; already restored: ${restored[*]:-none})"; exit 1; }
    restored+=("$f")
  done
  echo "  restored: ${backup_files[*]}"
else
  echo "  restored: (none -- backup marks this device as having no .be files)"
fi

# Delete any .be file on the device that is not part of this backup. Abort
# before deleting anything if the listing itself fails -- we must not guess
# at device state.
if ! listing=$(curl -sf --connect-timeout 3 --max-time 8 "http://$ip/ufsd?dir=/${TASMOTA_AUTH:+&$TASMOTA_AUTH}"); then
  echo "  FAILED to list files on $ip; aborting before delete/restart" >&2
  exit 1
fi
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
      echo "  FAILED deleting $f from $name_arg"
      rc=1
    fi
  fi
done

if [[ ${#deleted[@]} -gt 0 ]]; then
  listing2=$(curl -sf --connect-timeout 3 --max-time 8 "http://$ip/ufsd?dir=/${TASMOTA_AUTH:+&$TASMOTA_AUTH}") || listing2=""
  for f in "${deleted[@]}"; do
    if grep -q "file='$f'" <<<"$listing2"; then
      echo "  WARNING: $f still present on device after delete"
    fi
  done
  echo "  deleted: ${deleted[*]}"
else
  echo "  deleted: (none)"
fi

if [[ $no_verify -eq 0 ]]; then
  key=${lookup_name^^}
  if ! clear_retained_status "$key"; then
    echo "  WARNING: could not clear retained status for $key before restart"
  fi
fi

if ! curl -sf --connect-timeout 5 --max-time 30 "http://$ip/cm?cmnd=Restart%201${TASMOTA_AUTH:+&$TASMOTA_AUTH}" >/dev/null; then
  echo "  FAILED restarting $name_arg"
  exit 1
fi
echo "  restarted"

# Loaders from before the canonical autoexec never publish muh/berry/<KEY>/status,
# and an .EMPTY restore leaves no loader at all: waiting would always time out.
if [[ $no_verify -eq 0 ]] && ! grep -qs 'muh/berry/' "$backup_dir/autoexec.be"; then
  echo "  restored loader does not report load status; check with: make fleet (Status 4 / syslog)"
  no_verify=1
fi

if [[ $no_verify -eq 0 ]]; then
  # A restored backup may be an older AUTOEXEC_VERSION than the repo's, so
  # unlike deploy.sh, success here only requires ok:true (no version
  # given to wait_for_load).
  wait_for_load "$name_arg" "$key" "$ts" || rc=1
fi

exit $rc
