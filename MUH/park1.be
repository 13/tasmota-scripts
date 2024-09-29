import json
import mqtt
import string
import math

class ParkAi

  var distMax    # max distance
  var sr04       # sr1_state, sr1_distance, sr1_stateNum, sr1_stateNumLast, displayON
  var sensors

  def init()
    self.distMax = 200
    self.sr04 = [false, 0, 0, 0, false]
    self.sensors = ""
    tasmota.cmd('Power 1')
  end

  # checkDelta
  def checkDelta(current, last, threshold)
    if threshold == nil
      threshold = 1
    end
    return math.abs(current - last) >= threshold
  end

  # updateDisplay
  def updateDisplay()
    if self.sr04[0] 
      if !self.sr04[4] || self.sr04[3] != self.sr04[2]
        self.sr04[3] = self.sr04[2]
        self.sr04[4] = true
        tasmota.cmd(string.format("DisplayText %s"), self.sr04[2])
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
  def handleSR04(value)
    #print(string.format("MUH: SR04-%d new: %d, old: %d, state: %s", id, value, sr04[1], sr04[0]))
    if value > self.distMax || self.checkDelta(value, self.sr04[1])
      self.sr04[0] = false
    else
      self.sr04[0] = true
      if value < 20
        self.sr04[2] = 0
      elif value < 30
        self.sr04[2] = 1
      elif value < 40
        self.sr04[2] = 2
      elif value < 50
        self.sr04[2] = 3
      elif value < 60
        self.sr04[2] = 4
      elif value < 70
        self.sr04[2] = 5
      else 
        self.sr04[2] = 6
      end
    end
    # updateValue
    self.sr04[1] = value
    # updateDisplay
    self.updateDisplay()
  end

  def every_50ms()
    self.sensors = json.load(tasmota.read_sensors())
    self.handleSR04(self.sensors['SR04-1']['Distance'])
  end
end

p1 = ParkAi()
tasmota.add_driver(p1)
