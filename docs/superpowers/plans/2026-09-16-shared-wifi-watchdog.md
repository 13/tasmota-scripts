# Shared Wi-Fi Watchdog (HD/GD bootloop prevention) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the last ungated `restart 1` in the fleet (`gdhd.be`, used by HD and GD) by moving the boot-latched Wi-Fi watchdog from `hz_ww.be` into `muh_lib.be`, and deploy it to HZ_WW, HD and GD.

**Architecture:** `muh_lib.be` gains `init_wifi_watchdog(gateway_ip, cron_spec)`: arms a 120 s latch timer at load, registers the ping cron and the `Ping#<ip>#Success==0` rule, and only restarts once the latch has fired. `hz_ww.be` and `gdhd.be` each replace their hand-rolled cron + rule with one call. Test stubs move into a shared `tools/test_env.be` so a second harness can exercise the lib directly. Then register HD/GD IPs and deploy.

**Tech Stack:** Tasmota 15.1.0 Berry (strict mode), standalone `berry` at `/home/ben/repo/berry/berry`, `deploy.sh`.

## Global Constraints

- Berry on device is strict mode: every global must be declared with `var` or a top-level `def`, or be a plain assignment to a name that `muh_lib.be`/`autoexec.be` style already uses (muh_lib config globals are plain assignments, e.g. `DARK_OFFSET = 0`).
- `muh_lib.be` loads BEFORE the device script (see `autoexec.be`), and requires `log()` from `autoexec.be`.
- Never call `Restart 1` from Berry before the latch timer (`WATCHDOG_ARM_MS = 120000`) has fired. Tasmota's boot-loop protection counts restarts under 10 s uptime; 4 of them set `no_autoexec`, which skips `BerryInit()`.
- Timer/cron/rule ids must not collide across scripts on one device: `wifi_watchdog_arm`, `wifi_watchdog_ping`, `hz_ww_boot_retry` are reserved by this plan.
- `hz_ww.be` MQTT topic/payload must stay exactly `muh/sensors/HZ_WW/DS18B20-XXXXXX/json` with `{"time","tid","ds18b20":{"id","temperature"}}`, retained.
- `make test BERRY=/home/ben/repo/berry/berry` and `make check BERRY=/home/ben/repo/berry/berry` must pass after every task.
- HD and GD are door-lock controllers. Deploy them one at a time, verify each before the next, and only when nobody needs the doors for ~2 minutes.

## Evidence (2026-09-16)

- `MUH/gdhd.be:85` pings the gateway on cron `10 10 */3 * * * *`; `MUH/gdhd.be:93` restarts on `Ping#192.168.22.1#Success==0` with no uptime guard. Same defect class that silenced HZ_WW for 4 days.
- HD = 192.168.22.92 (uptime 299 d, Berry `52` alive), GD = 192.168.22.91 (uptime 68 d, alive). Both run the pre-`muh_lib` autoexec. Files on device: `autoexec.be`, `gdhd.be`, `hd.be`/`gd.be`, `_persist.json`, `say/`, `sfx/`. No name collisions between gdhd/hd/gd and muh_lib.
- Also found by sweep (not in scope, for `devices.tsv`): PV_A .56, HZ_DG .70, HZ_DGB .72, 3EM .60.
- Tasmota DS18x20 driver on this build uses `DS18x20_USE_ID_AS_NAME`, so keys are always `DS18B20-XXXXXX`; the single-sensor bare-key concern from the last review is moot.

---

### Task 1: Shared test environment + `init_wifi_watchdog` in muh_lib (TDD)

**Files:**
- Create: `tools/test_env.be`
- Create: `tools/test_wifi_watchdog.be`
- Modify: `tools/test_hz_ww.be` (use `test_env.be`, drop inline stubs)
- Modify: `MUH/muh_lib.be` (append watchdog section)
- Modify: `tools/be-check.be:17-20` (seed new lib names)
- Modify: `Makefile` (`test` runs both harnesses)

**Interfaces:**
- Produces (muh_lib globals): `WATCHDOG_ARM_MS` (int, 120000), `_watchdog_armed` (bool), `init_wifi_watchdog(gateway_ip, cron_spec)`.
- Produces (test env globals): `published`, `cmds`, `rules`, `crons`, `timers` (list of `[ms, closure, id]`), `sensor_json`, `tasmota` (stub), `DEVICENAME`, `LOG_PREFIX`, `DEBUG`, `log`, `mqtt_publish_hook`, `failures`, `check(cond, name)`, `reset()`, `load(filename)`, `finish()`.

- [ ] **Step 1: Create `tools/test_env.be`** (the stubs currently at the top of `tools/test_hz_ww.be`, moved verbatim, plus `finish()`):

```berry
# tools/test_env.be — shared stubs for the offline Berry harnesses.
# Execute from a test with: compile("tools/test_env.be", "file")()
# Top-level var/def here become globals visible to the test and to the
# scripts it loads (same as Tasmota's load() semantics).
import sys
sys.path().push("tools/stubs")
import json
import string
import math

var published = []     # list of [topic, payload_map, retain]
var cmds = []          # tasmota.cmd() calls
var rules = {}         # trigger -> closure
var crons = {}         # id -> closure
var timers = []        # list of [delay_ms, closure, id]
var sensor_json = ""

class TasmotaStub
  def read_sensors() return sensor_json end
  def rtc() return {'local': 0} end
  def time_str(t) return "2026-01-01T00:00:00" end
  def cmd(c)
    cmds.push(c)
    if c == "DeviceName" return {"DeviceName": DEVICENAME} end
    return {}
  end
  def add_rule(trigger, f) rules[trigger] = f end
  def add_cron(spec, f, id) crons[id] = f end
  def set_timer(ms, f, id) timers.push([ms, f, id]) end
  def remove_timer(id) end
end
var tasmota = TasmotaStub()
def mqtt_publish_hook(topic, payload, retain)
  published.push([topic, json.load(payload), retain])
end

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
def load(filename)
  compile(filename, "file")()
end
def finish()
  print(f"{failures} failures")
  if failures > 0 raise "test_failed" end
end
```
Copy the real `TasmotaStub` from the current `tools/test_hz_ww.be` if it differs (it must keep the `DeviceName` special case and the 3-element `set_timer` record).

- [ ] **Step 2: Refactor `tools/test_hz_ww.be`** to start with

```berry
# tools/test_hz_ww.be — offline behaviour test for MUH/hz_ww.be
# Run: berry tools/test_hz_ww.be   (from repo root)
compile("tools/test_env.be", "file")()
```
and delete everything it duplicated (imports, stubs, `check`, `reset`, `load`, the `var boot_publish, ...` seeds stay). Replace the trailing `print(f"{failures} failures") / raise` with `finish()`.
Run: `make test BERRY=/home/ben/repo/berry/berry` → still `0 failures` (19 checks). Commit: `test: extract shared harness env into tools/test_env.be`.

- [ ] **Step 3: Write the failing watchdog test** `tools/test_wifi_watchdog.be`:

```berry
# tools/test_wifi_watchdog.be — offline test for init_wifi_watchdog() in MUH/muh_lib.be
# Run: berry tools/test_wifi_watchdog.be   (from repo root)
compile("tools/test_env.be", "file")()
import string

load("MUH/muh_lib.be")
init_wifi_watchdog("192.168.22.1", "10 */8 * * * *")

# registration
var arm = nil
for t: timers
  if t[2] == "wifi_watchdog_arm" arm = t end
end
check(arm != nil && arm[0] == WATCHDOG_ARM_MS && WATCHDOG_ARM_MS == 120000, "arm timer registered with WATCHDOG_ARM_MS = 120000")
check(crons.contains("wifi_watchdog_ping"), "ping cron registered")
check(rules.contains("Ping#192.168.22.1#Success==0"), "ping-fail rule registered")

# cron issues the ping
reset()
crons["wifi_watchdog_ping"]()
check(cmds.size() == 1 && string.tolower(cmds[0]) == "ping4 192.168.22.1", "cron pings the gateway")

# ping failure before the latch: no restart
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 0, "ping fail before arm timer fired: no restart")

# latch fires, then ping failure restarts
arm[1]()
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after arm timer fired: restart 1")

finish()
```

- [ ] **Step 4: Run it, expect failure**
Run: `/home/ben/repo/berry/berry tools/test_wifi_watchdog.be`
Expected: error mentioning `init_wifi_watchdog` (undeclared / nil not callable).

- [ ] **Step 5: Implement in `MUH/muh_lib.be`** (append at end of file):

```berry
# Wi-Fi watchdog: ping `gateway_ip` on `cron_spec`; restart if a ping fails.
# The restart is held back until WATCHDOG_ARM_MS after script load: a restart
# inside Tasmota's 10 s boot-loop window counts toward boot-loop protection,
# and four of those set no_autoexec, which skips BerryInit() entirely
# (that is how HZ_WW went silent for four days in Sept 2026).
WATCHDOG_ARM_MS = 120000
_watchdog_armed = false

def init_wifi_watchdog(gateway_ip, cron_spec)
  tasmota.set_timer(WATCHDOG_ARM_MS, def ()
    _watchdog_armed = true
    log(f"wifi watchdog armed for {gateway_ip}")
  end, "wifi_watchdog_arm")
  tasmota.add_cron(cron_spec, def () tasmota.cmd(f"Ping4 {gateway_ip}") end, "wifi_watchdog_ping")
  tasmota.add_rule(f"Ping#{gateway_ip}#Success==0", def ()
    if _watchdog_armed
      log(f"ping {gateway_ip} failed, restarting")
      tasmota.cmd("Restart 1")
    else
      log(f"ping {gateway_ip} failed inside boot window, ignored")
    end
  end)
end
```

- [ ] **Step 6: Seed be-check** — in `tools/be-check.be` after the existing muh_lib lines add:
```berry
var WATCHDOG_ARM_MS, _watchdog_armed, init_wifi_watchdog
```

- [ ] **Step 7: Makefile** — change the `test` recipe to run both (TAB-indented):
```make
test:
	$(BERRY) tools/test_hz_ww.be
	$(BERRY) tools/test_wifi_watchdog.be
```

- [ ] **Step 8: Verify**
Run: `make test BERRY=/home/ben/repo/berry/berry` → both harnesses `0 failures`.
Run: `make check BERRY=/home/ben/repo/berry/berry` → `25/25 scripts OK`.

- [ ] **Step 9: Commit**
```bash
git add MUH/muh_lib.be tools/test_env.be tools/test_wifi_watchdog.be tools/test_hz_ww.be tools/be-check.be Makefile
git commit -m "feat(muh_lib): boot-latched init_wifi_watchdog shared helper"
```

---

### Task 2: hz_ww.be uses the shared watchdog; test the retry chain through the armed timer

**Files:**
- Modify: `MUH/hz_ww.be` (remove `restart_allowed`, `MIN_UPTIME_FOR_RESTART_MS`, the arm timer, the `check_wifi` cron and the ping rule; add one call)
- Modify: `tools/test_hz_ww.be`

**Interfaces:**
- Consumes: `init_wifi_watchdog(gateway_ip, cron_spec)` from Task 1; `WATCHDOG_ARM_MS`.
- Keeps: `boot_publish(attempt)`, `check_ds18b20(force)`, `last_temp`, `INVALID_TEMP`, `BOOT_RETRIES`, timer id `hz_ww_boot_retry`, cron ids `check_ds18b20`, `check_ds18b20_force`.

- [ ] **Step 1: Update the harness first.** In `tools/test_hz_ww.be`:
  - After the `compile("tools/test_env.be", "file")()` line add `load("MUH/muh_lib.be")` BEFORE `load("MUH/hz_ww.be")` (mirrors autoexec order). Remove `MIN_UPTIME_FOR_RESTART_MS` from the `var` seed line.
  - Replace the whole ping/latch block (the `guard_timer` capture and the three ping checks) with:
```berry
# wifi watchdog wired through muh_lib: arm timer + cron + rule registered by hz_ww.be
var arm = nil
for t: timers
  if t[2] == "wifi_watchdog_arm" arm = t end
end
check(arm != nil && arm[0] == WATCHDOG_ARM_MS, "hz_ww registers the shared wifi watchdog arm timer")
check(crons.contains("wifi_watchdog_ping") && !crons.contains("check_wifi"), "hz_ww uses the shared ping cron, old check_wifi cron gone")
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 0, "ping fail before arm: no restart")
arm[1]()
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after arm: restart")
```
    (Capture `arm` from `timers` right after the two `load(...)` calls, before the first `reset()`, exactly as the old `guard_timer` was.)
  - Add, after the existing boot block, a retry-chain test driven through the armed closure:
```berry
# retry chain: permanent 85 -> exactly BOOT_RETRIES re-arms, then give up, never a restart
reset()
mock_sensors(85, 40.0)
last_temp = {}
rules["system#boot"](nil, "system#boot", nil)
var rounds = 0
while timers.size() > 0 && rounds < 20
  var t = timers.pop()
  check(t[2] == "hz_ww_boot_retry" && t[0] == BOOT_RETRY_MS, f"retry {rounds + 1} armed as hz_ww_boot_retry")
  t[1]()
  rounds += 1
end
check(rounds == BOOT_RETRIES, f"retry chain stops after BOOT_RETRIES ({BOOT_RETRIES}) attempts")
check(cmds.size() == 0, "retry chain never restarts")
```
    Add `BOOT_RETRIES, BOOT_RETRY_MS` to the `var` seed line (they are `var` in hz_ww.be so they become globals when loaded; the seed only satisfies the compiler before load).
    Note: `timers.pop()` pops the last entry, and `boot_publish` pushes exactly one timer per attempt, so the loop consumes one per round; assert the id on each so a stray timer fails the test.

- [ ] **Step 2: Run, expect failures** — `make test BERRY=...`: the `check_wifi` cron still exists and `wifi_watchdog_arm` is absent → FAIL lines for those checks.

- [ ] **Step 3: Edit `MUH/hz_ww.be`:**
  - Delete `var MIN_UPTIME_FOR_RESTART_MS = 120000 ...` and `var restart_allowed = false ...`.
  - Delete the `tasmota.set_timer(MIN_UPTIME_FOR_RESTART_MS, ...)` block, the `check_wifi` cron line and the entire `Ping#192.168.22.1#Success==0` rule.
  - In their place, after the two `check_ds18b20` crons, add:
```berry
# Wi-Fi watchdog (shared, boot-latched; see muh_lib.be)
init_wifi_watchdog("192.168.22.1", "10 */8 * * * *")
```

- [ ] **Step 4: Verify** — `make test BERRY=...` both harnesses `0 failures`; `make check BERRY=...` `25/25 scripts OK`. Also `grep -n -i restart MUH/hz_ww.be` must show only the header comment lines.

- [ ] **Step 5: Commit**
```bash
git add MUH/hz_ww.be tools/test_hz_ww.be
git commit -m "refactor(hz_ww): use shared init_wifi_watchdog; test retry chain via armed timer"
```

---

### Task 3: gdhd.be uses the shared watchdog

**Files:**
- Modify: `MUH/gdhd.be:85` and `MUH/gdhd.be:92-93`

- [ ] **Step 1: Edit.** Delete line 85 (`tasmota.add_cron("10 10 */3 * * *", def (value) tasmota.cmd("ping4 192.168.22.1") end, "checkWifi")`) and lines 92-93 (the `## Restart when the gateway stops answering pings` comment and the `Ping#192.168.22.1#Success==0` rule). In the `# RULES` section put:
```berry
## Wi-Fi watchdog (shared, boot-latched; see muh_lib.be)
init_wifi_watchdog("192.168.22.1", "10 10 */3 * * *")
```

- [ ] **Step 2: Verify** — `make check BERRY=...` → `25/25 scripts OK`; `grep -n -i 'restart\|checkWifi' MUH/gdhd.be` → no matches.

- [ ] **Step 3: Commit**
```bash
git add MUH/gdhd.be
git commit -m "fix(gdhd): boot-latched wifi watchdog via muh_lib instead of ungated restart"
```

---

### Task 4: Register IPs and deploy HZ_WW, then HD, then GD

**Files:**
- Modify: `devices.tsv` (tab-separated)

- [ ] **Step 1: IPs.** Set:
```
HD	192.168.22.92	gdhd.be,hd.be
GD	192.168.22.91	gdhd.be,gd.be
PV_A	192.168.22.56	pv_a.be
```
(PV_A is bonus bookkeeping from the sweep; do not deploy it in this plan.) Commit: `chore: register HD, GD, PV_A IPs`.

- [ ] **Step 2: Deploy HZ_WW** (already on the new autoexec; low risk):
```bash
./deploy.sh HZ_WW
```
Verify after ~30 s and again after ~150 s:
```bash
curl -s 'http://192.168.22.74/cm?cmnd=Status%204' | grep -o '"Drivers":"[^"]*"' | grep -o '[!]*52'   # expect 52
curl -s 'http://192.168.22.74/cm?cmnd=Br%201%2B1'                                                   # expect {"Br":"2"}
curl -s 'http://192.168.22.74/cs?c2=0&c1=' | grep -o 'wifi watchdog armed[^}]*'                    # after 120 s
timeout 6 mosquitto_sub -h 192.168.22.5 -t 'muh/sensors/HZ_WW/#' -v -C 4 -W 5                       # fresh timestamps
```

- [ ] **Step 3: Deploy HD** — door controller. Confirm nobody needs the house door for the next ~2 minutes, then:
```bash
./deploy.sh HD
```
Expected upload list: `autoexec.be`, `muh_lib.be`, `gdhd.be`, `hd.be`, then `restarted`. Verify after ~40 s:
```bash
curl -s 'http://192.168.22.92/cm?cmnd=Status%204' | grep -o '"Drivers":"[^"]*"' | grep -o '[!]*52'   # 52
curl -s 'http://192.168.22.92/cm?cmnd=Br%201%2B1'                                                   # {"Br":"2"}
curl -s 'http://192.168.22.92/cs?c2=0&c1=' | grep -o 'MUH:[^}]\{0,80\}' | head                       # "Loading gdhd.be for HD", "Loading hd.be on HD..."
curl -s 'http://192.168.22.92/ufsd?dir=/' | grep -o "file='[^']*'" | tr '\n' ' '                   # _persist.json, say/, sfx/ still present
```
and after 120 s the console shows `wifi watchdog armed for 192.168.22.1`. Test one lock/unlock event the usual way before continuing.

- [ ] **Step 4: Deploy GD** — same procedure with `./deploy.sh GD` and IP 192.168.22.91; expect uploads `autoexec.be`, `muh_lib.be`, `gdhd.be`, `gd.be`.

- [ ] **Step 5: Rollback path (only if a device fails verification):** the old autoexec is saved at `/tmp/ae_192.168.22.9X.be` from the 2026-09-16 inspection (also recoverable from git: `git show 73b1119:MUH/autoexec.be`). Upload it via the device's `/ufsu` form or `curl -F 'ufsu=@old_autoexec.be' http://IP/ufsu`, then `Restart 1`. The old autoexec ignores `muh_lib.be`.

- [ ] **Step 6: Commit `devices.tsv` if not already, push**
```bash
git push origin main
```

---

### Task 5: Soak (next day)

- [ ] For each of 192.168.22.74 / .92 / .91: `Status 1` uptime ≥ 1 day or, if restarted, `Br 1+1` still answers and the console shows `wifi watchdog armed`.
- [ ] HZ_WW retained `time` within the last hour.

## Self-Review

- Coverage: ungated restart in gdhd (Task 3), shared latch (Task 1), hz_ww switched over (Task 2), retry-chain test gap from last review (Task 2), HD/GD IPs + deploy + rollback (Task 4). Single-sensor key: dropped with evidence.
- Placeholders: none. Names consistent: `init_wifi_watchdog`, `WATCHDOG_ARM_MS`, `_watchdog_armed`, timer `wifi_watchdog_arm`, cron `wifi_watchdog_ping`, `hz_ww_boot_retry`, `BOOT_RETRIES`, `BOOT_RETRY_MS`.
- Risk called out: HD/GD restarts on door controllers; one at a time, verify, rollback documented.
