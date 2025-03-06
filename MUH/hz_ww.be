#-
Backlog Template {"NAME":"Shelly Plus 1 ADDON","GPIO":[1344,1312,0,1,0,0,0,0,0,0,0,0,0,0,0,352,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; Restart 1;

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

# Constants
DS18B20_PREFIX = "DS18B20-"
INVALID_TEMP = 85
DEFAULT_DELTA_THRESHOLD = 1

# Device name
var DEVICE_NAME = tasmota.cmd("DeviceName")['DeviceName']

# Read sensors and filter DS18B20 sensors
var sensors = json.load(tasmota.read_sensors())
var ds18b20_data = { 'tid': DEVICE_NAME }
var ds18b20_list = []

for k in sensors.keys()
  if string.startswith(k, DS18B20_PREFIX)
    ds18b20_list.push(k)
    ds18b20_data[k] = {
      'ds18b20': {
        'id': sensors[k]['Id'],
        'temperature': sensors[k]['Temperature']
      }
    }
  end
end

# Check if the temperature delta exceeds the threshold
def check_delta(current, last, threshold)
  if threshold == nil
    threshold = DEFAULT_DELTA_THRESHOLD
  end
  return math.abs(current - last) >= threshold
end

# Publish sensor data to MQTT
def publish_mqtt(sensor)
  ds18b20_data[sensor]['tid'] = DEVICE_NAME
  ds18b20_data[sensor]['time'] = tasmota.time_str(tasmota.rtc()['local'])
  tasmota.publish(string.format("muh/sensors/%s/%s/json", DEVICE_NAME, sensor), json.dump(ds18b20_data[sensor]))
end

# Check DS18B20 sensors and publish data if delta is exceeded or forced
def check_ds18b20(force_publish)
  if force_publish == nil
    force_publish = false
  end
  sensors = json.load(tasmota.read_sensors())
  for sensor_id in ds18b20_list
    if sensors.contains(sensor_id)
      var sensor_temp = sensors[sensor_id]['Temperature']
      if !force_publish
        if check_delta(sensor_temp, ds18b20_data[sensor_id]['ds18b20']['temperature']) && sensor_temp != INVALID_TEMP
          ds18b20_data[sensor_id]['ds18b20']['temperature'] = sensor_temp
          publish_mqtt(sensor_id)
        end
      else
        publish_mqtt(sensor_id)
      end
    end
  end
end

# Boot rule: Initialize and publish sensor data
tasmota.add_rule("system#boot",
  def (value)
    for i: 0..ds18b20_list.size()-1
      var sensor_id = ds18b20_list[i]
      if sensors.contains(sensor_id)
        var sensor_temp = sensors[sensor_id]['Temperature']
        if sensor_temp != INVALID_TEMP
          publish_mqtt(sensor_id)
        else
          print(string.format("BRY: ERR85 %s", sensor_id))
          tasmota.set_timer((2*i+1)*2000,
            def (value)
              if sensor_temp != INVALID_TEMP
                publish_mqtt(sensor_id)
              else
                tasmota.cmd("restart 1")
              end
            end,
          sensor_id)
        end
      end
    end
  end
)

# Cron jobs
tasmota.add_cron("10 */2 * * * *", def (value) check_ds18b20() end, "check_ds18b20")
tasmota.add_cron("0 0 */1 * * *", def (value) check_ds18b20(true) end, "check_ds18b20_force")
tasmota.add_cron("10 */8 * * * *", def (value) tasmota.cmd("ping4 192.168.22.1") end, "check_wifi")
tasmota.add_rule("Ping#192.168.22.1#Success==0", def (value) tasmota.cmd("restart 1") end)
