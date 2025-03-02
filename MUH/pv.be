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
var power_readings = []
var interval = 3
#var pv_active_power = energy.read()['active_power']
#var tstamp = tasmota.time_str(tasmota.rtc()['local'])

def getMaxPowerInverter()
  var data = tasmota.cmd('WebQuery http://192.168.22.59:8050/getMaxPower GET') 

  if data.contains('WebQuery') && data['WebQuery'] != "Connect failed"
    if data['WebQuery'].contains('data') && data['WebQuery']['data'].contains('maxPower')
      inverter_power = int(data['WebQuery']['data']['maxPower'])
    else
      inverter_power = max_inverter_power
    end
  else
    inverter_power = max_inverter_power
  end
  return inverter_power
end

def setMaxPowerInverter(power)
  tasmota.cmd(string.format("WebQuery http://192.168.22.59:8050/setMaxPower?p=%d GET", power)) 
  #print(string.format("MUH: PV setting %d watt ...", power))
  print(string.format("%s MUH: PV setting %d watt (%d watt)...", tasmota.time_str(tasmota.rtc()['local']), power, total_active_power))
end

def controlInverter()
  var inverter_value = getMaxPowerInverter()
  if inverter_value != nil
    #print(string.format("MUH: getMaxPowerInverter %d watt ...", inverter_value))
    # Remove readings older than the time window
    while power_readings.size() > interval
      power_readings.remove(0)
    end
    # Calculate the average power over the last
    var sum_power = 0
    for reading: power_readings
      sum_power = sum_power + reading
    end
    var average_power = sum_power / power_readings.size()

    if int(average_power) < max_load_power && int(total_active_power) < max_load_power
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

def getTotalActivePower(topic, idx, payload)
  var data = json.load(payload)

  # Check if the payload contains the "ENERGY" key and the "Power" array
  if data.contains('ENERGY') && data['ENERGY'].contains('Power')
    var power_data = data['ENERGY']['Power']

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
  # Add the current reading to the list
  power_readings.push(total_active_power)
end

# mqtt
mqtt.subscribe("tasmota/tele/tasmota_5FF8B2/SENSOR", getTotalActivePower)

# cron
# check every 10 seconds 
tasmota.add_cron("*/10 * 6-21 * * *", def (value) controlInverter() end, "controlInverter")

print(string.format("MUH: Loaded %s ...", devicename))
