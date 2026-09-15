# HZ_WW Bootloop / Berry-Disabled Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `hz_ww.be` from killing its own Berry VM via Tasmota bootloop protection, so `muh/sensors/HZ_WW/<sensor>/json` keeps publishing indefinitely.

**Architecture:** `hz_ww.be` currently issues `restart 1` from a boot timer whenever a DS18B20 read 85 °C at load time (and the timer closure captures the stale value, so the restart is unconditional once triggered). Each restart lands inside Tasmota's 10 s boot-loop window; after 4 fast restarts Tasmota sets `no_autoexec`, which skips `BerryInit()` entirely. Berry stays dead until the next *slow* restart. Fix: never restart from Berry inside the boot window, re-read sensors fresh on retry, and guard the Wi-Fi ping restart with a minimum uptime. Then redeploy (device still runs the pre-`muh_lib` autoexec).

**Tech Stack:** Tasmota 15.1.0 Berry, standalone `berry` interpreter for `make check`, `deploy.sh` (HTTP upload + restart).

## Global Constraints

- Berry on device is strict mode (`comp_set_strict`): every global must be declared with `var` or assigned after being declared in autoexec/muh_lib.
- `DEVICENAME` (uppercase) is the global provided by `autoexec.be`; do not re-query `DeviceName` in the device script.
- Never call `Restart 1` from Berry when `tasmota.millis()` is below 120000 (Tasmota `BOOT_LOOP_TIME` is 10 s; 120 s leaves margin for Wi-Fi/NTP).
- MQTT topic and payload shape must stay exactly `muh/sensors/HZ_WW/DS18B20-XXXXXX/json` with `{"time","tid","ds18b20":{"id","temperature"}}`, retained.
- No standalone `berry` on PATH yet; build it once (Task 0).

## Evidence (from live device 192.168.22.74, 2026-09-15)

- `Status 4` Drivers list shows `!52` (Berry inactive); working sibling PlugUD shows `52` and answers `Br 1+1`.
- `Br ...` returns `{"Command":"Unknown"}`, `/bc` returns 404: `berry.vm == NULL`.
- RestartReason `Software reset CPU`, StartupUTC `2026-09-11T04:00:54`; last retained MQTT payloads are stamped `2026-09-11T06:00:00` local (54 s before the final boot: hourly force publish, then a restart storm).
- Tasmota source (`tasmota.ino`): `fast_reboot_count > SetOption36+2` sets `TasmotaGlobal.no_autoexec = true`; `BerryInit()` is only called when `!no_autoexec`. Counter resets at uptime 10 s (`BOOT_LOOP_TIME`). SetOption36 on device = 1.
- `hz_ww.be` restart sources: ERR85 boot timers at 2/6/10/14 s (stale closure `sensor_temp`, never re-read) and `Ping#...#Success==0` rule (cron at second 10 every 8 min, can fire before Wi-Fi is up after a boot).

---

### Task 0: Build the standalone Berry interpreter (one-time tooling)

**Files:**
- None in repo (binary lives outside repo).

- [ ] **Step 1: Clone and build**

```bash
git clone --depth 1 https://github.com/berry-lang/berry /home/ben/repo/berry
make -C /home/ben/repo/berry -j
ls -l /home/ben/repo/berry/berry
```
Expected: `berry` binary exists.

- [ ] **Step 2: Confirm existing check passes on current tree**

```bash
cd /home/ben/repo/tasmota-scripts && make check BERRY=/home/ben/repo/berry/berry
```
Expected: `N/N scripts OK` (N = number of `.be` files in `MUH/`).

---

### Task 1: Offline test harness for hz_ww.be

**Files:**
- Create: `tools/test_hz_ww.be`
- Modify: `Makefile` (add `test` target)

**Interfaces:**
- Produces: `make test BERRY=...` running `berry tools/test_hz_ww.be`, exit non-zero on failure.
- Consumes (from Task 2): globals `read_ds18b20()`, `check_ds18b20(force)`, `boot_publish(attempt)`, `last_temp` map, constants `INVALID_TEMP`, `MIN_UPTIME_FOR_RESTART_MS` defined in `MUH/hz_ww.be`.

- [ ] **Step 1: Write the failing test**

```berry
# tools/test_hz_ww.be — offline behaviour test for MUH/hz_ww.be
# Run: berry tools/test_hz_ww.be
import json
import string
import math

# ---- stubs for Tasmota built-ins ----
var published = []     # list of [topic, payload_map, retain]
var cmds = []          # tasmota.cmd() calls
var rules = {}         # trigger -> closure
var crons = {}         # id -> closure
var timers = []        # list of [delay_ms, closure]
var sensor_json = ""
var millis_now = 0

class TasmotaStub
  def read_sensors() return sensor_json end
  def rtc() return {'local': 0} end
  def time_str(t) return "2026-01-01T00:00:00" end
  def millis() return millis_now end
  def cmd(c) cmds.push(c) return {} end
  def add_rule(trigger, f) rules[trigger] = f end
  def add_cron(spec, f, id) crons[id] = f end
  def set_timer(ms, f, id) timers.push([ms, f]) end
  def remove_timer(id) end
end
class MqttStub
  def publish(topic, payload, retain)
    published.push([topic, json.load(payload), retain])
  end
end
var tasmota = TasmotaStub()
var mqtt = MqttStub()
var DEVICENAME = "HZ_WW"
var LOG_PREFIX = "MUH:"
var DEBUG = false
def log(m) if DEBUG print(m) end end

var failures = 0
def check(cond, name)
  if cond
    print(f"ok   {name}")
  else
    print(f"FAIL {name}")
    failures += 1
  end
end
def reset()
  published = [] cmds = [] timers = []
end
def sensors(a, b)
  sensor_json = json.dump({
    'Time': 'x',
    'ANALOG': {'Temperature1': 19.5},
    'DS18B20-3628FF': {'Id': '00042B3628FF', 'Temperature': a},
    'DS18B20-1C16E1': {'Id': '0621C01C16E1', 'Temperature': b},
  })
end

# ---- load script under test with one sensor stuck at 85 ----
sensors(85, 40.0)
load("MUH/hz_ww.be")

# boot: valid sensor published, 85 sensor not, no restart, retry timer armed
reset()
rules["system#boot"]()
check(published.size() == 1, "boot publishes only valid sensor")
check(published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "boot topic")
check(published[0][1]['ds18b20']['temperature'] == 40.0, "boot payload temperature")
check(published[0][1]['tid'] == "HZ_WW", "boot payload tid")
check(published[0][2] == true, "boot publish retained")
check(cmds.size() == 0, "boot with 85 never restarts")
check(timers.size() == 1, "boot with 85 arms one retry timer")

# retry re-reads sensors fresh: now valid -> published
reset()
sensors(53.1, 40.0)
timers = []
boot_publish(1)
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-3628FF/json", "retry publishes recovered sensor")
check(cmds.size() == 0, "retry never restarts")

# delta publish: < 1 degree -> nothing, >= 1 -> publish
reset()
sensors(53.5, 40.0)
crons["check_ds18b20"]()
check(published.size() == 0, "delta below threshold not published")
sensors(54.2, 40.0)
crons["check_ds18b20"]()
check(published.size() == 1 && published[0][1]['ds18b20']['temperature'] == 54.2, "delta above threshold published")

# forced publish skips 85 readings
reset()
sensors(85, 41.0)
crons["check_ds18b20_force"]()
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "force publish skips 85")

# ping failure: no restart during boot window, restart after
reset()
millis_now = 5000
rules["Ping#192.168.22.1#Success==0"]()
check(cmds.size() == 0, "ping fail early uptime: no restart")
millis_now = MIN_UPTIME_FOR_RESTART_MS + 1
rules["Ping#192.168.22.1#Success==0"]()
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after uptime guard: restart")

print(f"{failures} failures")
if failures > 0 raise "test_failed" end
```

- [ ] **Step 2: Add Makefile target**

Modify `Makefile`:

```make
.PHONY: check test deploy list

check:
	$(BERRY) tools/be-check.be

test:
	$(BERRY) tools/test_hz_ww.be
```

- [ ] **Step 3: Run test, verify it fails against current script**

```bash
make test BERRY=/home/ben/repo/berry/berry
```
Expected: FAIL (current script has no `boot_publish`, calls `tasmota.publish`, and `check_delta`/closure differ). Any error or `FAIL` lines count as the expected failing state.

- [ ] **Step 4: Commit**

```bash
git add tools/test_hz_ww.be Makefile
git commit -m "test: offline harness for hz_ww.be boot/publish behaviour"
```

---

### Task 2: Rewrite hz_ww.be without self-restart in the boot window

**Files:**
- Modify: `MUH/hz_ww.be` (replace everything below the `#- ... -#` header comment)

**Interfaces:**
- Produces globals: `INVALID_TEMP`, `MIN_UPTIME_FOR_RESTART_MS`, `last_temp`, `read_ds18b20()`, `publish_mqtt(key, s)`, `check_ds18b20(force)`, `boot_publish(attempt)`.
- Consumes: `DEVICENAME`, `log()` from `autoexec.be`; `mqtt`, `tasmota` built-ins.

- [ ] **Step 1: Replace script body**

Keep the existing header comment (Backlog template / IP config) unchanged. Replace all Berry code with:

```berry
import json
import mqtt
import string
import math

# Constants
DS18B20_PREFIX = "DS18B20-"
INVALID_TEMP = 85               # DS18B20 power-on / bus-error value
DEFAULT_DELTA_THRESHOLD = 1
BOOT_RETRY_MS = 5000            # re-read interval while a sensor still says 85 at boot
BOOT_RETRIES = 6
MIN_UPTIME_FOR_RESTART_MS = 120000   # never Restart from Berry inside Tasmota's boot-loop window

# sensor key ("DS18B20-3628FF") -> last published temperature
var last_temp = {}

# Fresh read of all DS18B20 entries: key -> {'Id':..., 'Temperature':...}
def read_ds18b20()
  var out = {}
  var sensors = json.load(tasmota.read_sensors())
  if sensors == nil
    return out
  end
  for k: sensors.keys()
    if string.startswith(k, DS18B20_PREFIX)
      out[k] = sensors[k]
    end
  end
  return out
end

def publish_mqtt(key, s)
  var payload = {
    'time': tasmota.time_str(tasmota.rtc()['local']),
    'tid': DEVICENAME,
    'ds18b20': {'id': s['Id'], 'temperature': s['Temperature']}
  }
  mqtt.publish(f"muh/sensors/{DEVICENAME}/{key}/json", json.dump(payload), true)
  last_temp[key] = s['Temperature']
end

# Publish every valid sensor when forced, otherwise only on >= threshold change.
# 85 readings are never published.
def check_ds18b20(force)
  var all = read_ds18b20()
  for key: all.keys()
    var t = all[key]['Temperature']
    if t == INVALID_TEMP
      continue
    end
    var last = last_temp.find(key)
    if force || last == nil || math.abs(t - last) >= DEFAULT_DELTA_THRESHOLD
      publish_mqtt(key, all[key])
    end
  end
end

# Boot: publish what is valid now; while any sensor still reads 85, retry a
# few times with a FRESH read. Never restart the device for this — a restart
# inside the first 10 s trips Tasmota's boot-loop protection, which disables
# Berry entirely (that is how this device went silent for days).
def boot_publish(attempt)
  check_ds18b20(true)
  var all = read_ds18b20()
  var pending = []
  for key: all.keys()
    if all[key]['Temperature'] == INVALID_TEMP
      pending.push(key)
    end
  end
  if pending.size() == 0
    return
  end
  if attempt < BOOT_RETRIES
    log(f"ERR85 {pending}, retry {attempt + 1}/{BOOT_RETRIES}")
    tasmota.set_timer(BOOT_RETRY_MS, def () boot_publish(attempt + 1) end, "hz_ww_boot_retry")
  else
    log(f"ERR85 {pending} still invalid after {BOOT_RETRIES} retries, giving up until next cron")
  end
end

tasmota.add_rule("system#boot", def () boot_publish(0) end)

# Cron jobs
tasmota.add_cron("10 */2 * * * *", def () check_ds18b20(false) end, "check_ds18b20")
tasmota.add_cron("0 0 */1 * * *", def () check_ds18b20(true) end, "check_ds18b20_force")
tasmota.add_cron("10 */8 * * * *", def () tasmota.cmd("Ping4 192.168.22.1") end, "check_wifi")

# Wi-Fi watchdog: restart only once well past the boot-loop window
tasmota.add_rule("Ping#192.168.22.1#Success==0", def ()
  if tasmota.millis() > MIN_UPTIME_FOR_RESTART_MS
    log("gateway ping failed, restarting")
    tasmota.cmd("Restart 1")
  else
    log("gateway ping failed during boot window, ignored")
  end
end)
```

- [ ] **Step 2: Run offline test**

```bash
make test BERRY=/home/ben/repo/berry/berry
```
Expected: every line `ok ...`, final `0 failures`.

- [ ] **Step 3: Run syntax/global check**

```bash
make check BERRY=/home/ben/repo/berry/berry
```
Expected: `N/N scripts OK`. If `be-check.be` reports undeclared globals for `hz_ww.be`, add the new names (`last_temp`, `read_ds18b20`, `publish_mqtt`, `check_ds18b20`, `boot_publish`) to the `var` seed list in `tools/be-check.be` only if the checker flags them (top-level `var`/`def` in the checked file itself normally need no seeding).

- [ ] **Step 4: Commit**

```bash
git add MUH/hz_ww.be
git commit -m "fix(hz_ww): stop self-restart inside boot-loop window; fresh re-read on ERR85"
```

---

### Task 3: Register HZ_WW IP and deploy

**Files:**
- Modify: `devices.tsv` (HZ_WW row)

- [ ] **Step 1: Set IP**

Change the row
```
HZ_WW	?	hz_ww.be
```
to
```
HZ_WW	192.168.22.74	hz_ww.be
```
(tab-separated).

- [ ] **Step 2: Deploy**

```bash
./deploy.sh HZ_WW
```
Expected output:
```
HZ_WW (192.168.22.74):
  upload autoexec.be
  upload muh_lib.be
  upload hz_ww.be
  restarted
```
This restart happens at uptime > 10 s, so Tasmota's fast-reboot counter is already 0 and Berry initialises normally.

- [ ] **Step 3: Verify Berry is back (wait ~30 s after restart)**

```bash
curl -s 'http://192.168.22.74/cm?cmnd=Status%204' | grep -o '"Drivers":"[^"]*"' | grep -o ',52,'
curl -s 'http://192.168.22.74/cm?cmnd=Br%201%2B1'
curl -s 'http://192.168.22.74/cm?cmnd=Br%20tasmota.millis()'
```
Expected: `,52,` printed (no `!`), `{"Br":"2"}`, and a millis value.

- [ ] **Step 4: Verify boot publish reached the broker**

```bash
timeout 5 mosquitto_sub -h 192.168.22.5 -t 'muh/sensors/HZ_WW/#' -v -C 4 -W 4
```
Expected: four retained payloads whose `time` is today, not `2026-09-11T06:00:00`.

- [ ] **Step 5: Check console log for script errors**

```bash
curl -s 'http://192.168.22.74/cs?c2=0&c1=' | grep -E 'BRY|MUH' | tail -20
```
Expected: `MUH: AutoExec HZ_WW ...`, `MUH: Loading hz_ww.be for HZ_WW`, no `BRY: Exception`.

- [ ] **Step 6: Commit**

```bash
git add devices.tsv
git commit -m "chore: register HZ_WW IP for deploy"
```

---

### Task 4: Soak check (next day)

- [ ] **Step 1: Confirm hourly force publish is running**

```bash
timeout 5 mosquitto_sub -h 192.168.22.5 -t 'muh/sensors/HZ_WW/DS18B20-3628FF/json' -v -C 1 -W 4
```
Expected: `time` within the last hour.

- [ ] **Step 2: Confirm no boot-loop event**

```bash
curl -s 'http://192.168.22.74/cm?cmnd=Status%201' | grep -o '"Uptime":"[^"]*"\|"RestartReason":"[^"]*"'
```
Expected: uptime ≥ 1 day, or if restarted, Berry still active (`Br 1+1` answers).

## Self-Review

- Spec coverage: bootloop trigger removed (Task 2 boot_publish, no Restart), stale-closure bug removed (fresh `read_ds18b20()` per retry), ping restart guarded (Task 2), redeploy of stale autoexec + missing muh_lib (Task 3), verification (Tasks 3–4). Offline test (Task 1) covers each behaviour.
- Placeholders: none.
- Names consistent across tasks: `read_ds18b20`, `check_ds18b20(force)`, `boot_publish(attempt)`, `last_temp`, `MIN_UPTIME_FOR_RESTART_MS`, `INVALID_TEMP`.
