#!/usr/bin/env bash
# Send one Tasmota command to devices. Usage: tools/fleet-cmd.sh '<command>' [name|ip ...]
# With no targets: every IP in devices.tsv plus $FLEET_EXTRA. Prints one line per device.
set -uo pipefail
cd "$(dirname "$0")/.."
cmd=${1:?command required}; shift
targets=()
if [[ $# -gt 0 ]]; then
  for t in "$@"; do ip=$(awk -F'\t' -v n="$t" '$1==n{print $2}' devices.tsv); targets+=("${ip:-$t}"); done
else
  while IFS=$'\t' read -r name ip _; do [[ $name == \#* || -z $name || $ip == "?" ]] && continue; targets+=("$ip"); done < devices.tsv
  for ip in ${FLEET_EXTRA:-}; do targets+=("$ip"); done
fi
enc=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$cmd")
rc=0
for ip in "${targets[@]}"; do
  name=$(curl -s --connect-timeout 3 --max-time 6 "http://$ip/cm?cmnd=DeviceName" | grep -o '"DeviceName":"[^"]*"' | cut -d'"' -f4)
  reply=$(curl -s --connect-timeout 3 --max-time 8 "http://$ip/cm?cmnd=$enc")
  [[ -z $reply ]] && rc=1
  printf '%-10s %-16s %s\n' "${name:-?}" "$ip" "${reply:-NO ANSWER}"
done
exit $rc
