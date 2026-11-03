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

var DEVICE_NAME = "HD_INT"
var DEVICE_NAME2 = "HD_GAR"

# muh_lib config
DARK_OFFSET = 90
DARK_OFFSET_SUNSET = 60
POWER_TIMER_DURATION = 25

var LUX_THRESHOLD = 35

var MQTT_TOPIC_PIR = "muh/portal/HDP/json"   # inside motion: PIR on the HD door unit (Switch4 in hd.be)
var MQTT_TOPIC_REED = "muh/portal/HD/json"   # front door reed: state 1 = closed, 0 = open
var MQTT_TOPIC_LUX = "muh/wst/data/B327"

# State variables
var motion_inside = false
var door_closed = nil   # nil until the first (retained) HD message arrives
var lux_state = false

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

  # Inside motion sensor (HDP)
  if topic == MQTT_TOPIC_PIR && data.contains('state')
    motion_inside = bool(data['state'])
  end

  # Front door (HD): light on when the door goes closed -> open while dark
  # and nobody is moving inside (someone inside opening the door = leaving,
  # no auto light). Edge-triggered so a retained "open" after
  # reboot/reconnect does nothing.
  if topic == MQTT_TOPIC_REED && data.contains('state')
    var closed = bool(data['state'])
    # skip if already on, so the timer never switches off a manually-on light
    if door_closed == true && !closed && !motion_inside && !tasmota.get_power()[0] && is_dark()
      set_power(true, 0, true)
    end
    door_closed = closed
  end

  # Weather station lux (used by Switch3 for HD_GAR)
  if topic == MQTT_TOPIC_LUX && data.contains('light_klx')
    lux_state = int(data['light_klx']) < LUX_THRESHOLD
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
mqtt.subscribe(MQTT_TOPIC_PIR, process_mqtt_message)   # Inside motion (HDP)
mqtt.subscribe(MQTT_TOPIC_REED, process_mqtt_message)  # Reed sensor (HD)
mqtt.subscribe(MQTT_TOPIC_LUX, process_mqtt_message)   # Lux (weather station)

log(f"Loaded {DEVICE_NAME} ...")
