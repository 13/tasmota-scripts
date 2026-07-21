#-
HD_EXT

Backlog
Template {"NAME":"Shelly Plus 1PM","GPIO":[0,0,0,0,192,2720,0,0,0,0,0,0,0,0,2656,0,0,0,0,2624,0,32,224,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1};
Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;

DeviceName HD_EXT; FriendlyName1 HD_EXT;
PulseTime1 600; SwitchMode 1;
Restart 1;
-#

# Uses muh_lib.be (loaded by autoexec.be)
import json
import mqtt
import string

var DEVICE_NAME = "HD_EXT"

# muh_lib config
DARK_OFFSET = 0
DARK_OFFSET_SUNSET = 0
POWER_TIMER_DURATION = 20

var MQTT_TOPIC_PIR1 = "shellies/shellymotion2-8CF6811074B3/status"

# State variables
var pir_state1 = false

# Process MQTT messages from subscribed topics
def process_mqtt_message(topic, idx, payload)
  var data = nil

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
  if string.find(topic, 'shellymotion2-8CF6811074B3') > -1 && data.contains('motion')
    pir_state1 = bool(data['motion'])
  end

  # Turn on the light if conditions are met
  if pir_state1 && is_dark() && !tasmota.get_power()[0]
    set_power(true, 0, true)
  end
end

init_power_publish(0, DEVICE_NAME)
init_sun()

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_PIR1, process_mqtt_message)

log(f"Loaded {DEVICE_NAME} ...")
