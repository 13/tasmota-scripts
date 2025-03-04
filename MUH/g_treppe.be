#-
G_TREPPE

PulseTime 160;
-#

import json
import mqtt
import string
import math

var pir_state = false
var reed_state = true
var power_state = tasmota.get_power()[0]

def is_dark() 
  var time_threshold = 25 * 60
  var statustim = tasmota.cmd('Status 7')['StatusTIM']
  var now = tasmota.rtc()['local']
  var now_dump = tasmota.time_dump(now)
  var now_date = string.format("%s-%s-%s", now_dump['year'], now_dump['month'], now_dump['day'])
  var sunrise = tasmota.strptime(string.format("%s %s", now_date, statustim['Sunrise']), "%Y-%m-%d %H:%M")
  var sunset = tasmota.strptime(string.format("%s %s", now_date, statustim['Sunset']), "%Y-%m-%d %H:%M")

  if now < sunrise['epoch'] + time_threshold || now > sunset['epoch'] - time_threshold
    return true
  else
    return false
  end
end

def setPowerTimer(state)
  tasmota.set_power(0, state)
  tasmota.remove_timer("powerTimer")
  tasmota.set_timer(20000, def (value) tasmota.set_power(0, !state) end, "powerTimer")
end

def process_mqtt_message(topic, idx, payload)
  var data = json.load(payload)
  var turn_on = false
 
  if string.find(topic, '6a7') > -1 && data.contains('S1') && reed_state != data['S1']
    reed_state = data['S1']
    if !reed_state
      turn_on = true
    end
  end

  if string.find(topic, '33c') > -1 && data.contains('M1') && pir_state != data['M1']
    pir_state = data['M1']
    if pir_state
      turn_on = true
    end
  end

  if turn_on && is_dark()
    setPowerTimer(true)
  end
end

# rules
tasmota.add_rule("Power1#state",
  def (value)
    if power_state != tasmota.get_power()[0]
      var tstamp = tasmota.time_str(tasmota.rtc()['local'])
      power_state = tasmota.get_power()[0]
      tasmota.publish(string.format("muh/lights/%s/json", devicename), string.format("{\"state\": %d, \"time\": \"%s\"}", power_state, tstamp), true)
    end
  end)

# mqtt
## g_treppe_door
mqtt.subscribe("muh/sensors/6a7/json", process_mqtt_message)
# g_treppe_pir
mqtt.subscribe("muh/sensors/33c/json", process_mqtt_message)

print(string.format("MUH: Loaded %s ...", devicename))
