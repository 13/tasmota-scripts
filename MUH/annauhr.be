#-
Backlog Template {"NAME":"AnnaUhr","GPIO":[0,0,0,0,1216,0,0,0,0,32,0,0,0,0,0,0,0,640,608,0,0,0,0,0,0,0,0,0,7104,7136,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0;

DeviceName AnnaUhr; FriendlyName1 AnnaUhrDisplay;
Backlog DisplayScrollDelay 8; DisplayDimmer 13; DisplayClock 2;
-#

import json
import mqtt
import string
import math

var tempIn = json.load(tasmota.read_sensors())['AM2301']['Temperature']
var tempOut = ""

# updateDisplay
def showClock()
  tasmota.cmd("DisplayClock 2")
end

def showTempIn()
  tasmota.cmd(string.format("DisplayText %dC", math.round(tempIn)))
end

def showTempOut()
  if tempOut != ""
    tasmota.cmd(string.format("DisplayText %dA", math.round(tempOut)))
  end 
end

# DisplayDimmer
def checkDimmer(value)
  var dimmer = int(tasmota.cmd("DisplayDimmer")['DisplayDimmer'])
  if value == 100
    if dimmer != 100
      tasmota.cmd("DisplayDimmer 100")
    end
  end
  if value == 13
    if dimmer != 13
      tasmota.cmd("DisplayDimmer 13")
    end
  end
end

# cron
# DisplayDimmer
tasmota.add_cron("0 * 7-18 * * *", def (value) checkDimmer(100) end, "DimmerHigh")
tasmota.add_cron("0 * 1-6,19-23 * * *", def (value) checkDimmer(13) end, "DimmerLow")
# cycle
tasmota.add_cron("5,20,35,50 */1 * * * *", def (value) showTempIn() end, "showTempIn")
tasmota.add_cron("10,25,40,55 */1 * * * *", def (value) showTempOut() end, "showTempOut")
tasmota.add_cron("15,30,45,0 */1 * * * *", def (value) showClock() end, "showClock")

# boot
tasmota.add_rule("system#init",
  def (value)
    tasmota.cmd("DisplayDimmer 13")
    tasmota.cmd("DisplayClock 2")
  end
)

# Rules
# tempIn
tasmota.add_rule("am2301#Temperature", def (value) tempIn = value end)
# tempOut
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe TempOut, muh/wst/data/B327, temp_c") end)
tasmota.add_rule("Event#TempOut", def (value) tempOut = int(value) end)

# boot
tasmota.add_rule("system#init",
  def (value)
    tasmota.cmd("DisplayDimmer 13")
    tasmota.cmd("DisplayClock 2")
  end
)
