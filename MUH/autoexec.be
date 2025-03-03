#- autoexec.be -#

import string

var devicename = tasmota.cmd("DeviceName")['DeviceName']
var loaded = false

print(string.format("MUH: AutoExec %s ...", devicename))

# Load custom script
if devicename == "HD" || devicename == "GD"
  load("gdhd.be")
elif devicename == "PARK1"
  load("park1.be")
elif devicename == "PARK2"
  load("park2.be")
elif devicename == "AnnaUhr"
  load("annauhr.be")
elif devicename == "HZ_WW"
  load("hz_ww.be")
elif devicename == "BAD"
  load("bad.be")
elif devicename == "PlugUD"
  load("plugud.be")
elif devicename == "PV"
  load("pv.be")
elif devicename == "G_TREPPE"
  load("g_treppe.be")
else
  print(string.format("MUH: Unknown %s", devicename))
end

