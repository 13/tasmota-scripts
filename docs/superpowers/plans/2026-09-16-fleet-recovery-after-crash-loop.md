# Fleet Recovery After the Sep 11 Crash Loop — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring G_INT, HD_EXT and G_EXT back to life (Berry, and for G_INT the relay/GPIO config), make "Berry silently disabled" impossible to miss in future, and reduce how easily a transient crash loop disables a device.

**Architecture:** No Berry code changes. Task 1 is device commands only (`Module 0`, `Restart 1`). Task 2 adds `tools/fleet-check.sh`, a read-only sweep that reports Berry driver state, module, GPIO count and uptime per device. Task 3 raises the boot-loop offset (`SetOption36`) fleet-wide so it takes more consecutive fast crashes before Tasmota starts stripping features. Task 4 captures evidence for the still-open question of what happened at 06:00 (FRITZ!Box event log, optional syslog). Deploying the repo's refactored scripts to these devices is explicitly out of scope (separate plan; they never ran on hardware).

**Tech Stack:** Tasmota 15.1.0 HTTP command API (`/cm?cmnd=`), bash + curl, mosquitto clients.

## Global Constraints

- Never issue `Restart 1` to a device more than once per 2 minutes, and never to two door/garage devices in parallel.
- All device commands over HTTP: `curl -s "http://IP/cm?cmnd=<urlencoded>"`. No web password is set on these devices.
- Verification of "Berry alive" is `Status 4` Drivers containing `52` without `!`. Verification of hardware config is `Module` returning the template name (`{"Module":{"0":"..."}}`) and `Status 10` showing `ENERGY`/`Switch1`.
- Do not touch `_persist.json`, `_matter_device.json` or any file on the devices.
- The devices in this plan run OLD self-contained scripts (not the repo versions). Keep it that way here.

## What happened (evidence, 2026-09-16)

- 2026-09-11 between 06:00:37 and 06:02:06 local, eight ESP32 Tasmota devices restarted: FL2, Bad, FL3, HZ_WW, HD_EXT, G_EXT, HD_INT, G_INT. Seven of them (all except HZ_WW) hold a crash record in `Status 12` (`IllegalInstruction` on FL2/FL3, `Cp7Dis` exception 39 on G_INT, "Unknown" on Bad/HD_INT/HD_EXT/G_EXT). HZ_WW's restart came from its own script (fixed 2026-09-16).
- No script on any of these devices contains a restart or ping rule (all on-device `.be` files downloaded and grepped). No oversized retained MQTT payload exists. MQTT broker uptime since 2026-08-18. FRITZ!Box WAN session since 2026-09-15 05:23, so not a WAN reconnect. FRITZ!Box 5530 Fiber, FRITZ!OS 8.25, is also the Wi-Fi AP (BSSID b0:f2:08:19:86:7c, AVM) for every affected device.
- Conclusion so far: a simultaneous crash across the ESP32 fleet at 06:00, most plausibly triggered by a Wi-Fi/AP event on the FRITZ!Box (channel change, Wi-Fi restart, firmware update, mesh re-sync). Each device crashed, rebooted, and some crashed again on reconnect while the AP was still unstable. Tasmota boot-loop protection (`SetOption36 = 1`) then stripped features by count of fast restarts: after 4 it set `no_autoexec` (Berry never initialised) on G_INT, HD_EXT, G_EXT; after 5 and 6 it wiped GPIOs and reset the module on G_INT. FL2/FL3/Bad/HD_INT crashed fewer times and kept Berry.
- Still unknown: the exact AP event. Only the FRITZ!Box event log (System > Ereignisse, needs the box login) can show it. That is Task 4 Step 1 for the owner.
- A second mass restart on 2026-09-07 12:16 local hit G_TREPPE, AnnaUhr, WZ3, PlugUD, HZ_DGB, PARK2: all report `RestartReason: Vbat power on reset`, so that one was a power cut, unrelated.
- Decoding the Sep 11 call chains is not possible: Tasmota publishes no `.map`/`.elf` for the 15.1.0 release builds (checked ota.tasmota.com and the GitHub release assets on 2026-09-16).
- Executed 2026-09-16: Task 1 (G_INT `Module 0` restored template/relay/ENERGY, Berry 52, relay toggled OK; HD_EXT and G_EXT `Restart 1`, Berry 52), Task 2 (`tools/fleet-check.sh`, sweep of 19 devices clean), Task 3 (`SetOption36 5` on 19 devices). Open: Task 4 Step 1, the FRITZ!Box event log around 2026-09-11 06:00.

Device facts (DHCP addresses, may change):

| Device | IP | Berry | Module | Hardware config |
|---|---|---|---|---|
| G_INT | 192.168.23.201 | dead (`!52`) | `1 ESP32-DevKit` (fallback) | all GPIO None, no relay/energy |
| HD_EXT | 192.168.23.88 | dead (`!52`) | `0 Shelly Plus 1PM` | intact (ENERGY, Switch1) |
| G_EXT | 192.168.23.119 | dead (`!52`) | `0 Shelly Plus 1PM` | intact |
| FL2 .156, FL3 .186, Bad .180, HD_INT .233 | | alive | | intact |

---

### Task 1: Recover G_INT, HD_EXT, G_EXT (device commands only)

**Files:** none.

- [ ] **Step 1: G_INT, reactivate template, then restart**
```bash
curl -s 'http://192.168.23.201/cm?cmnd=Module%200'      # expect {"Module":{"0":"Shelly Plus 1PM"}} and the device restarts by itself
```
`Module` changes trigger an automatic restart. Wait 40 s, then:
```bash
curl -s 'http://192.168.23.201/cm?cmnd=Status%201' | grep -o '"Uptime":"[^"]*"\|"RestartReason":"[^"]*"'
curl -s 'http://192.168.23.201/cm?cmnd=Module'                                   # {"Module":{"0":"Shelly Plus 1PM"}}
curl -s 'http://192.168.23.201/cm?cmnd=Status%2010'                               # ENERGY and Switch1 present
curl -s 'http://192.168.23.201/cm?cmnd=Status%204' | grep -o '"Drivers":"[^"]*"' | grep -o '[!]*52'   # 52
curl -s 'http://192.168.23.201/cm?cmnd=Br%20tasmota._crons'                       # shows the old script's cron (spec "0 30 */3 * * *")
curl -s 'http://192.168.23.201/cm?cmnd=Power'                                     # {"POWER":"OFF"} (relay exists again)
```
If Berry is still `!52` after the automatic restart (the restart happened under 10 s uptime, so it may have counted as fast), wait 2 minutes and send one explicit `curl -s 'http://192.168.23.201/cm?cmnd=Restart%201'`, then re-verify.
- [ ] **Step 2: Functional check.** Toggle the relay once and back: `Power TOGGLE` twice with 5 s between, watch `Power` reply. Trip the garage inside PIR/reed and confirm the light reacts (that is the old `g_int.be` logic).
- [ ] **Step 3: HD_EXT** (wait until Step 1 is verified):
```bash
curl -s 'http://192.168.23.88/cm?cmnd=Restart%201'
```
After 40 s: `Status 4` shows `52`, `Br 1+1` answers `{"Br":"2"}`, `Br tasmota._crons` lists the old cron, `Status 10` still shows ENERGY.
- [ ] **Step 4: G_EXT** same as Step 3 on 192.168.23.119.
- [ ] **Step 5: Record** the three verifications (uptime, Drivers, crons) in `.superpowers/sdd/progress.md`.

---

### Task 2: `tools/fleet-check.sh` — one-command fleet health sweep

**Files:**
- Create: `tools/fleet-check.sh`
- Modify: `devices.tsv` (add the DHCP-discovered IPs with a comment), `Makefile` (`fleet` target), `README.md` (one line)

**Interfaces:**
- Produces: `./tools/fleet-check.sh [ip-or-name ...]`; with no args sweeps every IP in `devices.tsv` plus `FLEET_EXTRA` env var. Prints one row per device; exits 1 if any device shows Berry `!52`, a fallback module, or zero configured GPIOs.

- [ ] **Step 1: Write the script**
```bash
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
  gpios=$(cm "$ip" GPIO | grep -o '"GPIO[0-9]*":{"[0-9]*":' | grep -vc '"0":')
  read -r uptime reason < <(cm "$ip" Status%201 | grep -o '"Uptime":"[^"]*"\|"RestartReason":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
  flag=''
  [[ $berry != 52 ]] && flag='BERRY-DEAD'
  [[ $module == 1:* ]] && flag="$flag MODULE-FALLBACK"
  [[ ${gpios:-0} -eq 0 ]] && flag="$flag NO-GPIO"
  [[ -n $flag ]] && bad=1
  printf '%-10s %-16s %-6s %-22s %-5s %-12s %s %s\n' "$name" "$ip" "${berry:-?}" "$module" "${gpios:-?}" "$uptime" "$reason" "$flag"
done
exit $bad
```
Note on the GPIO count: Tasmota's `GPIO` reply is `{"GPIO4":{"192":"Switch1"},...,"GPIO0":{"0":"None"}}`; entries whose inner key is `"0"` are unassigned, so the count excludes them.
- [ ] **Step 2: `devices.tsv`**: add a comment line `# DHCP devices seen 2026-09-16 on 192.168.23.x (may change): FL2 .156, FL3 .186, Bad .180, HD_INT .233, HD_EXT .88, G_EXT .119, G_INT .201, G_TREPPE .60, AnnaUhr .124, PARK2 .144, WZ3 .228` and fill those IPs into the matching rows (FL2, FL3, BAD, HD_INT, HD_EXT, G_EXT, G_INT, G_TREPPE, AnnaUhr, PARK2). Filling an IP enrols the device in `deploy.sh --all`, so ALSO change `deploy.sh`'s `--all` to require an explicit `DEPLOY_ALL=yes` env var (one `[[ ${DEPLOY_ALL:-} == yes ]] || { echo "refusing --all without DEPLOY_ALL=yes"; exit 1; }` at the top of the `--all` branch). These devices run old scripts; a blanket deploy would replace them.
- [ ] **Step 3: Makefile**: `fleet:` target running `./tools/fleet-check.sh`; add to `.PHONY`. README: one line under Workflow: `make fleet            # health sweep: Berry alive? module/GPIO intact?`.
- [ ] **Step 4: Verify**: `chmod +x tools/fleet-check.sh; ./tools/fleet-check.sh` before Task 1 must flag G_INT (`BERRY-DEAD MODULE-FALLBACK NO-GPIO`), HD_EXT and G_EXT (`BERRY-DEAD`) and exit 1; after Task 1 it must be clean and exit 0. `bash -n tools/fleet-check.sh deploy.sh`.
- [ ] **Step 5: Commit**: `feat(tools): fleet-check.sh health sweep; register DHCP IPs; guard deploy --all`.

---

### Task 3: Raise the boot-loop offset fleet-wide (`SetOption36 5`)

**Files:** none (device settings). Document in `README.md` under a new "Device settings we rely on" line.

Rationale: with `SetOption36 1`, Tasmota disables Berry after 4 consecutive restarts under 10 s uptime and wipes GPIOs after 5. A Wi-Fi-triggered crash loop of a minute is enough. `SetOption36 5` moves those thresholds to 8 and 9 consecutive fast restarts (still protection against a genuine boot loop, which recovers after ~90 s instead of ~40 s). Range is 0..200; 0 disables the protection entirely, which we do NOT want.

- [ ] **Step 1: Apply** to every reachable ESP32 device (list from `tools/fleet-check.sh` output plus HZ_WW .74, HD .92, GD .91, PlugUD .31, PV_A .56, HZ_DG .70, HZ_DGB .72). Per device: `curl -s "http://IP/cm?cmnd=SetOption36%205"` → reply `{"SetOption36":5}`. No restart needed (`SetOption36` is read at boot; the value persists in settings).
- [ ] **Step 2: Verify** with a loop over the same IPs: `curl -s "http://IP/cm?cmnd=SetOption36"` all reply `5`.
- [ ] **Step 3: Document** in README: "All ESP32 devices run `SetOption36 5` (boot-loop offset). Re-apply after a settings reset." Commit: `docs: record SetOption36 5 fleet setting`.

---

### Task 4: Pin down the 06:00 trigger (evidence, owner-driven)

**Files:** `docs/superpowers/plans/2026-09-16-fleet-recovery-after-crash-loop.md` (append findings under "What happened").

- [ ] **Step 1 (owner):** In the FRITZ!Box UI (http://192.168.22.1, System > Ereignisse, filter WLAN and System), read the entries between 2026-09-11 05:55 and 06:05 local. Look for: "WLAN-Kanal geändert" / DFS, "Neustart", "Update", "Mesh". Paste the lines into this plan under "What happened".
- [ ] **Step 2 (optional, owner):** If the log shows a scheduled Wi-Fi channel optimisation or nightly Wi-Fi off/on at 06:00, disable it (WLAN > Funkkanal: fixed channel, and WLAN > Zeitschaltung off) or move it to a time when a restart storm matters less.
- [ ] **Step 3 (optional):** Point all ESP32 devices at a syslog host so the next event is captured: pick a host that is always on (the MQTT broker host 192.168.22.5 if it runs rsyslog on 514/udp; test with `logger -n 192.168.22.5 -P 514 test`). Then per device `Backlog LogHost 192.168.22.5; LogPort 514; SysLog 2`. Skip if no syslog host exists; do not run rsyslog on a laptop.
- [ ] **Step 4:** Decode one crash for the record if feasible: `Status 12` call chains from FL2 (`IllegalInstruction`, EPC) and G_INT (`Cp7Dis`, EPC `40090354`) can be symbolised against the `tasmota32solo1` 15.1.0 build map if Tasmota publishes one for that release (`http://ota.tasmota.com/tasmota32/release/`); if not, skip and note it.

---

### Out of scope, follow-up plan

- Migrating FL2/FL3/Bad/HD_INT/HD_EXT/G_EXT/G_INT/G_TREPPE from their old self-contained scripts to the repo versions (`muh_lib.be` based). Those repo versions have never run on hardware; needs a per-device review + `deploy.sh` with readback, one device at a time. `Bad` currently has no `bad.be` on the device at all.
- Script header comments claim wrong static IPs (copy-paste); the devices are DHCP.

## Self-Review

- Recovery for the three dead devices: Task 1 (with the G_INT-specific `Module 0`). Visibility: Task 2. Resilience: Task 3. Root-cause capture: Task 4. Deploying new scripts deliberately excluded and stated.
- Placeholders: none. Names: `tools/fleet-check.sh`, `make fleet`, `DEPLOY_ALL=yes`, `SetOption36 5`.
