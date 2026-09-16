#!/usr/bin/env bash
# Read-only fleet inventory: Berry map drift + per-device *.be backup.
# Usage: tools/berry-inventory.sh            # every IP in devices.tsv (+ $FLEET_EXTRA, space-separated)
#        tools/berry-inventory.sh 192.168.23.201 HD
#
# For every reachable device with Berry enabled (skips ESP8266/ESP8285, which
# have no Berry, and any device with Status 4 Drivers showing "!52" or no
# "52"), downloads every *.be file from /ufsd?dir=/ into
# backups/<DeviceName>/<YYYYmmdd-HHMMSS>/, then prints one row comparing the
# device against the repo's MUH/ map:
#   DEVICE IP KEY AUTOEXEC FILES MAP PRESENT SCRIPT
# AUTOEXEC: same|drift|none (vs MUH/autoexec.be, byte-identical via cmp).
# FILES: comma-separated *.be files found on the device.
# MAP: script filename mapped to KEY in MUH/autoexec.be's DEVICE_SCRIPTS
#      (parsed case-insensitively), or "-" if KEY has no map entry.
# PRESENT: yes|no|- whether the MAP file exists among FILES ("-" when MAP is "-").
# SCRIPT: same|differs|repo-missing|- comparing the downloaded MAP file with
#         MUH/<file> ("-" when PRESENT is not "yes").
#
# READ-ONLY on devices: only GET /cm?cmnd=..., /ufsd?dir=/, /ufsd?download=...
# Never sends any other command. Exits non-zero if any *.be download fails.
set -uo pipefail
cd "$(dirname "$0")/.."

targets=()
if [[ $# -gt 0 ]]; then
  for t in "$@"; do
    ip=$(awk -F'\t' -v n="$t" '$1==n{print $2}' devices.tsv)
    targets+=("${ip:-$t}")
  done
else
  while IFS=$'\t' read -r name ip _; do
    [[ $name == \#* || -z $name || $ip == "?" ]] && continue
    targets+=("$ip")
  done < devices.tsv
  for ip in ${FLEET_EXTRA:-}; do targets+=("$ip"); done
fi

cm() { curl -s --connect-timeout 3 --max-time 6 "http://$1/cm?cmnd=$2"; }

# Repo map: DEVICE_SCRIPTS entries in MUH/autoexec.be, e.g. "AnnaUhr": "annauhr.be".
# Accept mixed- or upper-case keys (an in-flight task is uppercasing them);
# comparison against a device's KEY is case-insensitive.
map_raw=$(grep -oE '"[A-Za-z0-9_]+"[[:space:]]*:[[:space:]]*"[a-z0-9_.]*"' MUH/autoexec.be)
map_lookup() {
  # $1 = KEY (upper-case DeviceName)
  local k v
  while IFS= read -r line; do
    k=$(sed -E 's/^"([^"]+)".*/\1/' <<<"$line")
    v=$(sed -E 's/.*: *"([^"]*)"$/\1/' <<<"$line")
    if [[ ${k^^} == "$1" ]]; then
      echo "$v"
      return
    fi
  done <<<"$map_raw"
}

ts=$(date +%Y%m%d-%H%M%S)
rc=0

printf '%-10s %-16s %-10s %-8s %-30s %-12s %-8s %s\n' DEVICE IP KEY AUTOEXEC FILES MAP PRESENT SCRIPT
for ip in "${targets[@]}"; do
  name=$(cm "$ip" DeviceName | grep -o '"DeviceName":"[^"]*"' | cut -d'"' -f4)
  if [[ -z $name ]]; then
    printf '%-10s %-16s %s\n' '?' "$ip" 'no answer'
    rc=1
    continue
  fi

  st2=$(cm "$ip" Status%202)
  hw=$(grep -o '"Hardware":"[^"]*"' <<<"$st2" | cut -d'"' -f4)
  if [[ $hw == ESP8266* || $hw == ESP8285* ]]; then
    continue
  fi

  berry=$(cm "$ip" Status%204 | grep -o '"Drivers":"[^"]*"' | grep -oE '(^|,)!?52(,|$)' | tr -d ',')
  if [[ $berry != 52 ]]; then
    continue
  fi

  # Require a real 200 + something that looks like the ufsd management page;
  # curl -s alone would happily "succeed" on a connection-refused empty
  # response, which used to look just like an empty (but valid) file list.
  listing_rc=0
  listing=$(curl -sf --connect-timeout 3 --max-time 8 "http://$ip/ufsd?dir=/") || listing_rc=$?
  if [[ $listing_rc -ne 0 || $listing != *ufsd* ]]; then
    echo "FAILED: could not list files on $name ($ip)" >&2
    rc=1
    continue
  fi
  files=()
  while IFS= read -r f; do
    [[ -n $f ]] && files+=("$f")
  done < <(grep -oE "file='[^']*\.be'" <<<"$listing" | sed -E "s/file='([^']*)'/\1/")

  key=${name^^}
  backup_dir="backups/$name/$ts"
  mkdir -p "$backup_dir"
  dl_fail=0
  for f in "${files[@]}"; do
    if ! curl -sf --connect-timeout 3 --max-time 15 "http://$ip/ufsd?download=/$f" -o "$backup_dir/$f"; then
      dl_fail=1
    fi
  done
  if [[ $dl_fail -ne 0 ]]; then
    rc=1
  fi
  # A device that genuinely has no *.be files gets a marker so rollback.sh
  # can tell "empty backup, on purpose" apart from "backup never completed".
  if [[ ${#files[@]} -eq 0 ]]; then
    : >"$backup_dir/.EMPTY"
  fi
  echo "backup: $name -> $backup_dir" >&2

  autoexec=none
  if [[ -f "$backup_dir/autoexec.be" ]]; then
    if cmp -s "$backup_dir/autoexec.be" MUH/autoexec.be; then
      autoexec=same
    else
      autoexec=drift
    fi
  fi

  map=$(map_lookup "$key")
  map=${map:--}

  present=-
  script=-
  if [[ $map != "-" && -n $map ]]; then
    present=no
    for f in "${files[@]}"; do
      [[ $f == "$map" ]] && present=yes && break
    done
    if [[ $present == yes ]]; then
      if [[ ! -f "MUH/$map" ]]; then
        script=repo-missing
      elif cmp -s "$backup_dir/$map" "MUH/$map"; then
        script=same
      else
        script=differs
      fi
    fi
  fi

  files_joined=$(IFS=,; echo "${files[*]:-}")
  [[ -z $files_joined ]] && files_joined=-

  printf '%-10s %-16s %-10s %-8s %-30s %-12s %-8s %s\n' \
    "$name" "$ip" "$key" "$autoexec" "$files_joined" "$map" "$present" "$script"
done

exit $rc
