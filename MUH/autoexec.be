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
  "G_TREPPE": "g_treppe.be",
  "G_EXT": "g_ext.be",
  "HD_INT": "hd_int.be"
}

# Logging function
def log(message)
  if DEBUG
    print(string.format("%s %s", LOG_PREFIX, message))
  end
end

# Get device name
var DEVICENAME = tasmota.cmd("DeviceName")['DeviceName']
var loaded = false

# Validate device name
if DEVICENAME == nil || DEVICENAME == ""
  log("Device name is empty or invalid. Cannot proceed.")
  return
end

log(string.format("AutoExec %s ...", DEVICENAME))

# Load custom script
if DEVICE_SCRIPTS.has(DEVICENAME)
  var script = DEVICE_SCRIPTS[DEVICENAME]
  log(string.format("Loading %s for %s", script, DEVICENAME))
  try
    load(script)
    loaded = true
  except .. as e
    log(string.format("Failed to load %s - %s", script, e))
  end
else
  log(string.format("Unknown device %s.", DEVICENAME))
end
