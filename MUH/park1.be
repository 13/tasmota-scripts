import json
import mqtt
import string
import math

#-
{"NAME":"S2 Mini v1.0.0","GPIO":[32,1,1,7392,1,7456,1,7424,1,1,1,1,1,1,1,576,1888,1,0,0,0,1,1856,1,1,1,1,1,1,1,0,0,0,0,0,0],"FLAG":0,"BASE":1}

Backlog DisplayModel 19; DisplayMode 0; DisplayHeight 8; DisplayWidth 8;
-#

var threshold = 5
var distMax = 400
#- 0:stateNum, 1:stateNumLast, 2:distance -#
var sr04 = [-1, 0, 0]
var sensors = json.load(tasmota.read_sensors())
var timerOn = false

# checkDelta
def checkDelta(current, last, threshold)
  if threshold == nil
    threshold = 1
  end
  return math.abs(current - last) >= threshold
end

 # updateDisplay
def updateDisplay()
  if sr04[0] >= 0
     if sr04[0] != sr04[1]
       sr04[1] = sr04[0]
       tasmota.cmd(string.format("DisplayText %d", sr04[0]))
       tasmota.remove_timer("displayTimer")
       tasmota.set_timer(30000, def (value) tasmota.cmd('DisplayClear') end, "displayTimer")
     end
  else
    if !timerOn
      print(string.format("MUH: SR04 displayOff"))
      timerOn = true
      tasmota.remove_timer("displayTimer")
      tasmota.set_timer(30000, def (value) tasmota.cmd('DisplayClear') timerOn = false end, "displayTimer")
    end
  end
end

  # handleSR04
def handleSR04(value)
  if checkDelta(value, sr04[2], threshold)
    sr04[0] = -1
  else
    if value < 20
      sr04[0] = 0
    elif value < 40
      sr04[0] = 1
    elif value < 60
      sr04[0] = 2
    elif value < 80
      sr04[0] = 3
    elif value < 100
      sr04[0] = 4
    elif value < 120
      sr04[0] = 5
    elif value < distMax
      sr04[0] = 6
    else 
      sr04[0] = -1
    end
  end
  #print(string.format("MUH: SR04 %d", sr04[0]))
  # updateValue
  sr04[2] = value
  # updateDisplay
  updateDisplay()
end

class ParkAi
  def every_50ms()
    sensors = json.load(tasmota.read_sensors())
    if sensors != nil && sensors.contains('SR04') && sensors['SR04'].contains('Distance')
      handleSR04(sensors['SR04']['Distance'])
    end
  end
end

# load
print(string.format("MUH: Loading %s ...", devicename))
# poweron
tasmota.cmd('Power 1')
# bootscreen
tasmota.cmd(string.format("DisplayText Hoi"))

d1 = ParkAi()

# start
tasmota.add_rule("SR04#Distance",
  def (value)
    if !loaded
      loaded = true
      tasmota.set_timer(3000, def (value) tasmota.add_driver(d1) end)
      tasmota.remove_rule("SR04#Distance", "parkRule")
    end
  end, "parkRule")



