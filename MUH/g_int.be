#-

G_INT

Backlog
Template {"NAME":"Shelly Plus 1PM","GPIO":[0,0,0,0,192,2720,0,0,0,0,0,0,0,0,2656,0,0,0,0,2624,0,32,224,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1};
Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;

DeviceName G_INT; FriendlyName1 G_INT;
PulseTime1 3600; SwitchMode1 0;
Restart 1;

-#

import json
import mqtt
import string
import math

# Constants
var DARK_OFFSET = 90            # Offset in minutes for darkness detection
var DARK_OFFSET_SUNSET = 20
var POWER_TIMER_DURATION = 300  # in seconds

var MQTT_TOPIC_PIR1 = "muh/portal/GDP/json"
var MQTT_TOPIC_REED1 = "muh/portal/G/json"
var MQTT_TOPIC_REED2 = "muh/portal/GD/json"

# Device names
var DEVICE_NAME = "G_INT"

# State variables
var pir_state1 = false
var reed_state1 = true
var reed_state2 = true 
var reed_trigger = false
var power_state = tasmota.get_power()
var status_tim = nil

# Get status sunrise/sunset
def get_status_tim()
  status_tim = tasmota.cmd('Status 7')['StatusTIM']
  print(status_tim)
end

# Check if it's dark based on sunrise and sunset times
def is_dark()
  if status_tim == nil
    return false
  end

  var time_threshold = DARK_OFFSET * 60  # Convert offset to seconds
  var time_threshold_sunset = DARK_OFFSET_SUNSET * 60
  var now = tasmota.rtc()['local']
  var now_dump = tasmota.time_dump(now)
  var now_date = string.format("%s-%s-%s", now_dump['year'], now_dump['month'], now_dump['day'])
  
  var sunrise = tasmota.strptime(string.format("%s %s", now_date, status_tim['Sunrise']), "%Y-%m-%d %H:%M")
  var sunset = tasmota.strptime(string.format("%s %s", now_date, status_tim['Sunset']), "%Y-%m-%d %H:%M")
  
  var sunrise_threshold = sunrise['epoch'] + time_threshold
  var sunset_threshold = sunset['epoch'] - time_threshold_sunset

  #print(string.format("Sunrise: %s, Sunset: %s", tasmota.strftime("%H:%M", sunrise['epoch']), tasmota.strftime("%H:%M", sunset['epoch'])))
  print(string.format("Sunrise: %s, Sunset: %s", tasmota.strftime("%H:%M", sunrise_threshold), tasmota.strftime("%H:%M", sunset_threshold)))

  return now < sunrise_threshold || now > sunset_threshold
end

# Set power state with an optional timer
def set_power(state, id, timer)
  if id == nil
    id = 0
  end
  if timer == nil
    timer = false
  end

  tasmota.set_power(id, state)

  tasmota.remove_timer(string.format("power_timer_%d", id))
  if timer
    tasmota.set_timer(POWER_TIMER_DURATION * 1000, def () tasmota.set_power(id, !state) end, string.format("power_timer_%d", id))
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

  # Handle PIR sensor
  if string.find(topic, 'GDP/json') > -1 && data.contains('state')
    pir_state1 = bool(data['state'])
  end

  # Handle reed sensor
  if string.find(topic, 'G/json') > -1 && data.contains('state')
    reed_state1 = bool(data['state'])
  end

  if string.find(topic, 'GD/json') > -1 && data.contains('state')
    reed_state2 = bool(data['state'])
  end

  # Turn on the light if conditions are met
  if !pir_state1 && (!reed_state1 || !reed_state2)
    if !reed_trigger
      turn_on = true
      reed_trigger = true
    end
  else
    if pir_state1 && (reed_state1 && reed_state2)
      reed_trigger = false
    end
  end

  if turn_on && is_dark()
    set_power(true, 0, true)
  end
end

def publish_power_state(id, device_name, power_state)
  var timestamp = tasmota.time_str(tasmota.rtc()['local'])
  tasmota.publish(
    string.format("muh/lights/%s/json", device_name),
    string.format("{\"state\": %d, \"time\": \"%s\"}", int(power_state[id]), timestamp),
    true
  )
end

# Rules to publish power state changes
tasmota.add_rule("Power1#state", def (value)
  if power_state[0] != tasmota.get_power()[0]
    power_state[0] = tasmota.get_power()[0]
    publish_power_state(0, DEVICE_NAME, power_state)
  end
end)

# Get sunrise/sunset
tasmota.add_rule("Time#Initialized", def () get_status_tim() end)

# Rules to handle switch states
tasmota.add_rule("Switch1#state", def (value)
  set_power(tasmota.get_power()[0])
end)

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_PIR1, process_mqtt_message)
mqtt.subscribe(MQTT_TOPIC_REED1, process_mqtt_message)
mqtt.subscribe(MQTT_TOPIC_REED2, process_mqtt_message)

# cron
tasmota.add_cron("0 30 */3 * * *", def () get_status_tim() end, "get_status_tim")

print(string.format("MUH: Loaded %s ...", DEVICE_NAME))
