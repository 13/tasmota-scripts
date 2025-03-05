#-
G_TREPPE

PulseTime 160;
-#

import json
import mqtt
import string
import math

# Constants
var MQTT_TOPIC_PIR = "muh/sensors/33c/json"
var MQTT_TOPIC_REED = "muh/sensors/6a7/json"
var DARK_OFFSET = 120  # Offset in minutes for darkness detection

# State variables
var pir_state = false
var reed_state = true
var power_state = tasmota.get_power()[0]

# Check if it's dark based on sunrise and sunset times
def is_dark()
  var time_threshold = DARK_OFFSET * 60  # Convert offset to seconds
  var status_tim = tasmota.cmd('Status 7')['StatusTIM']
  var now = tasmota.rtc()['local']
  var now_dump = tasmota.time_dump(now)
  var now_date = string.format("%s-%s-%s", now_dump['year'], now_dump['month'], now_dump['day'])
  
  var sunrise = tasmota.strptime(string.format("%s %s", now_date, status_tim['Sunrise']), "%Y-%m-%d %H:%M")
  var sunset = tasmota.strptime(string.format("%s %s", now_date, status_tim['Sunset']), "%Y-%m-%d %H:%M")

  return now < sunrise['epoch'] + time_threshold || now > sunset['epoch'] - time_threshold
end

# Set power state with a timer to revert after 20 seconds
def set_power_timer(state)
  tasmota.set_power(0, state)
  tasmota.remove_timer("power_timer")
  tasmota.set_timer(20000, def () tasmota.set_power(0, !state) end, "power_timer")
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

  # Handle reed sensor (door) state changes
  if string.find(topic, '6a7') > -1 && data.contains('S1') && reed_state != data['S1']
    reed_state = data['S1']
    if !reed_state
      turn_on = true
    end
  end

  # Handle PIR sensor (motion) state changes
  if string.find(topic, '33c') > -1 && data.contains('M1') && pir_state != data['M1']
    pir_state = data['M1']
    if pir_state
      turn_on = true
    end
  end

  # Turn on the light if conditions are met
  if turn_on && is_dark()
    set_power_timer(true)
  end
end

# Rule to publish power state changes
tasmota.add_rule("Power1#state", def (value)
  if power_state != tasmota.get_power()[0]
    var timestamp = tasmota.time_str(tasmota.rtc()['local'])
    power_state = tasmota.get_power()[0]
    tasmota.publish(
      string.format("muh/lights/%s/json", devicename),
      string.format("{\"state\": %d, \"time\": \"%s\"}", power_state, timestamp),
      true
    )
  end
end)

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (door)
mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # PIR sensor (motion)

print(string.format("MUH: Loaded %s ...", devicename))
