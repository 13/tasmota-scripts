# Tasmota Scripts

Berry scripts and device configs for the Tasmota-based home automation setup.

## Layout

- `MUH/` — Berry scripts, one per device, dispatched by `MUH/autoexec.be`
- `MUH/muh_lib.be` — shared helpers (dark detection, timed relays, MQTT state publishing, Wi-Fi watchdog)
- `*.md` — per-device-class console configs (templates, calibration, rules)
- `devices.tsv` — device → IP → scripts map used by `deploy.sh`
- `tools/be-check.be` — offline strict-mode compile check + cron-spec lint for all Berry scripts
- `tools/test_env.be` + `tools/test_*.be` — offline behaviour tests (needs standalone berry)
- `z-old/` removed — history lives in git

## How a device boots

1. Tasmota runs `autoexec.be`.
2. `autoexec.be` reads `DeviceName`, loads `muh_lib.be`, then the device's
   script from its `DEVICE_SCRIPTS` map (HD/GD get `gdhd.be`, which loads
   `hd.be`/`gd.be` on top).
3. Top-level `var`/`def` in loaded files are globals, shared across scripts —
   that's how device scripts use `log()`, `DEVICENAME` and the lib helpers.

## Workflow

```sh
make check            # strict compile + cron-spec lint of every MUH/*.be (needs standalone berry)
make test             # offline behaviour tests for muh_lib and hz_ww
make fleet            # health sweep: Berry alive? module/GPIO intact? BUILD vs promoted OTA version
tools/fleet-cmd.sh '<cmd>' [names]   # send a Tasmota command to devices
tools/berry-inventory.sh             # read-only: back up every device's *.be, report map drift
./deploy.sh WC        # upload autoexec.be + muh_lib.be + wc.be, restart WC
./deploy.sh --autoexec-only FL3    # upload only autoexec.be + muh_lib.be
DEPLOY_ALL=yes ./deploy.sh --all   # same for every device with an IP in devices.tsv
tools/rollback.sh FL3               # no timestamp: lists backups/FL3/* (oldest first), exits 1
tools/rollback.sh FL3 20260916-153000   # restore that backup's *.be, delete extras, restart
```

`deploy.sh` backs a device up (`tools/berry-inventory.sh`) before uploading,
and — unless `--no-verify` — clears the device's retained
`muh/berry/<KEY>/status` *before* uploading anything, uploads `muh_lib.be`,
then the device's own script(s), then `autoexec.be` **last** (old loaders
ignore `muh_lib.be`; the new canonical loader only takes over once
`autoexec.be` lands), restarts, then polls the status for up to 90s
(`$DEPLOY_VERIFY_TIMEOUT`) to confirm the new `autoexec.be` actually loaded.
On any failure it prints the matching `tools/rollback.sh <name> <timestamp>`
command — `tools/rollback.sh <name>` with no timestamp always requires one
explicitly and lists what's on disk instead of guessing "the newest".

Standalone `berry`: `git clone https://github.com/berry-lang/berry && make`,
put the binary on PATH (or `make check BERRY=/path/to/berry`).

## Load status

Every device publishes a retained MQTT message on `muh/berry/<KEY>/status` when
MQTT connects (or immediately if already connected), where `<KEY>` is the
upper-case device name (e.g., `BAD` for DeviceName `Bad`). The message is
retained so a consumer can check the latest state without waiting for a reboot.

**Example: success**
```json
{
  "lib": true,
  "script": "wc.be",
  "ok": true,
  "err": "",
  "device": "WC",
  "autoexec": "2026.09.16-1",
  "time": "2026-09-16T15:30:45",
  "uptime": 86400
}
```

**Example: failure** (device script load error; the library still loaded)
```json
{
  "lib": true,
  "script": "gdhd.be",
  "ok": false,
  "err": "gdhd.be: load_error: hd.be: key_error: some_undefined_key",
  "device": "HD",
  "autoexec": "2026.09.16-1",
  "time": "2026-09-16T15:30:45",
  "uptime": null
}
```

**Field meanings:**
- `lib` — whether `muh_lib.be` loaded successfully
- `script` — device script name from DEVICE_SCRIPTS, or "" for library-only devices
- `ok` — true only if both lib and script loaded successfully
- `err` — empty on success, or a nested error chain showing which file failed and why
- `device` — DeviceName (for filtering/tracking in a consumer)
- `autoexec` — version of the loader that published this status
- `time` — local time (requires NTP sync)
- `uptime` — seconds since last reboot (nil if RTC is not yet synced)

**Node-RED recipe:** Catch load failures and trigger notifications
```
[
  {
    "id": "mqtt-in",
    "type": "mqtt in",
    "topic": "muh/berry/+/status",
    "qos": "1",
    "datatype": "json",
    "outputs": 1
  },
  {
    "id": "switch-ok",
    "type": "switch",
    "property": "payload.ok",
    "propertyType": "msg",
    "rules": [{"t": "eq", "v": "false", "vt": "bool"}],
    "checkall": "true"
  },
  {
    "id": "notify",
    "type": "notification",
    "format": "msg.payload.device + \": \" + msg.payload.err"
  }
]
```

**Combining with liveness checks:** A retained `ok:true` message survives if a
device reboots or goes offline after a successful load, so combine with
`tasmota/tele/<Topic>/LWT` to detect dead devices. To clear a retired device's
status: `mosquitto_pub -h 192.168.22.5 -t muh/berry/<KEY>/status -r -n`.

**Runtime errors:** Exceptions raised later inside rules, crons, or drivers are
not captured in MUH_STATUS. They appear as `BRY: Exception>` lines in
`/var/log/tasmota/<device-ip>.log` on the central log server (192.168.22.11).

## One loader

`MUH/autoexec.be` is identical on every Berry device (enforced by version
checking in deploy.sh and fleet-check.sh). The device map lives in
`DEVICE_SCRIPTS` inside autoexec.be and must match `devices.tsv`. `make check`
runs `tools/check-map.sh` to verify this. Drift is caught at deploy time by
`tools/fleet-check.sh`, which flags `AUTOEXEC-DRIFT`, `LOAD-ERROR`, and
`LOAD-MISSING`.

## Device inventory

| Device | Script | Hardware | Purpose |
|---|---|---|---|
| HD | gdhd.be + hd.be | ESP32 + I2S audio + fingerprint | House door lock/unlock, LED status, chimes |
| GD | gdhd.be + gd.be | ESP32 + I2S audio + fingerprint + LD2410 | Garage door lock/unlock, garage light |
| HD_INT | hd_int.be | Shelly Plus 2PM + addon | Hall + garage light on motion/reed |
| HD_EXT | hd_ext.be | Shelly Plus 1PM | Outside light on motion when dark |
| G_INT | g_int.be | Shelly Plus 1PM | Garage inside light on door/motion |
| G_EXT | g_ext.be | Shelly Plus 1PM | Garage outside light |
| G_TREPPE | g_treppe.be | Shelly Plus1PMMini | Stair light on PIR/reed + lux |
| FL2 / FL3 | fl2.be / fl3.be | Shelly Plus 1PM | Hallway lights, state publishing |
| WC | wc.be | Shelly Plus1PMMini | WC light, state publishing |
| PlugUD | plugud.be | Athom Plug V3 | DVB-T antenna power follows device pings |
| PARK1 / PARK2 | park1.be / park2.be | ESP32 + SR04 + display | Parking distance display |
| PV / PV_A / SOLAR_EXT / WZ3 / HZ_DG / HZ_DGB | — | ESP32 / Plug | Library only (no device script) |
| HZ_WW | hz_ww.be | Plug | Warm-water heating control |
| BAD | — | — | Library only (no device script) |
| AnnaUhr | annauhr.be | ESP32 clock | Clock |

ESP8266 devices (Athom Plug V2 etc.) have no Berry — they use native Tasmota
rules documented in `MUH/Plugs8266.md`.

## Device settings we rely on

- All ESP32 devices run `SetOption36 5` (boot-loop offset): Tasmota then needs 8
  consecutive restarts under 10 s uptime before it disables Berry, 9 before it
  wipes GPIOs. Default 1 let a one-minute Wi-Fi crash loop on 2026-09-11 kill
  Berry on three devices. Re-apply after a settings reset; `make fleet` shows
  the damage if it happens again.
