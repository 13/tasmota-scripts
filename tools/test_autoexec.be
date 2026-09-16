# tools/test_autoexec.be — offline test for MUH/autoexec.be (canonical loader)
# Run: berry tools/test_autoexec.be   (from repo root)
#
# The test chdirs into tools/fixtures/autoexec, which plays the device
# filesystem (muh_lib.be, good.be, boom.be, syntax.be; nolib/ has no
# muh_lib.be). autoexec.be is compiled from the repo by relative path with
# MUH_AUTOEXEC_NO_BOOT set, so its last block does not boot; each case then
# sets DEVICENAME and DEVICE_SCRIPTS and calls muh_boot()/publish_status().

# Berry compiles this whole file in one pass before executing any of it, so
# a name that a separately-compiled unit (tools/test_env.be, MUH/autoexec.be,
# the fixtures) assigns only becomes usable here once that unit's own
# compile()() call has actually run. Forward-declare every such name first
# (nil until then) so this file's own code compiles.
var published, cmds, rules, check, reset, finish, json, string
var DEVICENAME, DEBUG, TasmotaStub, tasmota, mqtt_is_connected
compile("tools/test_env.be", "file")()

# Globals provided by MUH/autoexec.be
var AUTOEXEC_VERSION, DEVICE_SCRIPTS, DEVICE_KEY, MUH_STATUS
var run_file, muh_boot, publish_status, muh_start
# Globals provided by the fixtures
var FIXTURE_LIB, FIXTURE_GOOD, FIXTURE_NOLIB_RAN

import os
import sys
var ROOT = os.getcwd()
# test_env pushed "tools/stubs" relative to the repo root; keep the stubs
# (mqtt, path) importable after the chdir below.
sys.path().push(ROOT + "/tools/stubs")
os.chdir(ROOT + "/tools/fixtures/autoexec")

var MUH_AUTOEXEC_NO_BOOT = true
compile("../../../MUH/autoexec.be", "file")()
DEBUG = false

def has(s, sub) return s != nil && string.find(s, sub) >= 0 end

def boot_as(name, scripts)
  DEVICENAME = name
  DEVICE_SCRIPTS = scripts
  reset()
  muh_boot()
end

def last_publish()
  return published.size() > 0 ? published[published.size() - 1] : nil
end

# ---- 1. known device, script loads ----
boot_as("Good", {"GOOD": "good.be"})
check(MUH_STATUS["lib"] == true && MUH_STATUS["script"] == "good.be" && MUH_STATUS["ok"] == true && MUH_STATUS["err"] == "",
  "1 good: MUH_STATUS = {lib:true, script:'good.be', ok:true, err:''}")
check(MUH_STATUS.size() == 4, "1 good: MUH_STATUS has exactly lib, script, ok, err")
check(FIXTURE_LIB == true && FIXTURE_GOOD == true, "1 good: library and device script both ran")
publish_status()
check(published.size() == 1 && published[0][0] == "muh/berry/GOOD/status", "1 good: published on muh/berry/GOOD/status")

# ---- 2. mixed-case DeviceName is looked up and published upper-case ----
boot_as("Bad", {"BAD": "good.be"})
check(MUH_STATUS["ok"] == true && DEVICE_KEY == "BAD", "2 mixed case: 'Bad' resolves to key BAD")
publish_status()
check(last_publish() != nil && last_publish()[0] == "muh/berry/BAD/status", "2 mixed case: topic muh/berry/BAD/status")
check(last_publish()[1]["device"] == "Bad", "2 mixed case: payload device keeps the DeviceName as set")

# ---- 3. device script raises ----
boot_as("Good", {"GOOD": "boom.be"})
check(MUH_STATUS["ok"] == false && MUH_STATUS["lib"] == true && MUH_STATUS["script"] == "boom.be",
  "3 raise: ok:false, lib:true, script:'boom.be'")
check(has(MUH_STATUS["err"], "boom.be") && has(MUH_STATUS["err"], "boom at load"),
  f"3 raise: err names file and message ({MUH_STATUS['err']})")

# ---- 4. device script does not compile ----
boot_as("Good", {"GOOD": "syntax.be"})
check(MUH_STATUS["ok"] == false && MUH_STATUS["lib"] == true && has(MUH_STATUS["err"], "syntax.be"),
  f"4 syntax error: ok:false, err names syntax.be ({MUH_STATUS['err']})")

# ---- 5. device script missing ----
boot_as("Good", {"GOOD": "missing.be"})
check(MUH_STATUS["ok"] == false && MUH_STATUS["err"] == "missing.be: file not found",
  f"5 missing: err == 'missing.be: file not found' ({MUH_STATUS['err']})")

# ---- 6. library missing: device script is not attempted ----
os.chdir("nolib")
boot_as("Good", {"GOOD": "marker.be"})
os.chdir("..")
check(MUH_STATUS["lib"] == false && MUH_STATUS["ok"] == false && has(MUH_STATUS["err"], "muh_lib.be"),
  f"6 no lib: lib:false, err names muh_lib.be ({MUH_STATUS['err']})")
check(FIXTURE_NOLIB_RAN == nil, "6 no lib: device script not attempted")

# ---- 7. unknown device / empty DeviceName ----
boot_as("Nope", {"GOOD": "good.be"})
check(MUH_STATUS["lib"] == false && MUH_STATUS["ok"] == false && has(MUH_STATUS["err"], "DEVICE_SCRIPTS"),
  f"7 unknown device: lib:false, err mentions DEVICE_SCRIPTS ({MUH_STATUS['err']})")
publish_status()
check(last_publish()[0] == "muh/berry/NOPE/status", "7 unknown device: still publishes on its own key")
boot_as("", {"GOOD": "good.be"})
check(MUH_STATUS["ok"] == false && MUH_STATUS["err"] != "", f"7 empty DeviceName: not ok ({MUH_STATUS['err']})")
publish_status()
check(last_publish()[0] == "muh/berry/UNKNOWN/status", "7 empty DeviceName: publishes on muh/berry/UNKNOWN/status")

# ---- 8. library only ----
boot_as("Good", {"GOOD": ""})
check(MUH_STATUS["lib"] == true && MUH_STATUS["script"] == "" && MUH_STATUS["ok"] == true && MUH_STATUS["err"] == "",
  "8 library only: lib:true, script:'', ok:true")

# ---- 9. published payload ----
boot_as("Good", {"GOOD": "good.be"})
publish_status()
var pub = last_publish()
check(pub[2] == true, "9 payload: published retained")
var expected = ["lib", "script", "ok", "err", "device", "autoexec", "time", "uptime"]
var all_keys = pub[1].size() == expected.size()
for k : expected
  if !pub[1].contains(k) all_keys = false end
end
check(all_keys, f"9 payload: keys are exactly {expected}")
check(pub[1]["ok"] == true && pub[1]["script"] == "good.be" && pub[1]["autoexec"] == AUTOEXEC_VERSION
  && pub[1]["device"] == "Good" && pub[1]["time"] == "2026-01-01T00:00:00",
  "9 payload: status + device, autoexec version, local time")
check(pub[1]["uptime"] == nil, "9 payload: uptime null while the clock is not synced")
check(MUH_STATUS.size() == 4, "9 payload: publishing does not add keys to MUH_STATUS")
class SyncedRtc : TasmotaStub
  def rtc() return {"utc": 1700000100, "local": 1700007300, "restart": 1700000000} end
end
var stub = tasmota
tasmota = SyncedRtc()
publish_status()
tasmota = stub
check(last_publish()[1]["uptime"] == 100, "9 payload: uptime = utc - restart once the clock is synced")

# ---- 10. MQTT connection handling in muh_start() ----
DEVICENAME = "Good"
DEVICE_SCRIPTS = {"GOOD": "good.be"}
reset()
rules = {}
mqtt_is_connected = false
muh_start()
check(published.size() == 0, "10 offline: nothing published while MQTT is down")
check(rules.contains("mqtt#connected"), "10 offline: mqtt#connected rule registered")
rules["mqtt#connected"](nil, "mqtt#connected", nil)
check(published.size() == 1 && published[0][0] == "muh/berry/GOOD/status" && published[0][2] == true,
  "10 offline: rule publishes the retained status once")
reset()
rules = {}
mqtt_is_connected = true
muh_start()
check(published.size() == 1 && published[0][0] == "muh/berry/GOOD/status", "10 online: publishes immediately")
check(rules.contains("mqtt#connected"), "10 online: rule still registered for reconnects")

# ---- 11. the file's last block boots unless MUH_AUTOEXEC_NO_BOOT ----
MUH_AUTOEXEC_NO_BOOT = false
DEVICENAME = "hz_ww"
reset()
mqtt_is_connected = true
compile("../../../MUH/autoexec.be", "file")()
DEBUG = false
check(published.size() == 1 && published[0][0] == "muh/berry/HZ_WW/status", "11 boot block: runs muh_start() and publishes")
check(MUH_STATUS["lib"] == true && MUH_STATUS["err"] == "hz_ww.be: file not found",
  f"11 boot block: real map sends HZ_WW to hz_ww.be ({MUH_STATUS['err']})")
var bad_keys = []
for k : DEVICE_SCRIPTS.keys()
  if k != string.toupper(k) bad_keys.push(k) end
end
check(bad_keys.size() == 0, f"11 real map: every key is upper case {bad_keys}")

# ---- 12. gdhd.be-like propagation: sub-script error surfaces via raise ----
boot_as("Good", {"GOOD": "gdhd_like.be"})
check(MUH_STATUS["ok"] == false && has(MUH_STATUS["err"], "gdhd_like.be") && has(MUH_STATUS["err"], "boom at load"),
  f"12 gdhd-like error: err names gdhd_like.be and boom at load ({MUH_STATUS['err']})")

boot_as("Good", {"GOOD": "gdhd_ok.be"})
check(MUH_STATUS["ok"] == true, "12 gdhd-like ok: success variant reports ok")

os.chdir(ROOT)
finish()
