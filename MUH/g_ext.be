#-
G_EXT

Backlog Template {"NAME":"Shelly Plus 1PM","GPIO":[0,0,0,0,192,2720,0,0,0,0,0,0,0,0,2656,0,0,0,0,2624,0,32,224,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName G_EXT; FriendlyName1 G_EXT;
PowerOnState 0; PulseTime 600;
SwitchMode 5; SetOption1 1; SetOption32 30;
Restart 1;
-#

# Uses muh_lib.be (loaded by autoexec.be)
import json
import string

var DEVICE_NAME = "G_EXT"

# muh_lib config
DARK_OFFSET = 30
DARK_OFFSET_SUNSET = 30
POWER_TIMER_DURATION = 5

var MQTT_TOPIC_PIR = "muh/sensors/33c/json"
var MQTT_TOPIC_REED = "muh/sensors/6a7/json"

# State variables
var pir_state = false
var reed_state = true

# Process MQTT messages from subscribed topics
def process_mqtt_message(topic, idx, payload)
  var data = nil
  var turn_on = false

  try
    data = json.load(payload)
    if data == nil
      log(f"Invalid JSON: {payload}")
      return
    end
  except .. as e, m
    log(f"Failed to parse MQTT payload - {e}: {m}")
    return
  end

  # Handle PIR sensor (motion) state changes
  #if string.find(topic, '33c') > -1 && data.contains('M1') && pir_state != data['M1']
  #  pir_state = bool(data['M1'])
  #  turn_on = pir_state
  #end

  # Turn on the light if conditions are met
  if turn_on && is_dark()
    set_power(true, 0, true)
  end
end

init_power_publish(0, DEVICE_NAME)
init_sun()

# Manual switch-on during daylight reverts after POWER_TIMER_DURATION
tasmota.add_rule("Power1#state", def (value)
  if tasmota.get_power()[0] && !is_dark()
    set_power(true, 0, true)
  end
end)

# Subscribe to MQTT topics
#mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (door)
#mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # PIR sensor (motion)

log(f"Loaded {DEVICE_NAME} ...")
