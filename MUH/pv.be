#-

Backlog
Template {"NAME":"Shelly Plus Plug S","GPIO":[0,0,0,0,224,0,32,2720,0,0,0,0,0,0,0,2624,0,0,2656,0,0,288,289,0,0,0,0,0,0,4736,0,0,0,0,0,0],"FLAG":0,"BASE":1};
Module 0; Restart 1;

Backlog
Template {"NAME":"Shelly Plus Plug S 4 LEDs","GPIO":[0,0,0,0,224,0,32,2720,0,0,0,0,0,0,0,2624,0,0,2656,0,0,1376,0,0,0,0,0,0,0,4736,0,0,0,0,0,0],"FLAG":0,"BASE":1};
Module 0; Restart 1;

Backlog DeviceName PlusPlugS; FriendlyName1 PlusPlugS; PowerDelta 101; PowerOnState 0; Restart 1;

ZERO FEED

http://192.168.22.59:8050/getOutputData
-> data.p1 + data.p2 => 300 + 400 = 700
http://192.168.22.59:8050/getMaxPower
-> data.maxPower => 800
http://192.168.22.59:8050/setMaxPower?p=800

-#

import json
import mqtt
import string
import math

var mqtt_topic_power = "tasmota/tele/tasmota_5FF8B2/SENSOR"

# Grundverbrauch ~= 150
var MAX_INVERTER_POWER = 800
var MIN_INVERTER_POWER = 600
var UPPER_THRESHOLD = 0
var LOWER_THRESHOLD = -500

var current_inverter_power = MAX_INVERTER_POWER
var power_usage = 0
#var pv_active_power = energy.read()['active_power']

def get_power_usage(topic, idx, payload)
  var data = nil

  try
    data = json.load(payload)
  except .. as e
    print("Failed to parse MQTT payload:", e)
    return
  end

  # Check if the payload contains the "ENERGY" key and the "Power" array
  if data.contains('ENERGY') && data['ENERGY'].contains('Power')
    # data['ENERGY']['Power'].isinstance(list)
    var power_data = data['ENERGY']['Power']

    # Calculate the sum of the Power array
    var power_usage_sum = 0
    for power_value: power_data
      power_usage_sum += int(power_value)  # Convert to integer and sum
    end
    #print("TotalPower:", power_sum)
    if power_usage_sum != nil
      power_usage = int(power_usage_sum)
    else
      power_usage = 0
    end
  else
    print(string.format("MUH: ERR MQTT %s ...", devicename))
    power_usage = 0
  end
end

def get_inverter_power()
  var data = tasmota.cmd('WebQuery http://192.168.22.59:8050/getMaxPower GET') 

  if data.contains('WebQuery') && data['WebQuery'] != "Connect failed"
    if data['WebQuery'].contains('data') && data['WebQuery']['data'].contains('maxPower')
      return int(data['WebQuery']['data']['maxPower'])
    end
  end

  return MAX_INVERTER_POWER
end

def set_inverter_power(power)
  print(string.format("%s MUH: PV setting %d watt (%d watt)...", tasmota.time_str(tasmota.rtc()['local']), power, power_usage))
  tasmota.cmd(string.format("WebQuery http://192.168.22.59:8050/setMaxPower?p=%d GET", power)) 
end

def control_inverter()
  var current_inverter_power = get_inverter_power()

    # Hysteresis logic
    if int(power_usage) < LOWER_THRESHOLD && int(current_inverter_power) != MIN_INVERTER_POWER
      set_inverter_power(MIN_INVERTER_POWER)
    elif int(power_usage) > UPPER_THRESHOLD && int(current_inverter_power) != MAX_INVERTER_POWER
      set_inverter_power(MAX_INVERTER_POWER)
    end
end

# mqtt
mqtt.subscribe(mqtt_topic_power, get_power_usage)

# cron
# check every 10 seconds 
tasmota.add_cron("* */5 6-21 * * *", def () control_inverter() end, "control_inverter")

print(string.format("MUH: Loaded %s ...", devicename))
