#!/usr/bin/env bash
# Fleet health sweep: Berry driver state, module, GPIO count, uptime, restart reason.
# Usage: tools/fleet-check.sh            # every IP in devices.tsv (+ $FLEET_EXTRA, space-separated)
#        tools/fleet-check.sh 192.168.23.201 HD
# Exit 1 if any device has Berry disabled (!52), a fallback module that does not
# match its stored Template, or relays
# declared in its Template but missing at runtime (boot-loop GPIO wipe).
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
# BUILD column: compare each device's running firmware image against the
# version promoted on the OTA host's CURRENT file (lines "name -> target").
# Until CURRENT exists, curl returns an nginx 404 page; grep -E filters that
# out so every device just falls back to showing its plain version untagged.
OTA_BASE=${OTA_BASE:-http://192.168.22.11/tasmota}
current=$(curl -s --max-time 5 "$OTA_BASE/CURRENT" | grep -E '^[^ ]+ -> [^ ]+$')
bad=0
printf '%-10s %-16s %-6s %-22s %-14s %-12s %-14s %s\n' DEVICE IP BERRY MODULE RELAYS UPTIME BUILD RESTART
for ip in "${targets[@]}"; do
  name=$(cm "$ip" DeviceName | grep -o '"DeviceName":"[^"]*"' | cut -d'"' -f4)
  if [[ -z $name ]]; then
    printf '%-10s %-16s %s\n' '?' "$ip" 'no answer'; bad=1; continue
  fi
  berry=$(cm "$ip" Status%204 | grep -o '"Drivers":"[^"]*"' | grep -oE '(^|,)!?52(,|$)' | tr -d ',')
  module=$(cm "$ip" Module | grep -o '"[0-9]*":"[^"]*"' | head -1 | tr -d '"')
  # Live GPIO assignment is not queryable (`GPIO` lists only free pins), so
  # detect a boot-loop GPIO wipe indirectly: the stored Template still lists
  # relay pins (codes 224..255) but the running config has no relay, in which
  # case `Status 11` carries no "POWER" key.
  tpl=$(cm "$ip" Template)
  tpl_name=$(grep -o '"NAME":"[^"]*"' <<<"$tpl" | cut -d'"' -f4)
  tpl_relays=$(grep -o '"GPIO":\[[^]]*\]' <<<"$tpl" | grep -o '"GPIO":\[[^]]*\]' | sed -E 's/.*\[(.*)\]/\1/' | tr ',' '\n' | awk '($1>=224 && $1<=255) || ($1>=2272 && $1<=2303)' | wc -l)   # Relay1..32, plus inverted (+2048)
  live_power=$(cm "$ip" Status%2011 | grep -c '"POWER')
  relays="tpl:${tpl_relays} live:$([[ $live_power -gt 0 ]] && echo y || echo n)"
  st1=$(cm "$ip" Status%201)
  uptime=$(grep -o '"Uptime":"[^"]*"' <<<"$st1" | cut -d'"' -f4)
  reason=$(grep -o '"RestartReason":"[^"]*"' <<<"$st1" | cut -d'"' -f4)
  # BUILD: does the running image match what CURRENT promotes for this
  # device's OtaUrl? "stock" = OtaUrl not listed in CURRENT (not a MUH
  # build, or CURRENT has no data yet for it). "old:<ver>" = a promoted
  # build exists but this device hasn't picked it up yet.
  ver=$(cm "$ip" Status%202 | grep -o '"Version":"[^"]*"' | cut -d'"' -f4)
  img=${ver#*(}; img=${img%)}
  ota=$(cm "$ip" OtaUrl | grep -o '"OtaUrl":"[^"]*"' | cut -d'"' -f4)
  want=$(awk -v f="${ota##*/}" '$1 == f {print $3}' <<<"$current"); want=${want%/*}; want=${want#dev/}
  if [[ -z $want ]]; then build=$ver
  elif [[ $img == "$want-"* ]]; then build=$want
  else build="old:${ver%%(*}"; fi
  flag=''
  [[ $berry != 52 ]] && flag='BERRY-DEAD'
  # Boot-loop protection resets the module to the fallback (index 1, e.g.
  # ESP32-DevKit) but leaves the stored Template intact, so the two disagree.
  [[ $module == 1:* && ${module#1:} != "$tpl_name" ]] && flag="$flag MODULE-FALLBACK"
  [[ $tpl_relays -gt 0 && $live_power -eq 0 ]] && flag="$flag RELAYS-WIPED"
  [[ -n $flag ]] && bad=1
  # UPGRADE-PENDING is informational only; it never affects the exit code.
  note=''
  [[ -n $want && $build == old:* ]] && note='UPGRADE-PENDING'
  printf '%-10s %-16s %-6s %-22s %-14s %-12s %-14s %s %s %s\n' "$name" "$ip" "${berry:-?}" "$module" "$relays" "$uptime" "$build" "$reason" "$flag" "$note"
done
exit $bad
