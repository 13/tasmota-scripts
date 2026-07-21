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

# Uses muh_lib.be (loaded by autoexec.be)
import json
import mqtt
import string

var DEVICE_NAME = "G_INT"

# muh_lib config
DARK_OFFSET = 10
DARK_OFFSET_SUNSET = 20
POWER_TIMER_DURATION = 300

var MQTT_TOPIC_PIR1 = "muh/portal/GDP/json"
var MQTT_TOPIC_REED1 = "muh/portal/G/json"
var MQTT_TOPIC_REED2 = "muh/portal/GD/json"

# State variables
var pir_state1 = false
var reed_state1 = true
var reed_state2 = true
var reed_trigger = false

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

  # Handle PIR sensor
  if string.find(topic, 'GDP/json') > -1 && data.contains('state')
    pir_state1 = bool(data['state'])
  end

  # Handle reed sensors
  if string.find(topic, 'G/json') > -1 && data.contains('state')
    reed_state1 = bool(data['state'])
  end

  if string.find(topic, 'GD/json') > -1 && data.contains('state')
    reed_state2 = bool(data['state'])
  end

  # Turn on once per door-open cycle while no motion at the portal
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

init_power_publish(0, DEVICE_NAME)
init_sun()

# Rules to handle switch states
tasmota.add_rule("Switch1#state", def (value)
  set_power(tasmota.get_power()[0])
end)

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_PIR1, process_mqtt_message)
mqtt.subscribe(MQTT_TOPIC_REED1, process_mqtt_message)
mqtt.subscribe(MQTT_TOPIC_REED2, process_mqtt_message)

log(f"Loaded {DEVICE_NAME} ...")
