#!/usr/bin/env bash
# Fleet health sweep: Berry driver state, module, GPIO count, uptime, restart reason.
# Usage: tools/fleet-check.sh            # every IP in devices.tsv (+ $FLEET_EXTRA, space-separated)
#        tools/fleet-check.sh 192.168.23.201 HD
# Exit 1 if any device has Berry disabled (!52), a fallback module, or no GPIOs.
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
bad=0
printf '%-10s %-16s %-6s %-22s %-5s %-12s %s\n' DEVICE IP BERRY MODULE GPIOS UPTIME RESTART
for ip in "${targets[@]}"; do
  name=$(cm "$ip" DeviceName | grep -o '"DeviceName":"[^"]*"' | cut -d'"' -f4)
  if [[ -z $name ]]; then
    printf '%-10s %-16s %s\n' '?' "$ip" 'no answer'; bad=1; continue
  fi
  berry=$(cm "$ip" Status%204 | grep -o '"Drivers":"[^"]*"' | grep -o '[!]*52')
  module=$(cm "$ip" Module | grep -o '"[0-9]*":"[^"]*"' | head -1 | tr -d '"')
  # `Template` reports the device's GPIO map as {"NAME":...,"GPIO":[n,n,...],...}
  # regardless of device class (ESP32 or Shelly); a plain `GPIO` query returns
  # {"GPIO":"Not supported"} on Shelly-based devices and, even on ESP32, lists
  # every pin as {"None":0} rather than the "0"-keyed form once assumed here.
  # A pin is configured when its Template array entry is non-zero.
  gpios=$(cm "$ip" Template | grep -o '"GPIO":\[[^]]*\]' | sed -E 's/.*\[(.*)\]/\1/' | tr ',' '\n' | grep -vc '^0$')
  read -r uptime reason < <(cm "$ip" Status%201 | grep -o '"Uptime":"[^"]*"\|"RestartReason":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
  flag=''
  [[ $berry != 52 ]] && flag='BERRY-DEAD'
  [[ $module == 1:* ]] && flag="$flag MODULE-FALLBACK"
  [[ ${gpios:-0} -eq 0 ]] && flag="$flag NO-GPIO"
  [[ -n $flag ]] && bad=1
  printf '%-10s %-16s %-6s %-22s %-5s %-12s %s %s\n' "$name" "$ip" "${berry:-?}" "$module" "${gpios:-?}" "$uptime" "$reason" "$flag"
done
exit $bad
