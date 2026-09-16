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
import global

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

# Replaces Tasmota's global log(msg, level): calls with a level (Tasmota's own
# Berry code) go to the Tasmota log as before; device scripts call log(msg).
def log(message, level)
  if level != nil
    tasmota.log(message, level)
  elif DEBUG
    print(f"{LOG_PREFIX} {message}")
  end
end

# Compile and run a device file. Returns "" on success, otherwise
# "<file>: <exception>: <message>".
def run_file(fname)
  import path
  var p = string.startswith(fname, "/") ? fname : "/" + fname
  if !path.exists(p)
    if !path.exists(fname) return f"{fname}: file not found" end
    p = fname   # offline tests run in a plain directory
  end
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
var devicename = DEVICENAME   # legacy: pre-canonical annauhr.be on AnnaUhr reads it
var MUH_STATUS = {"lib": false, "script": "", "ok": false, "err": ""}

def muh_boot()
  MUH_STATUS = {"lib": false, "script": "", "ok": false, "err": ""}
  DEVICE_KEY = string.toupper(DEVICENAME != nil ? DEVICENAME : "")
  devicename = DEVICENAME
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
  var payload = {}
  for k : MUH_STATUS.keys() payload[k] = MUH_STATUS[k] end
  var rtc = tasmota.rtc()
  var utc = rtc.find("utc", 0)
  payload["device"] = DEVICENAME
  payload["autoexec"] = AUTOEXEC_VERSION
  payload["time"] = tasmota.time_str(rtc["local"])
  payload["uptime"] = (utc > 1600000000 && rtc.find("restart", 0) > 0) ? utc - rtc["restart"] : nil
  var key = DEVICE_KEY != "" ? DEVICE_KEY : "UNKNOWN"
  mqtt.publish(f"muh/berry/{key}/status", json.dump(payload), true)
end

def muh_start()
  log(f"AutoExec {DEVICENAME} ({AUTOEXEC_VERSION})")
  muh_boot()
  if MUH_STATUS["ok"]
    log(f"loaded lib + '{MUH_STATUS['script']}'")
  else
    log(f"LOAD FAILED: {MUH_STATUS['err']}")
  end
  # id: re-running autoexec replaces the rule instead of adding a second one
  tasmota.add_rule("mqtt#connected", def () publish_status() end, "muh_status")
  if mqtt.connected() publish_status() end
end

# Tasmota runs Berry in strict mode: reading an undeclared global does not
# compile, so the test flag is looked up through the global module.
if !global.contains("MUH_AUTOEXEC_NO_BOOT") || !global.MUH_AUTOEXEC_NO_BOOT
  muh_start()
end
