#-

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

# Grundverbrauch ~= 150
var max_load_power = -400
var max_inverter_power = 800
var min_inverter_power = 400

var inverter_power = max_inverter_power
var total_active_power = 0
#var pv_active_power = energy.read()['active_power']

def getMaxPowerInverter()
  var payload = tasmota.cmd('WebQuery http://192.168.22.59:8050/getMaxPower GET') 
  if payload.contains('WebQuery') && payload['WebQuery'].contains('data') && payload['WebQuery']['data'].contains('maxPower')
    inverter_power = int(payload['WebQuery']['data']['maxPower'])
  else
    inverter_power = max_inverter_power
  end
  return inverter_power
end

def setMaxPowerInverter(power)
  tasmota.cmd(string.format("WebQuery http://192.168.22.59:8050/setMaxPower?p=%d GET", power)) 
  print(string.format("MUH: PV setting %d watt ...", power))
end

def controlInverter()
  var inverter_value = getMaxPowerInverter()
  if inverter_value != nil
    #print(string.format("MUH: getMaxPowerInverter %d watt ...", inverter_value))
    if int(total_active_power) < max_load_power
      if int(inverter_value) == max_inverter_power
        setMaxPowerInverter(min_inverter_power)
      end
    else
      if int(inverter_value) != max_inverter_power
        setMaxPowerInverter(max_inverter_power)
      end
    end
  end
end

def getTotalActivePower(topic, idx, data, databytes)
  var mydata = json.load(data)

  # Check if the payload contains the "ENERGY" key and the "Power" array
  if mydata.contains('ENERGY') && mydata['ENERGY'].contains('Power')
    var power_data = mydata['ENERGY']['Power']

    # Calculate the sum of the Power array
    var power_sum = 0
    for power_value: power_data
      power_sum = power_sum + int(power_value)  # Convert to integer and sum
    end
    #print("TotalPower:", power_sum)
    if power_sum != nil
      total_active_power = int(power_sum)
    else
      total_active_power = 0
    end
  else
    print(string.format("MUH: ERR MQTT %s ...", devicename))
    total_active_power = 0
  end
end

# mqtt
mqtt.subscribe("tasmota/tele/tasmota_5FF8B2/SENSOR", getTotalActivePower)

# cron
# check every 10 seconds 
tasmota.add_cron("*/10 * * * * *", def (value) controlInverter() end, "controlInverter")

print(string.format("MUH: Loaded %s ...", devicename))
