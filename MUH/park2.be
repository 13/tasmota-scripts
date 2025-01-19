import json
import mqtt
import string
import math

#-
Backlog Template {"NAME":"SuperMini ESP32-S3","GPIO":[1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1],"FLAG":0,"BASE":1}; Module 0; restart 1;

Backlog DeviceName PARK2; FriendlyName1 park2Display;

DisplayModel 19; DisplayMode 0; DisplayHeight 8; DisplayWidth 8; restart 1;

-#

class ParkAi

  var distMax    # max distance
  var sr04       # sr1_state, sr1_distance, sr2_state, sr2_distance, displayON
  var sensors

  def init()
    self.distMax = 190
    self.sr04 = [false, 0, false, 0, false]
    self.sensors = ""
    tasmota.cmd('Power 1')
  end

  # checkDelta
  def checkDelta(current, last, threshold)
    if threshold == nil
      threshold = 4
    end
    return math.abs(current - last) >= threshold
  end

  # updateDisplay
  def updateDisplay()
    if self.sr04[0] && self.sr04[2]
      if !self.sr04[4]
        self.sr04[4] = true
        tasmota.cmd('DisplayText X')
        tasmota.remove_timer("displayTimer")
        tasmota.set_timer(30000, def (value) tasmota.cmd('DisplayClear') end, "displayTimer")
      end
    else
      if self.sr04[4]
        tasmota.remove_timer("displayTimer")
        tasmota.cmd('DisplayClear')
        self.sr04[4] = false
      end
    end
  end

  # handleSR04
  def handleSR04(id, value)
    if id == 1
      #print(string.format("MUH: SR04-%d new: %d, old: %d, state: %s", id, value, sr04[1], sr04[0]))
      if value > self.distMax || self.checkDelta(value, self.sr04[1])
        self.sr04[0] = false
      else
        self.sr04[0] = true
      end
      # updateValue
      self.sr04[1] = value
    end
    if id == 2
      #print(string.format("MUH: SR04-%d new: %d, old: %d, state: %s", id, value, sr04[3], sr04[2]))
      if value > self.distMax || self.checkDelta(value, self.sr04[3])
        self.sr04[2] = false
      else
        self.sr04[2] = true
      end
      # updateValue
      self.sr04[3] = value
    end
    # updateDisplay
    self.updateDisplay()
  end

  def every_50ms()
    self.sensors = json.load(tasmota.read_sensors())
    self.handleSR04(1,self.sensors['SR04-1']['Distance'])
    self.handleSR04(2,self.sensors['SR04-2']['Distance'])
  end
end

p1 = ParkAi()
tasmota.add_driver(p1)
