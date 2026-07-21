# Tasmota Scripts

Berry scripts and device configs for the Tasmota-based home automation setup.

## Layout

- `MUH/` — Berry scripts, one per device, dispatched by `MUH/autoexec.be`
- `MUH/muh_lib.be` — shared helpers (dark detection, timed relays, MQTT state publishing)
- `*.md` — per-device-class console configs (templates, calibration, rules)
- `devices.tsv` — device → IP → scripts map used by `deploy.sh`
- `tools/be-check.be` — offline syntax/global check for all Berry scripts
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
make check            # compile-check every MUH/*.be (needs standalone berry)
./deploy.sh WC        # upload autoexec.be + muh_lib.be + wc.be, restart WC
./deploy.sh --all     # same for every device with an IP in devices.tsv
```

Standalone `berry`: `git clone https://github.com/berry-lang/berry && make`,
put the binary on PATH (or `make check BERRY=/path/to/berry`).

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
| PV / PV_A / PV_B | pv*.be | ESP32 | Solar monitoring |
| HZ_WW | hz_ww.be | Plug | Warm-water heating control |
| BAD | bad.be | — | Bathroom |
| AnnaUhr | annauhr.be | ESP32 clock | Clock |

ESP8266 devices (Athom Plug V2 etc.) have no Berry — they use native Tasmota
rules documented in `Plugs.md`.
