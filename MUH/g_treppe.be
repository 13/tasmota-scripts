#-
G_TREPPE

Backlog Template {"NAME":"Shelly Plus1PMMini","GPIO":[576,32,0,4736,0,224,3200,8161,0,0,192,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName G_TREPPE; FriendlyName1 G_TREPPE;
SwitchMode 1; PulseTime1 160; Restart 1;
-#

# Uses muh_lib.be (loaded by autoexec.be)
import json
import mqtt
import string

var DEVICE_NAME = "G_TREPPE"

# muh_lib config
DARK_OFFSET = 90
DARK_OFFSET_SUNSET = 60
POWER_TIMER_DURATION = 22

var LUX_THRESHOLD = 35

var MQTT_TOPIC_PIR = "muh/sensors/80/json"
var MQTT_TOPIC_REED = "muh/sensors/64/json"
var MQTT_TOPIC_LUX = "muh/wst/data/B327"

# State variables
var pir_state = false
var reed_state = true
var lux_state = false

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

  # Handle reed sensor (door) state changes
  if string.find(topic, '64') > -1 && data.contains('SWITCH') && reed_state != data['SWITCH']
    reed_state = bool(data['SWITCH'])
    turn_on = !reed_state
  end

  # Handle PIR sensor (motion) state changes
  if string.find(topic, '80') > -1 && data.contains('PIR') && pir_state != data['PIR']
    pir_state = bool(data['PIR'])
    turn_on = pir_state
  end

  # Weather station lux
  if string.find(topic, 'B327') > -1 && data.contains('light_klx')
    lux_state = int(data['light_klx']) < LUX_THRESHOLD
  end

  # Turn on the light if conditions are met
  if turn_on && (is_dark() || lux_state)
    set_power(true, 0, true)
  end
end

init_power_publish(0, DEVICE_NAME)
init_sun()

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (door)
mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # PIR sensor (motion)
mqtt.subscribe(MQTT_TOPIC_LUX, process_mqtt_message)   # Lux (weather station)

log(f"Loaded {DEVICE_NAME} ...")
