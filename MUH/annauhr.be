#-
Backlog Template {"NAME":"AnnaUhr","GPIO":[0,0,0,0,1216,0,0,0,0,32,0,0,0,0,0,0,0,640,608,0,0,0,0,0,0,0,0,0,7104,7136,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; restart 1;

Backlog DeviceName AnnaUhr; FriendlyName1 AnnaUhrDisplay;
DisplayScrollDelay 8; DisplayDimmer 13; DisplayClock 2;
-#

import json
import mqtt
import string
import math

# Initialize temperature variables
var temp_in = json.load(tasmota.read_sensors())['AM2301']['Temperature']
var temp_out = nil
var mqtt_topic_temp = "muh/wst/data/B327"

# Helper function to display rounded temperature with proper positioning
def show_temp(temp, label)
  if temp != nil && temp != ""
    var rounded_temp = int(math.round(temp))
    var temp_size = size(str(rounded_temp))
    var pos = 3 - temp_size  # Calculate position based on number of digits (1-3 digits supported)
    tasmota.cmd(string.format("DisplayText %d^,%d", rounded_temp, pos))
  end
end

# Update display functions
def show_clock()
  tasmota.cmd("DisplayClock 2")
end

def show_temp_in()
  show_temp(temp_in, "TempIn")
end

def show_temp_out()
  show_temp(temp_out, "TempOut")
end

# Adjust display dimmer based on time of day
def check_dimmer(value)
  var dimmer = int(tasmota.cmd("DisplayDimmer")['DisplayDimmer'])
  if dimmer != value
    tasmota.cmd(string.format("DisplayDimmer %d", value))
  end
end

def get_temperature(topic, idx, payload)
  var data = nil

  try
    data = json.load(payload)
  except .. as e
    print("Failed to parse MQTT payload:", e)
    return
  end

  # Check if the payload contains the "ENERGY" key and the "Power" array
  if data.contains('temp_c') 
    temp_out = real(data['temp_c'])
  end
end

# Schedule display updates and dimmer adjustments
tasmota.add_cron("0 * 7-18 * * *", def () check_dimmer(100) end, "dimmer_high")  # Bright during daytime
tasmota.add_cron("0 * 1-6,19-23 * * *", def () check_dimmer(13) end, "dimmer_low")  # Dim during nighttime
tasmota.add_cron("5,20,35,50 */1 * * * *", show_temp_in, "show_temp_in")  # Show indoor temp
tasmota.add_cron("10,25,40,55 */1 * * * *", show_temp_out, "show_temp_out")  # Show outdoor temp
tasmota.add_cron("15,30,45,0 */1 * * * *", show_clock, "show_clock")  # Show clock

# Initialize display on boot
tasmota.add_rule("system#init", def ()
  tasmota.cmd("DisplayDimmer 13")
  tasmota.cmd("DisplayClock 2")
end)

# Update temperature variables
tasmota.add_rule("am2301#Temperature", def (value) temp_in = value end)  # Update indoor temp
mqtt.subscribe(mqtt_topic_temp, get_temperature)

print(string.format("MUH: Loaded %s ...", devicename))
