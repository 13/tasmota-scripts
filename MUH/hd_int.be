#-
HD_INT

{"NAME":"Shelly Plus 2PM ADDON PCB v0.1.9","GPIO":[320,0,0,0,32,192,0,0,225,224,0,0,0,0,193,0,0,0,194,0,0,608,640,3458,0,0,0,0,0,9472,0,4736,0,0,0,0],"FLAG":0,"BASE":1}
Backlog PulseTime1 600; PulseTime2 300; SwitchMode3 1; SetOption114 1;
-#

import json
import mqtt
import string
import math

# Constants
var MQTT_TOPIC_PIR = "shellies/shellymotion2-8CF6811074B3/status"
var MQTT_TOPIC_PIR2 = "muh/portal/HDP/json"
var MQTT_TOPIC_REED = "muh/portal/HD/json"
var DARK_OFFSET = 180  # Offset in minutes for darkness detection

# Device names
var DEVICE_NAME = "HD_INT"
var DEVICE_NAME2 = "HD_GAR"

# State variables
var pir_state1 = tasmota.get_switches()[0]
var pir_state2 = tasmota.get_switches()[1]
var reed_state = tasmota.get_switches()[2]
var power_state = [tasmota.get_power()[0], tasmota.get_power()[1]]
var status_tim = nil


# Get status sunrise/sunset
def get_status_tim()
  status_tim = tasmota.cmd('Status 7')['StatusTIM']
end

# Check if it's dark based on sunrise and sunset times
def is_dark()
  var time_threshold = DARK_OFFSET * 60  # Convert offset to seconds
  var now = tasmota.rtc()['local']
  var now_dump = tasmota.time_dump(now)
  var now_date = string.format("%s-%s-%s", now_dump['year'], now_dump['month'], now_dump['day'])
  
  if status_tim != nil
    var sunrise = tasmota.strptime(string.format("%s %s", now_date, status_tim['Sunrise']), "%Y-%m-%d %H:%M")
    var sunset = tasmota.strptime(string.format("%s %s", now_date, status_tim['Sunset']), "%Y-%m-%d %H:%M")

    return now < sunrise['epoch'] + time_threshold || now > sunset['epoch'] - time_threshold
  else
    return false
  end
end

# Set power state with an optional timer to revert after 20 seconds
def set_power(state, id, timer)
  if id == nil
    id = 0
  end
  if timer == nil
    timer = false
  end

  tasmota.set_power(id, state)

  if id == 1
    tasmota.remove_timer(string.format("power_timer_%d", id))
    if timer
      tasmota.set_timer(25000, def () tasmota.set_power(id, !state) end, string.format("power_timer_%d", id))
    end
  end

end

# Process MQTT messages from subscribed topics
def process_mqtt_message(topic, idx, payload)
  var data = nil
  var turn_on = false

  try
    data = json.load(payload)
  except .. as e
    print("Failed to parse MQTT payload:", e)
    return
  end

  # Handle PIR sensor 1 (Shelly Motion)
  if string.find(topic, 'shellymotion2-8CF6811074B3') > -1 && data.contains('motion') && pir_state1 != data['motion']
    pir_state1 = bool(data['motion'])
  end

  # Handle PIR sensor 2 (HDP)
  if string.find(topic, 'HDP/json') > -1 && data.contains('state') && pir_state2 != data['state']
    pir_state2 = bool(data['state'])
  end

  # Handle reed sensor (HD)
  if string.find(topic, 'HD/json') > -1 && data.contains('state') && reed_state != data['state']
    reed_state = bool(data['state'])
  end

  # Turn on the light if conditions are met
  if pir_state1 && !pir_state2 && reed_state
    turn_on = true
  end

  if turn_on && is_dark()
    set_power(true, 0, true)
  end
end

# Rules to publish power state changes
tasmota.add_rule("Power1#state", def (value)
  if power_state[0] != tasmota.get_power()[0]
    var timestamp = tasmota.time_str(tasmota.rtc()['local'])
    power_state[0] = tasmota.get_power()[0]
    tasmota.publish(
      string.format("muh/lights/%s/json", DEVICE_NAME),
      string.format("{\"state\": %d, \"time\": \"%s\"}", int(power_state[0]), timestamp),
      true
    )
  end
end)

tasmota.add_rule("Power2#state", def (value)
  if power_state[1] != tasmota.get_power()[1]
    var timestamp = tasmota.time_str(tasmota.rtc()['local'])
    power_state[1] = tasmota.get_power()[1]
    tasmota.publish(
      string.format("muh/lights/%s/json", DEVICE_NAME2),
      string.format("{\"state\": %d, \"time\": \"%s\"}", int(power_state[1]), timestamp),
      true
    )
  end
end)

# Get sunrise/sunset
tasmota.add_rule("System#Init", def () get_status_tim() end)

# Rules to handle switch states
tasmota.add_rule("Switch1#state", def (value)
  #set_power(tasmota.get_switches()[0])
  set_power(!tasmota.get_power()[0])
end)

tasmota.add_rule("Switch2#state", def (value)
  #set_power(tasmota.get_switches()[1], 1)
  set_power(!tasmota.get_power()[1], 1)
end)

tasmota.add_rule("Switch3#state=1", def ()
  if !tasmota.get_power()[1] && is_dark()
    set_power(true, 1, true)
  end
end)

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # PIR sensor 1 (Shelly Motion)
mqtt.subscribe(MQTT_TOPIC_PIR2, process_mqtt_message)  # PIR sensor 2 (HDP)
mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (HD)

# cron
tasmota.add_cron("0 30 */3 * * *", def () get_status_tim() end, "get_status_tim")

print(string.format("MUH: Loaded %s ...", DEVICE_NAME))
