#- G_EXT

Backlog Template {"NAME":"Shelly Plus 1PM","GPIO":[0,0,0,0,192,2720,0,0,0,0,0,0,0,0,2656,0,0,0,0,2624,0,32,224,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName G_EXT; FriendlyName1 G_EXT;
PowerOnState 0; PulseTime 600;
SwitchMode 5; SetOption1 1; SetOption32 30;
Restart 1;

-#

import json
import mqtt
import string
import math

# Constants
# Device names
var DEVICE_NAME = "G_EXT"

var DARK_OFFSET = 30            # Offset in minutes for darkness detection
var DARK_OFFSET_SUNSET = 30
var POWER_TIMER_DURATION = 5    # in seconds

var MQTT_TOPIC_PIR = "muh/sensors/33c/json"
var MQTT_TOPIC_REED = "muh/sensors/6a7/json"

# State variables
var pir_state = false
var reed_state = true
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

# Set power state with a timer to revert after 20 seconds
def set_power_timer(state)
  tasmota.set_power(0, state)
  tasmota.remove_timer("power_timer")
  tasmota.set_timer(POWER_TIMER_DURATION * 1000, def () tasmota.set_power(0, !state) end, "power_timer")
end

# Process MQTT messages from subscribed topics
def process_mqtt_message(topic, idx, payload)
  var data = nil
  var turn_on = false

  try
    data = json.load(payload)
    #print(data)
  except .. as e
    print("Failed to parse MQTT payload:", e)
    return
  end

  # Handle PIR sensor (motion) state changes
  #if string.find(topic, '33c') > -1 && data.contains('M1') && pir_state != data['M1']
  #  pir_state = bool(data['M1'])
  #  turn_on = pir_state
  #end

  # Turn on the light if conditions are met
  if turn_on && is_dark()
    set_power_timer(true)
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
  if tasmota.get_power()[0] && !is_dark()
    set_power_timer(true)
  end
end)

# Get sunrise/sunset
tasmota.add_rule("Time#Initialized", def () get_status_tim() end)

# Subscribe to MQTT topics
#mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (door)
#mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # PIR sensor (motion)
# cron
tasmota.add_cron("0 30 */3 * * *", def () get_status_tim() end, "get_status_tim")

print(string.format("MUH: Loaded %s ...", DEVICE_NAME))
