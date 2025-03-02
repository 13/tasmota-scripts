#-
G_TREPPE
-#

import json
import mqtt
import string
import math

var pir_state = false
var reed_state = true
var power_state = tasmota.get_power()[0]

# sunrise/sunset timers??
var statustim=tasmota.cmd('Status 7')['StatusTIM']
print(statustim['Sunrise'], statustim['Sunset'])

def setPowerTimer(state)
  tasmota.set_power(0, state)
  tasmota.remove_timer("powerTimer")
  tasmota.set_timer(20000, def (value) tasmota.set_power(0, !state) end, "powerTimer")
end

def getMqttState(topic, idx, payload)
  var data = json.load(payload)
 
  if topic.contains('6a7') && data.contains('S1') && reed_state != data['S1']
    reed_state = data['S1']
    if !reed_state
      setPowerTimer(true)
    end
  end
  if topic.contains('33c') && data.contains('M1') && reed_state != data['M1']
    pir_state = data('M1')
    if pir_state
      setPowerTimer(true)
    end
  end
  #print(string.format("MUH: ERR MQTT %s ...", devicename))
end

# rules
tasmota.add_rule("Power1#state",
  def (value)
    if power_state != tasmota.get_power()[0]
      power_state = tasmota.get_power()[0]
      tasmota.publish(string.format("muh/lights/%s/json", devicename), string.format("{\"state\": %d, \"time\": \"%s\"}", power_state, tstamp), true)
    end
  end)

# mqtt
## g_treppe_door
mqtt.subscribe("muh/sensors/6a7/json", getMqttState)
# g_treppe_pir
mqtt.subscribe("muh/sensors/33c/json", getMqttState)

print(string.format("MUH: Loaded %s ...", devicename))
