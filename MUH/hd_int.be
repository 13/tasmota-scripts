#-
HD_INT

{"NAME":"Shelly Plus 2PM ADDON PCB v0.1.9","GPIO":[320,0,0,0,32,192,0,0,225,224,0,0,0,0,193,0,0,0,194,0,0,608,640,3458,0,0,0,0,0,9472,0,4736,0,0,0,0],"FLAG":0,"BASE":1}
Backlog PulseTime1 600; PulseTime2 300; SwitchMode3 1; SetOption114 1;
-#

import json
import mqtt
import string
import math

var mqtt_topic_pir = "shellies/shellymotion2-8CF6811074B3/status"
var mqtt_topic_pir2 = "muh/portal/HDP/json"
var mqtt_topic_reed = "muh/portal/HD/json"

var dark_offset = 120

var devicename2 = "HD_GAR"
var pir_state1 = false
var pir_state2 = false
var reed_state = false
var power_state = [tasmota.get_power()[0], tasmota.get_power()[1]]

def is_dark() 
  var time_threshold = dark_offset * 60
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

def setPower(state, id, timer)
  if id == nil
    id = 0
  end
  if timer == nil
    timer = false
  end
  power_state[id] = state
  tasmota.set_power(id, state)
  if timer
    tasmota.remove_timer(string.format("powerTimer%d", id))
    tasmota.set_timer(20000, def (value) tasmota.set_power(id, !state) end, string.format("powerTimer%d", id))
  end
end

def process_mqtt_message(topic, idx, payload)
  var data = nil
  var turn_on = false

  try
    data = json.load(payload)
  except .. as e
    print("Failed to parse MQTT payload:", e)
    return
  end
 
  if string.find(topic, 'shellymotion2-8CF6811074B3') > -1 && data.contains('motion') && pir_state1 != data['motion']
    pir_state1 = data['motion']
  end

  if string.find(topic, 'HDP/json') > -1 && data.contains('state') && reed_state != data['state']
    pir_state2 = data['state']
  end

  if string.find(topic, 'HD/json') > -1 && data.contains('state') && pir_state1 != data['state']
    reed_state = data['state']
  end

  if pir_state1 && !pir_state2 && reed_state
    turn_on = true
  end

  if turn_on && is_dark()
    setPower(true, 0, true)
  end
end

# rules
tasmota.add_rule("Power1#state",
  def (value)
    if power_state[0] != tasmota.get_power()[0]
      var tstamp = tasmota.time_str(tasmota.rtc()['local'])
      power_state[0] = tasmota.get_power()[0]
      tasmota.publish(string.format("muh/lights/%s/json", devicename), string.format("{\"state\": %d, \"time\": \"%s\"}", power_state[0], tstamp), true)
    end
  end)
tasmota.add_rule("Power2#state",
  def (value)
    if power_state[1] != tasmota.get_power()[1]
      var tstamp = tasmota.time_str(tasmota.rtc()['local'])
      power_state[1] = tasmota.get_power()[1]
      tasmota.publish(string.format("muh/lights/%s/json", devicename2), string.format("{\"state\": %d, \"time\": \"%s\"}", power_state[1], tstamp), true)
    end
  end)

tasmota.add_rule("Switch1#state",
  def (value)
    setPower(value)
  end)
tasmota.add_rule("Switch2#state",
  def (value)
    setPower(value, 1)
  end)
tasmota.add_rule("Switch3#state=1",
  def ()
    if !power_state[1]
      if is_dark()
        setPower(true, 1, true)
      end
    end
  end)

# mqtt
## 
mqtt.subscribe(mqtt_topic_pir, process_mqtt_message)
mqtt.subscribe(mqtt_topic_pir2, process_mqtt_message)
mqtt.subscribe(mqtt_topic_reed, process_mqtt_message)

print(string.format("MUH: Loaded %s ...", devicename))
