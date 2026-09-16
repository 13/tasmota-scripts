#!/usr/bin/env bash
# Cross-check MUH/autoexec.be's DEVICE_SCRIPTS map against devices.tsv.
#
# Fails (exit 1), printing every mismatch, if:
#   (a) a devices.tsv name's upper-case form is not a DEVICE_SCRIPTS key
#   (b) a DEVICE_SCRIPTS key has no devices.tsv row
#   (c) the map value differs from the first entry of the tsv scripts
#       column (both empty is fine)
#   (d) a mapped script does not exist in MUH/
set -uo pipefail
cd "$(dirname "$0")/.."

AUTOEXEC=MUH/autoexec.be
TSV=devices.tsv
fail=0

# Parse DEVICE_SCRIPTS = { "KEY": "script.be", ... } into KEY<TAB>script lines.
map=$(sed -n '/var DEVICE_SCRIPTS *= *{/,/^}/p' "$AUTOEXEC" \
  | grep -oE '"[A-Za-z0-9_]+" *: *"[^"]*"' \
  | sed -E 's/"([A-Za-z0-9_]+)" *: *"([^"]*)"/\1\t\2/')

if [[ -z $map ]]; then
  echo "check-map: could not find DEVICE_SCRIPTS in $AUTOEXEC" >&2
  exit 1
fi

declare -A map_script
while IFS=$'\t' read -r key script; do
  [[ -z $key ]] && continue
  map_script["$key"]=$script
done <<<"$map"

declare -A tsv_first
declare -A tsv_seen
while IFS=$'\t' read -r name ip scripts; do
  [[ $name == \#* || -z $name ]] && continue
  key=${name^^}
  tsv_seen["$key"]=1
  first=${scripts%%,*}
  tsv_first["$key"]=$first

  if [[ -z ${map_script["$key"]+x} ]]; then
    echo "MISMATCH: $name (-> $key) has a devices.tsv row but no DEVICE_SCRIPTS entry"
    fail=1
  fi
done < "$TSV"

for key in "${!map_script[@]}"; do
  if [[ -z ${tsv_seen["$key"]+x} ]]; then
    echo "MISMATCH: DEVICE_SCRIPTS[\"$key\"] has no devices.tsv row"
    fail=1
    continue
  fi

  script=${map_script[$key]}
  tsv_val=${tsv_first[$key]}
  if [[ $script != "$tsv_val" ]]; then
    echo "MISMATCH: $key: DEVICE_SCRIPTS has \"$script\", devices.tsv first script is \"$tsv_val\""
    fail=1
  fi

  if [[ -n $script && ! -f "MUH/$script" ]]; then
    echo "MISMATCH: $key: DEVICE_SCRIPTS points at MUH/$script, which does not exist"
    fail=1
  fi
done

if [[ $fail -eq 0 ]]; then
  echo "check-map: OK (${#map_script[@]} map entries, ${#tsv_seen[@]} devices.tsv rows)"
fi
exit $fail
