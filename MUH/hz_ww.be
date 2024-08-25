#-
Backlog Template {"NAME":"Shelly Plus 1 ADDON","GPIO":[1344,1312,0,1,0,0,0,0,0,0,0,0,0,0,0,352,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0;
Backlog IPAddress1 192.168.22.74; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName HZ_WW; FriendlyName1 HZ_WW_PUMPE;
TempRes 1;
TelePeriod 3600;
Restart 1;
-#

import json
import mqtt
import string
import math

var devicename = tasmota.cmd("DeviceName")['DeviceName']
var sensors = json.load(tasmota.read_sensors())
var ds18b20_data = {}
ds18b20_data['TID'] = devicename
var ds18b20_list = []

for k: sensors.keys()
  if string.startswith(k,"DS18B20-")
    #print(k)
    ds18b20_list.push(k)
  end
end

for i: 0..ds18b20_list.size()-1
  if sensors.contains(ds18b20_list[i])
    ds18b20_data[ds18b20_list[i]] = {}
    ds18b20_data[ds18b20_list[i]]['DS18B20'] = {}
    ds18b20_data[ds18b20_list[i]]['DS18B20']['Id'] = sensors[ds18b20_list[i]]['Id']
    ds18b20_data[ds18b20_list[i]]['DS18B20']['Temperature'] = sensors[ds18b20_list[i]]['Temperature']
  end
end

# checkDelta
def checkDelta(current, last, threshold)
  if threshold == nil
    threshold = 1
  end
  return math.abs(current - last) >= threshold
end

# Publish
def publishMqtt(sensor)
  ds18b20_data[sensor]['TID'] = devicename
  ds18b20_data[sensor]['Time'] = tasmota.time_str(tasmota.rtc()['local'])
  #print(string.format("MQT: Publish %s", sensor))
  tasmota.publish(string.format("muh/sensors/%s/%s/json", devicename, sensor), json.dump(ds18b20_data[sensor]))
end

def checkDS18B20()
  sensors = json.load(tasmota.read_sensors())
  for i: 0..ds18b20_list.size()-1
    if sensors.contains(ds18b20_list[i])
      if checkDelta(sensors[ds18b20_list[i]]['Temperature'], ds18b20_data[ds18b20_list[i]]['DS18B20']['Temperature'])
        #print(string.format("BRY: Delta %s", ds18b20_list[i]))
        ds18b20_data[ds18b20_list[i]]['DS18B20']['Temperature'] = sensors[ds18b20_list[i]]['Temperature']
        publishMqtt(ds18b20_list[i])
      end
    end
  end
end

# boot
tasmota.add_rule("system#boot",
  def (value)
    for i: 0..ds18b20_list.size()-1
      if sensors.contains(ds18b20_list[i])
        if sensors[ds18b20_list[i]]['Temperature'] != 85 
          publishMqtt(ds18b20_list[i])
        else
          tasmota.set_timer((i+1)*2500, def (value) publishMqtt(ds18b20_list[i]) end, ds18b20_list[i])
        end
      end
    end
  end
)

# cron
tasmota.add_cron("10 */2 * * * *", def (value) checkDS18B20() end, "checkDS18B20")

#for i: 0..ds18b20_list.size()-1
#  if sensors.contains(ds18b20_list[i])
#    tasmota.add_rule(string.format("%s#Temperature", ds18b20_list[i]),
#      def (value)
#        if checkDelta(value, ds18b20_data[ds18b20_list[i]]['DS18B20']['Temperature'])
#          ds18b20_data[ds18b20_list[i]]['DS18B20']['Temperature'] = value 
#          publishMqtt(ds18b20_list[i])
#        end
#      end
#    )
#  end
#end
