# Tasmota Fleet Safety and Security Hardening — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the holes found on 2026-09-16 without breaking the automation: any LAN client can currently command every device (anonymous MQTT publish, unauthenticated HTTP API and web UI), firmware ships the Wi-Fi password in cleartext, OTA is plain HTTP without integrity checks, and one device (3EM) still restarts itself on a failed gateway ping.

**Architecture:** Defence in layers, cheapest first. (1) Broker: per-client credentials + ACLs so a device may only publish its own topics and subscribe to the `muh/` topics it uses; anonymous off; the tasmota-scripts tooling gets its own read-mostly account. (2) Devices: web password on every device, HTTP API kept but authenticated (all tooling in tasmota-scripts learns a `TASMOTA_AUTH` credential from one git-ignored env file), MQTT credentials per device, `SetOption` hygiene. (3) Firmware: credentials no longer baked in (devices keep them in settings; the build only ships the SSID), OTA images signed/verified by sha256 in the manifest before `Upgrade`, and hardened defaults compiled in. (4) Network: Tasmota devices moved to their own VLAN/SSID with the FRITZ!Box firewall allowing only broker, NTP, syslog, OTA host and DNS. Each layer is a task and works alone.

**Tech Stack:** Mosquitto 2.0.21 on 192.168.22.5, Tasmota 15.x (fork profiles), bash tooling in tasmota-scripts, FRITZ!Box 5530.

## Global Constraints

- Nothing in this plan may make a device unreachable for the automation: every credential change is applied device by device and verified with `make fleet` before the next.
- All secrets live in git-ignored files: `~/repo/tasmota/muh/build.env` (already), new `~/repo/tasmota-scripts/.fleet.env` (`TASMOTA_WEB_USER`, `TASMOTA_WEB_PASS`, `MQTT_ADMIN_USER`, `MQTT_ADMIN_PASS`). `.gitignore` both.
- The MQTT topic layout stays exactly as today: devices publish `tasmota/tele|stat/<topic>/…`, subscribe `tasmota/cmnd/<topic>/…` and `tasmota/cmnd/tasmotas/…`, plus the `muh/…` application topics (`muh/sensors/…`, `muh/lights/…`, `muh/portal/…`).
- Berry scripts are not changed except where a device restarts itself on network loss (3EM rules).
- Order of tasks is the order of risk reduction; stop after any task and the fleet is still consistent.

## Findings (2026-09-16, read-only sweep of 22 devices)

| Finding | Evidence | Risk |
|---|---|---|
| Broker accepts anonymous publish and subscribe | `mosquitto_pub -h 192.168.22.5 -t muh/probe/anon` succeeded with no credentials; 62 retained `tasmota/discovery/#` messages readable | Anyone on the /22 (guest Wi-Fi client, compromised IoT box, laptop malware) can publish `tasmota/cmnd/tasmotas/Restart 1`, `Power`, `Upgrade`, `Reset` to every device |
| No web authentication | `GET http://<device>/` returns 200 and `/cm?cmnd=…` accepted commands all day; `WebPassword` reports `****` but is not enforced | Same as above over HTTP, plus settings dump and firmware upload (`/ufsu`, `/u2`) |
| MQTT without TLS, default user `DVES_USER`, one shared password | `MqttTLS 0` on all; 8883 closed on broker | Credentials and payloads sniffable; one password for everything |
| Wi-Fi password compiled into firmware | `STA_PASS1` from `MUH_WIFI_PASS`; images on http://192.168.22.11/tasmota/ and in GitHub Release assets | Anyone who can fetch an image gets the Wi-Fi PSK |
| OTA over plain HTTP, no integrity check | `OtaUrl http://192.168.22.11/tasmota/…` | A LAN attacker who can spoof .11 (ARP) can push arbitrary firmware; Tasmota only checks the image magic |
| Flat network | Devices on 192.168.20.0/22 with everything else (laptops, servers, FRITZ!Box) | No blast-radius limit |
| 3EM (ESP8266) restarts on ping failure via Rule2 | `MUH/3EM.md` | Same class as the Sep 11 incident; on ESP8266 boot-loop protection disables rules, not Berry |
| Discovery/tele payloads reveal MAC, IP, topic, module | retained `tasmota/discovery/<MAC>/config` | Reconnaissance; harmless once the broker requires auth |
| `HTTP_API 1`, `Webserver 2` (admin) on all | `Status 0` | Needed by tooling; must be authenticated, not disabled |
| Emulation 2 (Hue) on Dimmer2B | `Emulation` | Unauthenticated Hue emulation on port 80/1900; disable unless used |

---

### Task 1: Broker authentication and ACLs (biggest win, no device downtime)

**Files:** on 192.168.22.5: `/etc/mosquitto/conf.d/muh.conf`, `/etc/mosquitto/passwd`, `/etc/mosquitto/acl`. In tasmota-scripts: `.fleet.env.example`, `.gitignore`, `tools/mqtt-env.sh` (sourced helper exporting `MOSQ_ARGS`).

Precondition: shell access to 192.168.22.5 (SSH host key currently mismatched from this machine: `Host key verification failed`; owner to confirm the host and provide access or run the steps there).

- [ ] **Step 1: Accounts.** One account per device (`user = DeviceName`, random 24-char password) plus `muh-tools` (this machine, tasmota-scripts), `muh-ha` (Home Assistant / whatever consumes `muh/…`), `muh-admin`. Generate with `openssl rand -base64 18`, store the list ONLY in `.fleet.env`-style files on the admin machine (`~/repo/tasmota-scripts/.fleet-mqtt-passwords` git-ignored) and `mosquitto_passwd -b /etc/mosquitto/passwd <user> <pass>` on the broker.
- [ ] **Step 2: ACL file** (`/etc/mosquitto/acl`), pattern-based so new devices need no edit:
```
# each device: own tasmota topics + the muh application topics
pattern readwrite tasmota/tele/%u/#
pattern readwrite tasmota/stat/%u/#
pattern read      tasmota/cmnd/%u/#
pattern read      tasmota/cmnd/tasmotas/#
pattern readwrite tasmota/discovery/#
pattern readwrite muh/#
pattern read      $SYS/broker/uptime

user muh-tools
topic readwrite #

user muh-admin
topic readwrite #
```
  Note the `%u` pattern requires the MQTT username to equal the device's `Topic`. Today `Topic` is `tasmota_<MAC6>` (e.g. `tasmota_A3338C`), not the DeviceName. Either set `Topic <DeviceName>` on each device (changes all its MQTT paths and the retained discovery; the Berry scripts in this repo publish under `muh/…` and do not depend on `Topic`, but Home Assistant discovery does) or use the MAC-topic as the username. Decision for this plan: **username = current Topic (`tasmota_XXXXXX`)**, so nothing else moves. Get the list with `tools/fleet-cmd.sh Topic`.
- [ ] **Step 3: Broker config** (`/etc/mosquitto/conf.d/muh.conf`):
```
listener 1883 0.0.0.0
allow_anonymous false
password_file /etc/mosquitto/passwd
acl_file /etc/mosquitto/acl
```
  Before restarting mosquitto, set the credentials on every device (Task 1 Step 4) so they reconnect cleanly; the broker restart itself drops all sessions once.
- [ ] **Step 4: Device credentials**, one device at a time via tasmota-scripts: `tools/fleet-cmd.sh "Backlog MqttUser <topic>; MqttPassword <pass>" <name>`; the device reconnects within seconds; verify with `tools/fleet-cmd.sh MqttCount <name>` incrementing and `mosquitto_sub -u muh-tools -P … -t tasmota/tele/<topic>/LWT -C 1` showing `Online`.
- [ ] **Step 5: Tooling**: `tools/mqtt-env.sh` exports `MOSQ_ARGS="-h 192.168.22.5 -u $MQTT_TOOLS_USER -P $MQTT_TOOLS_PASS"` from `.fleet.env`; update the README examples (`mosquitto_sub $MOSQ_ARGS …`).
- [ ] **Step 6: Verify**: anonymous `mosquitto_pub` now fails (`Connection Refused: not authorised`); a device account cannot publish to another device's `cmnd` (`mosquitto_pub -u tasmota_A3338C -P … -t tasmota/cmnd/tasmota_9521A4/Power -m 0` is refused, check broker log); `make fleet` clean; the `muh/sensors/HZ_WW/…` retained values keep updating hourly.

---

### Task 2: Web authentication on every device, tooling carries the credential

**Files:** tasmota-scripts: `.fleet.env.example`, `.gitignore`, `deploy.sh`, `tools/fleet-check.sh`, `tools/fleet-cmd.sh`, `README.md`.

- [ ] **Step 1: Tooling first.** Add to the top of each script: `[[ -f .fleet.env ]] && { set -a; . .fleet.env; set +a; }` and build the auth query `AUTH="user=${TASMOTA_WEB_USER:-admin}&password=${TASMOTA_WEB_PASS:-}"`; append `&$AUTH` (or `?$AUTH`) to every `/cm` and `/ufsd`/`/ufsu` URL when `TASMOTA_WEB_PASS` is non-empty (`deploy.sh` already has the `TASMOTA_AUTH` hook; unify on the new variables). URL-encode the password (`python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))'`).
- [ ] **Step 2: Set the password** device by device: `tools/fleet-cmd.sh "WebPassword <pass>" <name>` (the reply is masked). Immediately verify `curl -s -o /dev/null -w '%{http_code}' http://<ip>/` → `401`, and `tools/fleet-cmd.sh DeviceName <name>` (now authenticated) → answers. Then next device.
- [ ] **Step 3: Berry on-device tooling** is unaffected (Berry runs inside). `deploy.sh` upload verification must still pass with auth (the readback GET carries the credential).
- [ ] **Step 4: Verify**: `make fleet` (authenticated) clean; unauthenticated `curl http://<ip>/cm?cmnd=Status` → `401` on all devices.

---

### Task 3: Take the Wi-Fi password out of the firmware

**Files:** `~/repo/tasmota`: `tasmota/user_config_override.h`, `platformio_muh.ini`, `muh/build.env.example`, `.github/workflows/muh-build.yml`, `README-MUH.md`.

Rationale: every device already holds SSID/password in its settings; the compiled default only matters on a settings reset. Keeping the SSID compiled in is harmless; the PSK is not. Boot-loop protection level 6+ resets settings, so a device that loses its PSK falls back to Wi-Fi manager AP mode (`WifiConfig 2`), which is recoverable by hand and does not leak the PSK to anyone who downloads an image.

- [ ] **Step 1:** In `user_config_override.h` keep `STA_SSID1 MUH_WIFI_SSID`, remove `STA_PASS1`, the `MUH_WIFI_PASS` `#error` and its `static_assert`; set `#undef WIFI_CONFIG_TOOL / #define WIFI_CONFIG_TOOL WIFI_MANAGER` so a device without credentials opens its config AP instead of rebooting.
- [ ] **Step 2:** Remove `-DMUH_WIFI_PASS` from `platformio_muh.ini` `[muh]`, `MUH_WIFI_PASS` from `build.env.example`, the workflow `env:` and its guard loop, and from README-MUH. Delete the GitHub secret after the first green build.
- [ ] **Step 3:** Rebuild `tasmota32solo1-muh`, `strings build/tasmota32solo1-muh/tasmota32solo1-muh.bin | grep -c Wombat` → 0. Commit `build: firmware no longer embeds the Wi-Fi password`.
- [ ] **Step 4 (owner):** rotate the Wi-Fi PSK on the FRITZ!Box and on the devices (`tools/fleet-cmd.sh "Password1 <new>"` device by device; devices reconnect within ~10 s; do the AP change last), since the old PSK is in git history of a private repo and in every image built today.

---

### Task 4: OTA integrity: verify before upgrade, images not world-readable

**Files:** tasmota-scripts: `tools/fleet-upgrade.sh`; 192.168.22.11: nginx config.

Tasmota cannot verify signatures itself (no signed-OTA support on ESP32 in 15.x), so the check happens in the tool that triggers the upgrade, and the transport is protected by nginx basic auth (Tasmota's `OtaUrl` supports `http://user:pass@host/…`).

- [ ] **Step 1: nginx basic auth** on `/tasmota/`: `apt-get install apache2-utils; htpasswd -c /etc/nginx/.htpasswd ota`; add `auth_basic "ota"; auth_basic_user_file /etc/nginx/.htpasswd;` to the `location /tasmota/` block; reload. `muh/build.sh --publish` still rsyncs over SSH, unaffected.
- [ ] **Step 2: `OtaUrl` with credentials** via `tools/fleet-cmd.sh "OtaUrl http://ota:<pass>@192.168.22.11/tasmota/<profile>.bin"` per group (same group list as the build plan's Task 5).
- [ ] **Step 3: `tools/fleet-upgrade.sh <name>`**: reads the device's `OtaUrl`, fetches `manifest.txt` from the OTA host, downloads the image, compares sha256 with the manifest line for that file, refuses on mismatch, then sends `Upgrade 1`, waits for reboot, verifies `Status 2` version/`BuildDateTime` changed and `make fleet` row is healthy. One device per invocation; never `tasmotas` group.
- [ ] **Step 4: Verify**: tamper test on a scratch file (edit one byte of a copy on the host, point a test manifest at it) → script refuses.

---

### Task 5: Device hygiene settings (per device, reversible)

- [ ] `Emulation 0` on Dimmer2B unless Hue emulation is in use (ask owner).
- [ ] `SetOption3 1` (MQTT on) is fine; `SetOption19 0` (no HA autodiscovery) only if Home Assistant is not using it (ask owner); otherwise keep.
- [ ] `WebServer 2` stays (tooling needs `/cm`); `SetOption36 5` already set; `SetOption65 1` (disable fast power-cycle reset) on devices that are power-cycled by a wall switch (FL2/FL3/Bad-style light circuits) so five quick toggles cannot factory-reset them — check with the owner which devices are on switched circuits.
- [ ] 3EM: replace Rule2's `Ping…Reachable=false DO Restart 1` with a rule that only restarts if uptime > 120 s: `ON Ping#192.168.22.1#Reachable=false DO Backlog0 Delay 0; Var1 %uptime% ENDON` is awkward in rules; simplest: `ON Ping#192.168.22.1#Reachable=false DO IF (%uptime% > 120) Restart 1 ENDIF ENDON` (the fork build has `SUPPORT_IF_STATEMENT` and `USE_EXPRESSION`; stock `tasmota-4M` does not, so this waits for the 3EM to run `tasmota-muh-3em`). Update `MUH/3EM.md`.
- [ ] Record every setting in the device's `.md` file so `Backlog` re-provisioning stays complete.

---

### Task 6: Network segmentation (owner-driven, FRITZ!Box)

- [ ] **Step 1:** Create a dedicated IoT SSID/VLAN on the FRITZ!Box (or an extra AP) and move Tasmota devices to it: `tools/fleet-cmd.sh "Backlog Ssid2 <iot-ssid>; Password2 <psk>"` first (devices try SSID1 then SSID2), then swap SSID1 later.
- [ ] **Step 2:** Firewall from the IoT segment: allow to 192.168.22.5:1883 (MQTT), 192.168.22.5:123 (NTP), 192.168.22.11:514/udp (syslog), 192.168.22.11:80 (OTA), DNS on 192.168.22.6:53; deny everything else including Internet (Tasmota needs no Internet once NTP is local; ESP8266 stock OTA URLs point at ota.tasmota.com and would stop working, intended).
- [ ] **Step 3:** Admin machine and Home Assistant reach the IoT segment through explicit rules (HTTP 80 to devices for tooling).
- [ ] **Step 4:** Verify with `make fleet` from the admin machine and one `mosquitto_sub $MOSQ_ARGS -t 'muh/#'` from Home Assistant's host.

---

### Task 7: Monitoring for the security posture

- [ ] Extend `tools/fleet-check.sh` with two columns: `AUTH` (`401` on unauthenticated GET = ok) and `MQTTUSER` (must not be `DVES_USER`), flagged like the existing health checks.
- [ ] Add a weekly `make fleet` run (cron on the admin machine or the OTA host) that mails/prints the table; anything flagged is a regression.

## Out of scope / not recommended

- MQTT TLS: Mosquitto can do it and Tasmota32 supports it, but certificate handling on 22 devices for a LAN-only broker adds fragility (clock dependence at boot, cert rotation) for little gain once the network is segmented and the broker requires auth. Revisit if devices ever cross an untrusted network.
- Disabling the HTTP API or web UI: the tooling depends on it; authentication is the right control.
- Signed firmware: not supported by Tasmota on ESP32 in 15.x.

## Self-Review

- Every finding maps to a task: anonymous broker → 1; open HTTP → 2; PSK in firmware → 3; OTA integrity → 4; 3EM self-restart, Hue, power-cycle reset → 5; flat network → 6; regression detection → 7.
- Each task ends with a verification that the automation still works (`make fleet`, retained sensor updates).
- Owner inputs needed: broker shell access (Task 1), whether Home Assistant uses discovery and Hue (Task 5), FRITZ!Box VLAN capability (Task 6), PSK rotation window (Task 3).
