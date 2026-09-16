# Canonical autoexec.be with Load Status — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One `MUH/autoexec.be`, byte-identical on every Berry device, that loads `muh_lib.be` and the device script, records the outcome in a global `MUH_STATUS = {lib, script, ok, err}`, and publishes it retained on `muh/berry/<KEY>/status`, so Node-RED gets the exact error text instead of `loaded=false`. Device lookup is case-insensitive (fixes `Bad` vs `BAD`). Drift becomes visible in `make fleet` and fails it.

**Architecture:** `autoexec.be` no longer calls Tasmota's `load()` (it swallows every error and returns `false`); it compiles and runs files itself inside `try`, so the exception type and message end up in `MUH_STATUS.err`. The device map uses upper-case keys; `KEY = string.toupper(DeviceName)` is also the topic segment. Publishing happens on `mqtt#connected` (autoexec runs before MQTT is up) and immediately if already connected. `deploy.sh` gains `--autoexec-only` (push the loader and library, keep whatever device script runs today), backs up device files first, and verifies the retained status after the restart. A consistency check ties `devices.tsv` to the map.

**Tech Stack:** Tasmota 15.x Berry (strict), standalone `berry` + `tools/test_env.be` harness, bash, mosquitto clients, broker 192.168.22.5.

## Global Constraints

- Topic: `muh/berry/<KEY>/status`, retained, `KEY` = upper-case DeviceName (`BAD`, `ANNAUHR`, `HZ_WW`).
- `MUH_STATUS` has exactly `lib` (bool), `script` (string, `""` = library only), `ok` (bool), `err` (string, `""` when ok). The published JSON is `MUH_STATUS` plus metadata `device` (DeviceName as set), `autoexec` (version string), `time` (local time string), `uptime` (seconds or null before NTP sync).
- Keep the globals device scripts rely on: `DEVICENAME`, `log()`, `LOG_PREFIX`, `DEBUG`. `load_script()` is removed (only autoexec used it).
- **Rollout never changes which device script runs**, unless a task says so explicitly: `--autoexec-only` keeps the on-device script; map values must equal the filename that runs today.
- Device commands one device at a time; door controllers (HD, GD) last.
- `make check` and `make test` must pass after every task.

## Facts (2026-09-16)

- Nine different `autoexec.be` variants on 12 Berry devices; only HD, GD, HZ_WW run the repo file (md5 `5f5f3f29`). Older variants use `if/elif` chains with a lowercase `devicename` global and `var loaded = false` (never set true).
- `Bad` (192.168.23.180): DeviceName `Bad`, all maps use `BAD` → "Unknown device", and there is no `bad.be` on the device: it runs no script.
- `PARK2` runs `park.be`; the repo maps `PARK2 → park2.be`.
- `PV_A`, `SOLAR_EXT`, `WZ3`, `HZ_DG`, `HZ_DGB` have Berry but no `.be` files. `PV_A` has a repo `pv_a.be` that is not on the device. `PV_B → pv_b.be` does not exist in the repo.
- Tasmota `load()` (`lib/libesp32/berry_tasmota/src/embedded/tasmota_class.be` ~560–600): prefixes `/`, returns `false` for a missing file, prints `BRY: failed to load …` / `BRY: failed to run compiled code …` and returns `false` on errors; it never raises. The current repo autoexec wraps it in `try` and therefore always reports success. `gdhd.be` loads `hd.be`/`gd.be` with `load()` too.
- Berry on the device has `import path` (`path.exists`), `compile(f, "file")`, `mqtt.connected()`; `tasmota.rtc()` returns `utc`, `local`, `restart`. `mqtt#connected` rules are already used in `gd.be`.
- Standalone berry has `os.chdir`, no `path` module (needs a stub).
- Old self-contained device scripts re-declare names that `muh_lib.be` defines (`var DARK_OFFSET`, `def is_dark`). Berry allows re-declaring a global in a later compile unit (the hz_ww harness already relies on this), so loading `muh_lib.be` first does not break them; the old script's definitions win.

## Device map decisions (defaults; Task 2 confirms each against the device)

| KEY | map value | why |
|---|---|---|
| HD, GD | `gdhd.be` | unchanged |
| HZ_WW | `hz_ww.be` | unchanged |
| FL2, FL3, G_EXT, G_INT, HD_EXT, HD_INT, G_TREPPE, WC | `<name>.be` | same filename on device (old content kept by `--autoexec-only`) |
| ANNAUHR | `annauhr.be` | unchanged |
| PLUGUD | `plugud.be` | unchanged |
| PARK1 | `park1.be` | offline, unchanged |
| PARK2 | `park2.be` **after** renaming the device file, or `park.be` | Task 2 checkpoint |
| BAD | `""` | nothing runs today; enabling `bad.be` is a separate decision |
| PV, PV_A, SOLAR_EXT, WZ3, HZ_DG, HZ_DGB | `""` | Berry without device script today (`pv.be`/`pv_a.be` stay in the repo, not enabled) |
| PV_B | removed | `pv_b.be` does not exist |

---

### Task 1: `tools/berry-inventory.sh` (read-only) and backups

**Files:** Create `tools/berry-inventory.sh`; modify `.gitignore` (`backups/`), `README.md`.

- [ ] **Step 1: Script.** For every device in `devices.tsv` with an IP plus `$FLEET_EXTRA`: skip devices whose `Status 4` has no Berry driver (`52` absent or `!52` counts as "berry off"); download every `*.be` from `/ufsd?dir=/` into `backups/<DeviceName>/<YYYYmmdd-HHMMSS>/`; print one row: `DEVICE IP KEY AUTOEXEC(same|drift|none) FILES MAP(script from repo MAP_AUTOEXEC) PRESENT(yes|no|-) SCRIPT(same|differs|repo-missing)` where SCRIPT compares the mapped on-device file with `MUH/<file>` (`cmp`). The repo map is parsed from `MUH/autoexec.be` with `grep -o '"[A-Z0-9_]*": *"[a-z0-9_.]*"'`. Upload helpers are not part of this script; it only reads.
- [ ] **Step 2: Verify** against the live fleet; expected today: HD/GD/HZ_WW `same`, others `drift`, Bad `KEY=BAD MAP=bad.be PRESENT=no`, PARK2 `MAP=park2.be PRESENT=no FILES=autoexec.be park.be`. Backups exist for every row.
- [ ] **Step 3: Commit**: `feat(tools): berry-inventory.sh (read-only, backs up device scripts)`.

---

### Task 2: Reconcile PARK2 (owner checkpoint)

- [ ] **Step 1:** `cmp backups/PARK2/<ts>/park.be MUH/park2.be`.
  - identical → rename on the device: `tools/fleet-cmd.sh 'UfsRename /park.be,/park2.be' PARK2`, verify `/ufsd?dir=/` lists `park2.be`; map stays `park2.be`.
  - different → **stop and ask the owner**: show `diff -u MUH/park2.be backups/PARK2/<ts>/park.be`. Options: (a) map `PARK2 → park.be` and `devices.tsv` scripts column `park.be`, import the device file as `MUH/park.be`; (b) deploy the repo `park2.be` (behaviour change, separate test).
- [ ] **Step 2:** record the decision in this plan's table and in `.superpowers/sdd/progress.md`.

**Decision (2026-09-16):** device `park.be` equals `MUH/park2.be` except for the `#- setup notes -#` header, so PARK2 gets a normal full `./deploy.sh PARK2` in Task 9 (uploads `park2.be`, map stays `park2.be`; the orphan `park.be` can be deleted afterwards). The old PARK2 loader waited 8 s before loading because `every_50ms` indexes `SR04-1/-2`, which exist only once the sensors have measured; driver exceptions are caught per call (`tasmota_class.be` `event()`), so this was log noise, not a crash. `MUH/park2.be` now returns early until both sensors exist.

---

### Task 3: Test harness support

**Files:** Create `tools/stubs/path.be`; modify `tools/test_env.be` (mqtt stub `connected()`), `tools/stubs/mqtt.be`.

- [ ] **Step 1:** `tools/stubs/path.be`
```berry
# Stub `path` module for offline tests: exists() by trying to open the file.
var m = module("path")
m.exists = def (f)
  try
    var fh = open(f, "r")
    fh.close()
    return true
  except ..
    return false
  end
end
return m
```
- [ ] **Step 2:** `tools/stubs/mqtt.be`: add `m.connected = def () return mqtt_connected_hook() end`; `tools/test_env.be`: `var mqtt_is_connected = false` and `def mqtt_connected_hook() return mqtt_is_connected end`.
- [ ] **Step 3:** `make test` still green (existing harnesses unaffected). Commit: `test: path stub and mqtt.connected in harness`.

---

### Task 4: Canonical `MUH/autoexec.be` (TDD)

**Files:** Create `tools/test_autoexec.be`, `tools/fixtures/autoexec/` (tiny `.be` files); replace `MUH/autoexec.be`; modify `Makefile` (`test` target), `tools/be-check.be` (seeds).

**Interfaces:**
- Globals: `AUTOEXEC_VERSION`, `LOG_PREFIX`, `DEBUG`, `DEVICE_SCRIPTS`, `DEVICENAME`, `DEVICE_KEY`, `MUH_STATUS`, `log(msg)`, `run_file(fname) -> ""|error text`, `publish_status()`, `muh_boot()`.

- [ ] **Step 1: Fixtures** in `tools/fixtures/autoexec/` (the test chdirs there, so these play the device filesystem): `muh_lib.be` (`var FIXTURE_LIB = true`), `good.be` (`var FIXTURE_GOOD = true`), `boom.be` (`raise "value_error", "boom at load"`), `syntax.be` (`def (` — compile error), `autoexec.be` is NOT copied: the test compiles `../../../MUH/autoexec.be` by path after chdir.
- [ ] **Step 2: Failing test** `tools/test_autoexec.be`. Pattern per case: set `DEVICENAME` via the stub (`TasmotaStub.cmd("DeviceName")` returns global `DEVICENAME`), override `DEVICE_SCRIPTS` after loading is not possible (the file defines it), so the test **rewrites the map after compiling but before `muh_boot()`**: compile autoexec with a flag global `MUH_AUTOEXEC_NO_BOOT = true` that makes the file skip its last block, then set `DEVICE_SCRIPTS = {...}`, call `muh_boot()`, `publish_status()`, and assert. Cases:
  1. `DEVICENAME="Good"`, map `{"GOOD":"good.be"}` → `MUH_STATUS == {lib:true, script:"good.be", ok:true, err:""}`, `FIXTURE_GOOD == true`.
  2. `"Bad"` (mixed case), map `{"BAD":"good.be"}` → ok, and published topic is `muh/berry/BAD/status`.
  3. script raises → `ok:false`, `err` contains `boom.be` and `boom at load`, `lib:true`.
  4. syntax error → `ok:false`, `err` contains `syntax.be`.
  5. missing file → `err == "missing.be: file not found"`.
  6. library missing (chdir to an empty dir) → `lib:false`, `err` mentions `muh_lib.be`, script not attempted.
  7. unknown device → `err` mentions `DEVICE_SCRIPTS`, `lib:false`.
  8. map value `""` → `lib:true, script:"", ok:true`.
  9. publish payload: retained flag true; JSON has keys `lib script ok err device autoexec time uptime`.
  10. connection handling: with `mqtt_is_connected = false`, running the boot block (without the NO_BOOT flag, in a fresh VM is not possible, so call the exported helper `muh_start()` that the file's last block calls) publishes nothing and registers `rules["mqtt#connected"]`; firing that rule publishes once. With `mqtt_is_connected = true`, `muh_start()` publishes immediately.
- [ ] **Step 3: Run**, expect failure (old autoexec has no `muh_boot`).
- [ ] **Step 4: Implement** `MUH/autoexec.be`:
```berry
#- autoexec.be — canonical MUH loader. Identical on every Berry device;
   deployed by tasmota-scripts (deploy.sh). Do not edit on a device.

   1. KEY = upper-case DeviceName, looked up in DEVICE_SCRIPTS
   2. runs muh_lib.be, then the device script ("" = library only)
   3. MUH_STATUS = {lib, script, ok, err}, published retained on
      muh/berry/<KEY>/status when MQTT is (or becomes) connected

   Tasmota's load() swallows errors and returns false, so files are
   compiled and run here to capture the exception text. -#

import string
import json
import mqtt

var AUTOEXEC_VERSION = "2026.09.16-1"
var LOG_PREFIX = "MUH:"
var DEBUG = true

# KEY (upper case) -> device script, "" = library only. Must match devices.tsv
# (tools/check-map.sh).
var DEVICE_SCRIPTS = {
  "HD": "gdhd.be",
  "GD": "gdhd.be",
  "HZ_WW": "hz_ww.be",
  "FL2": "fl2.be",
  "FL3": "fl3.be",
  "WC": "wc.be",
  "G_EXT": "g_ext.be",
  "G_INT": "g_int.be",
  "G_TREPPE": "g_treppe.be",
  "HD_EXT": "hd_ext.be",
  "HD_INT": "hd_int.be",
  "ANNAUHR": "annauhr.be",
  "PLUGUD": "plugud.be",
  "PARK1": "park1.be",
  "PARK2": "park2.be",
  "BAD": "",
  "PV": "",
  "PV_A": "",
  "SOLAR_EXT": "",
  "WZ3": "",
  "HZ_DG": "",
  "HZ_DGB": "",
}

def log(message)
  if DEBUG print(f"{LOG_PREFIX} {message}") end
end

# Compile and run a device file. Returns "" on success, otherwise
# "<file>: <exception>: <message>".
def run_file(fname)
  import path
  var p = string.startswith(fname, "/") ? fname : "/" + fname
  if !path.exists(p) && !path.exists(fname) return f"{fname}: file not found" end
  if !path.exists(p) p = fname end   # offline tests run in a plain directory
  try
    var code = compile(p, "file")
    code()
  except .. as e, m
    return f"{fname}: {e}: {m}"
  end
  return ""
end

var DEVICENAME = tasmota.cmd("DeviceName")["DeviceName"]
var DEVICE_KEY = string.toupper(DEVICENAME != nil ? DEVICENAME : "")
var MUH_STATUS = {"lib": false, "script": "", "ok": false, "err": ""}

def muh_boot()
  MUH_STATUS = {"lib": false, "script": "", "ok": false, "err": ""}
  DEVICE_KEY = string.toupper(DEVICENAME != nil ? DEVICENAME : "")
  if DEVICE_KEY == ""
    MUH_STATUS["err"] = "DeviceName is empty"
    return
  end
  if !DEVICE_SCRIPTS.contains(DEVICE_KEY)
    MUH_STATUS["err"] = f"{DEVICE_KEY} not in DEVICE_SCRIPTS"
    return
  end
  var script = DEVICE_SCRIPTS[DEVICE_KEY]
  MUH_STATUS["script"] = script
  var err = run_file("muh_lib.be")
  if err != ""
    MUH_STATUS["err"] = err
    return
  end
  MUH_STATUS["lib"] = true
  if script != ""
    err = run_file(script)
    if err != ""
      MUH_STATUS["err"] = err
      return
    end
  end
  MUH_STATUS["ok"] = true
end

def publish_status()
  var payload = MUH_STATUS.copy()
  var rtc = tasmota.rtc()
  payload["device"] = DEVICENAME
  payload["autoexec"] = AUTOEXEC_VERSION
  payload["time"] = tasmota.time_str(rtc["local"])
  payload["uptime"] = rtc["utc"] > 1600000000 ? rtc["utc"] - rtc["restart"] : nil
  mqtt.publish(f"muh/berry/{DEVICE_KEY != '' ? DEVICE_KEY : 'UNKNOWN'}/status", json.dump(payload), true)
end

def muh_start()
  log(f"AutoExec {DEVICENAME} ({AUTOEXEC_VERSION})")
  muh_boot()
  if MUH_STATUS["ok"]
    log(f"loaded lib + '{MUH_STATUS['script']}'")
  else
    log(f"LOAD FAILED: {MUH_STATUS['err']}")
  end
  tasmota.add_rule("mqtt#connected", def () publish_status() end)
  if mqtt.connected() publish_status() end
end

if !global.contains("MUH_AUTOEXEC_NO_BOOT") || !MUH_AUTOEXEC_NO_BOOT
  muh_start()
end
```
  Notes for the implementer: verify `global.contains` exists in this Berry (`import global` is needed on Tasmota: add `import global` at the top and use `global.contains("…")`); verify that assigning the global `MUH_STATUS` inside `muh_boot` works under strict mode (it is declared with `var` above, so it does); if `rtc["restart"]` is absent on an older build, fall back to `nil`. Run `make check` (strict) after implementing. Update `tools/be-check.be` seeds: remove `load_script`; add `AUTOEXEC_VERSION, DEVICE_KEY, MUH_STATUS, run_file, publish_status, muh_boot, muh_start`.
- [ ] **Step 5:** tests green, `make check` green. Commit: `feat(autoexec): canonical loader with MUH_STATUS and retained load status`.

---

### Task 5: `gdhd.be` reports sub-script errors

**Files:** Modify `MUH/gdhd.be` (the `load("hd.be")` / `load("gd.be")` block).

- [ ] **Step 1:** replace with
```berry
# Load the door-specific part; raise so autoexec records the real error
var sub = DEVICENAME == "HD" ? "hd.be" : DEVICENAME == "GD" ? "gd.be" : nil
if sub == nil
  raise "config_error", f"gdhd.be: unknown device {DEVICENAME}"
end
var sub_err = run_file(sub)
if sub_err != ""
  raise "load_error", sub_err
end
```
  (`run_file` is the autoexec global; `DEVICENAME` values are `HD`/`GD` exactly on these devices.)
- [ ] **Step 2:** add a case to `tools/test_autoexec.be` using fixtures `gdhd_like.be` that calls `run_file("boom.be")` and raises → `err` contains both `gdhd_like.be` and `boom at load`. `make check`, `make test` green. Commit: `fix(gdhd): propagate hd.be/gd.be load errors to MUH_STATUS`.

---

### Task 6: One map, checked

**Files:** Create `tools/check-map.sh`; modify `Makefile` (`check` runs it), `devices.tsv` (rows for SOLAR_EXT, WZ3, HZ_DG, HZ_DGB with IPs from the 2026-09-16 sweep and an empty scripts column; drop `PV_B`; `BAD`, `PV`, `PV_A` scripts column empty).

- [ ] **Step 1:** `tools/check-map.sh`: parse `DEVICE_SCRIPTS` from `MUH/autoexec.be`; parse `devices.tsv`; fail if (a) a tsv name's upper-case is not a map key, (b) a map key has no tsv row, (c) the map value differs from the first entry of the tsv scripts column (both empty is fine), (d) a mapped script does not exist in `MUH/`. Print each mismatch.
- [ ] **Step 2:** `deploy.sh` must accept an empty scripts column (only `autoexec.be` + `muh_lib.be`); fix the `IFS=, read -ra` path if it produces an empty array element.
- [ ] **Step 3:** `make check` green. Commit: `build: devices.tsv and autoexec map checked against each other`.

---

### Task 7: `deploy.sh --autoexec-only`, backup, status verification, rollback

**Files:** Modify `deploy.sh`; create `tools/rollback.sh`; modify `README.md`.

- [ ] **Step 1:** `deploy.sh [--autoexec-only] <device...>`:
  - before uploading: `tools/berry-inventory.sh <name>` (backup) — refuse to continue if the backup failed;
  - `--autoexec-only`: upload `autoexec.be` and `muh_lib.be` only;
  - after `Restart 1`: wait for the retained `muh/berry/<KEY>/status` to show `autoexec == <repo AUTOEXEC_VERSION>` and `uptime < 300` (or `uptime == null`), up to 90 s: `mosquitto_sub -h 192.168.22.5 -t "muh/berry/$KEY/status" -C 1 -W 5` in a loop; print `ok` or the `err` text and exit 1 on `ok == false` or timeout (MQTT credentials via `$MOSQ_ARGS` once the security plan lands).
- [ ] **Step 2:** `tools/rollback.sh <name> [timestamp]`: re-upload every `.be` from `backups/<name>/<timestamp or latest>/` with the same prime/readback logic as deploy, then `Restart 1`.
- [ ] **Step 3: Verify** with `tools/fixtures` not possible on hardware; dry-run by `bash -n`, and on FL3 in Task 9.
- [ ] **Step 4:** Commit: `feat(deploy): --autoexec-only, backup first, verify retained load status; rollback.sh`.

---

### Task 8: `make fleet` shows drift and load errors

**Files:** Modify `tools/fleet-check.sh`, `README.md`.

- [ ] Add columns `AUTOEXEC` (`same`/`drift`/`none`, sha256 of `/ufsd?download=/autoexec.be` vs repo) and `LOAD` (`ok`, or the first 40 chars of `err`, from one `mosquitto_sub -t 'muh/berry/+/status' -v -W 3` at start). Flags `AUTOEXEC-DRIFT` and `LOAD-ERROR` set the exit code (unlike `UPGRADE-PENDING`). Berry-off devices show `-`.
- [ ] Verify today: every drift device flagged, exit 1. Commit: `feat(fleet-check): AUTOEXEC drift and LOAD status columns`.

---

### Task 9: Rollout

- [ ] **Step 1: Canary FL3** (hallway light): `./deploy.sh --autoexec-only FL3` → status `ok`, retained message present, walk past the PIR, light works. `make fleet FL3`-row clean.
- [ ] **Step 2:** one at a time with `--autoexec-only` (names exactly as in `devices.tsv`): FL2, G_EXT, G_INT, HD_EXT, HD_INT, G_TREPPE, AnnaUhr, PlugUD, BAD, PV_A, SOLAR_EXT, WZ3, HZ_DG, HZ_DGB. After each: status `ok`, functional spot check where the device has a script.
- [ ] **Step 2b:** PARK2 with a full `./deploy.sh PARK2` (Task 2 decision; `--autoexec-only` would report `park2.be: file not found`). Afterwards delete the orphan: `curl 'http://192.168.23.144/ufsd?delete=/park.be'`.
- [ ] Rollback for any device uses the pre-rollout backup timestamp explicitly: `tools/rollback.sh <name> 20260916-182955` (the first inventory run; every later deploy creates a newer backup of the new files).
- [ ] **Step 3:** HZ_WW, then HD, then GD with a full `./deploy.sh <name>` (they already run repo scripts; this ships the new `gdhd.be`). After HD and GD: lock/unlock once each.
- [ ] **Step 4:** `make fleet` exit 0 (no drift, no load errors). `mosquitto_sub -t 'muh/berry/+/status' -v -W 3` lists every Berry device.

---

### Task 10: Node-RED consumer (docs)

- [ ] `README.md` section "Load status": topic, payload example, meaning of fields, and a Node-RED recipe: `mqtt in` on `muh/berry/+/status` (JSON) → `switch` on `msg.payload.ok` → notify with `msg.payload.device + ": " + msg.payload.err`; combine with `tasmota/tele/<topic>/LWT` for liveness, because a retained `ok:true` survives a dead device. To retire a device: `mosquitto_pub -t muh/berry/<KEY>/status -r -n`.
- [ ] Note: errors raised later inside rules/crons are not in `MUH_STATUS`; they appear as `BRY: Exception>` lines in `/var/log/tasmota/<ip>.log` on 192.168.22.11.

## Self-Review

- One canonical file: Task 4, enforced by Task 6 (map ↔ tsv) and Task 8 (drift fails `make fleet`), rolled out in Task 9.
- `MUH_STATUS {lib, script, ok, err}` + retained publish at end of load: Task 4 (on connect and immediately when connected; autoexec runs before MQTT).
- Exact error text: `run_file` replaces `load()`; `gdhd.be` propagates nested errors (Task 5).
- `BAD` vs `Bad`: upper-case key lookup, topic uses the key (Task 4 test case 2).
- Safety: inventory + backups before any upload (Task 1, 7), rollback script (Task 7), `--autoexec-only` keeps running scripts, canary first, door controllers last (Task 9), PARK2 owner checkpoint (Task 2).
