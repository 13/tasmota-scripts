#-
HD_INT

Backlog Template {"NAME":"Shelly Plus 2PM ADDON PCB v0.1.9","GPIO":[320,0,0,0,32,192,0,0,225,224,0,0,0,0,193,0,0,0,194,0,0,608,640,3458,0,0,0,0,0,9472,0,4736,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName HD_INT; FriendlyName1 HD_INT; FriendlyName2 HD_GAR;
SaveData 3600;
PulseTime1 600; PulseTime2 300; SwitchMode3 1; SetOption114 1; Restart 1;
-#

# Uses muh_lib.be (loaded by autoexec.be)
import json
import mqtt
import string

var DEVICE_NAME = "HD_INT"
var DEVICE_NAME2 = "HD_GAR"

# muh_lib config
DARK_OFFSET = 90
DARK_OFFSET_SUNSET = 60
POWER_TIMER_DURATION = 25

var LUX_THRESHOLD = 35

var MQTT_TOPIC_PIR = "shellies/shellymotion2-8CF6811074B3/status"
var MQTT_TOPIC_PIR2 = "muh/portal/HDP/json"
var MQTT_TOPIC_REED = "muh/portal/HD/json"
var MQTT_TOPIC_LUX = "muh/wst/data/B327"

# State variables
var pir_state1 = false
var pir_state2 = false
var reed_state1 = false
var reed_state2 = false
var last_reed_state2 = false
var hdl_unlocked = false
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

  # Handle PIR sensor 1 (Shelly Motion)
  if string.find(topic, 'shellymotion2-8CF6811074B3') > -1 && data.contains('motion')
    pir_state1 = bool(data['motion'])
  end

  # Handle PIR sensor 2 (HDP)
  if string.find(topic, 'HDP/json') > -1 && data.contains('state')
    pir_state2 = bool(data['state'])
  end

  # Handle reed sensor (HD)
  if string.find(topic, 'HD/json') > -1 && data.contains('state')
    reed_state1 = bool(data['state'])
    # Turn on the light if conditions are met
    if pir_state1 && !pir_state2 && !reed_state1 && hdl_unlocked
      turn_on = true
    end
  end

  # Handle reed sensor 2 (HDL)
  if string.find(topic, 'HDL/json') > -1 && data.contains('state')
    reed_state2 = bool(data['state'])
    hdl_unlocked = reed_state2 == false && reed_state2 != last_reed_state2
    last_reed_state2 = reed_state2
  end

  # Weather station lux
  if string.find(topic, 'B327') > -1 && data.contains('light_klx')
    lux_state = int(data['light_klx']) < LUX_THRESHOLD
  end

  #if turn_on && (is_dark() || lux_state)
  if turn_on && is_dark()
    set_power(true, 0, true)
  end
end

init_power_publish(0, DEVICE_NAME)
init_power_publish(1, DEVICE_NAME2)
init_sun()

# Rules to handle switch states
tasmota.add_rule("Switch1#state", def (value)
  set_power(!tasmota.get_power()[0])
end)

tasmota.add_rule("Switch2#state", def (value)
  set_power(!tasmota.get_power()[1], 1)
end)

tasmota.add_rule("Switch3#state=1", def ()
  if !tasmota.get_power()[1] && (is_dark() || lux_state)
    set_power(true, 1, true)
  end
end)

# Subscribe to MQTT topics
mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # PIR sensor 1 (Shelly Motion)
mqtt.subscribe(MQTT_TOPIC_PIR2, process_mqtt_message)  # PIR sensor 2 (HDP)
mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (HD)
mqtt.subscribe(MQTT_TOPIC_LUX, process_mqtt_message)   # Lux (weather station)

log(f"Loaded {DEVICE_NAME} ...")
