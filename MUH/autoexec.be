#- autoexec.be -#

import string

# Configuration
var LOG_PREFIX = "MUH:"
var DEBUG = true

# Device-to-script mapping
var DEVICE_SCRIPTS = {
  "HD": "gdhd.be",
  "GD": "gdhd.be",
  "PARK1": "park1.be",
  "PARK2": "park2.be",
  "AnnaUhr": "annauhr.be",
  "HZ_WW": "hz_ww.be",
  "BAD": "bad.be",
  "PlugUD": "plugud.be",
  "PV": "pv.be",
  "PV_A": "pv_a.be",
  "PV_B": "pv_b.be",
  "G_TREPPE": "g_treppe.be",
  "G_EXT": "g_ext.be",
  "G_INT": "g_int.be",
  "HD_INT": "hd_int.be",
  "HD_EXT": "hd_ext.be",
  "FL2": "fl2.be",
  "FL3": "fl3.be",
  "WC": "wc.be",
}

# Logging function
def log(message)
  if DEBUG
    print(f"{LOG_PREFIX} {message}")
  end
end

def load_script(script)
  try
    load(script)
    return true
  except .. as e, m
    log(f"Failed to load {script} - {e}: {m}")
    return false
  end
end

# Get device name
var DEVICENAME = tasmota.cmd("DeviceName")['DeviceName']

# Validate device name
if DEVICENAME == nil || DEVICENAME == ""
  log("Device name is empty or invalid. Cannot proceed.")
  return
end

log(f"AutoExec {DEVICENAME} ...")

# Load shared helpers, then the device script
if DEVICE_SCRIPTS.has(DEVICENAME)
  var script = DEVICE_SCRIPTS[DEVICENAME]
  log(f"Loading {script} for {DEVICENAME}")
  if load_script("muh_lib.be")
    load_script(script)
  end
else
  log(f"Unknown device {DEVICENAME}.")
end
