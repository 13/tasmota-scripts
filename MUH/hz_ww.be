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
var DS18B20_PREFIX = "DS18B20-"
var INVALID_TEMP = 85               # DS18B20 power-on / bus-error value
var DEFAULT_DELTA_THRESHOLD = 1
var BOOT_RETRY_MS = 5000            # re-read interval while a sensor still says 85 at boot
var BOOT_RETRIES = 6
var MIN_UPTIME_FOR_RESTART_MS = 120000   # never Restart from Berry inside Tasmota's boot-loop window

# sensor key ("DS18B20-3628FF") -> last published temperature
var last_temp = {}
var restart_allowed = false   # set once the boot-loop window is safely behind us

# Fresh read of all DS18B20 entries: key -> {'Id':..., 'Temperature':...}
def read_ds18b20()
  var out = {}
  var sensors = json.load(tasmota.read_sensors())
  if sensors == nil
    return out
  end
  for k: sensors.keys()
    if string.startswith(k, DS18B20_PREFIX)
      out[k] = sensors[k]
    end
  end
  return out
end

def publish_mqtt(key, s)
  var payload = {
    'time': tasmota.time_str(tasmota.rtc()['local']),
    'tid': DEVICENAME,
    'ds18b20': {'id': s['Id'], 'temperature': s['Temperature']}
  }
  mqtt.publish(f"muh/sensors/{DEVICENAME}/{key}/json", json.dump(payload), true)
  last_temp[key] = s['Temperature']
end

# Publish every valid sensor when forced, otherwise only on >= threshold change.
# 85 readings are never published.
def check_ds18b20(force)
  var all = read_ds18b20()
  for key: all.keys()
    var t = all[key].find('Temperature')
    if t == nil || t == INVALID_TEMP
      continue
    end
    var last = last_temp.find(key)
    if force || last == nil || math.abs(t - last) >= DEFAULT_DELTA_THRESHOLD
      publish_mqtt(key, all[key])
    end
  end
end

# Boot: publish what is valid now; while any sensor still reads 85, retry a
# few times with a FRESH read. Never restart the device for this — a restart
# inside the first 10 s trips Tasmota's boot-loop protection, which disables
# Berry entirely (that is how this device went silent for days).
def boot_publish(attempt)
  check_ds18b20(false)
  var all = read_ds18b20()
  var pending = []
  for key: all.keys()
    if all[key]['Temperature'] == INVALID_TEMP
      pending.push(key)
    end
  end
  if pending.size() == 0
    return
  end
  if attempt < BOOT_RETRIES
    log(f"ERR85 {pending}, retry {attempt + 1}/{BOOT_RETRIES}")
    tasmota.set_timer(BOOT_RETRY_MS, def () boot_publish(attempt + 1) end, "hz_ww_boot_retry")
  else
    log(f"ERR85 {pending} still invalid after {BOOT_RETRIES} retries, giving up until next cron")
  end
end

tasmota.add_rule("system#boot", def () boot_publish(0) end)
tasmota.set_timer(MIN_UPTIME_FOR_RESTART_MS, def () restart_allowed = true end, "hz_ww_restart_guard")

# Cron jobs
tasmota.add_cron("10 */2 * * * *", def () check_ds18b20(false) end, "check_ds18b20")
tasmota.add_cron("0 0 */1 * * *", def () check_ds18b20(true) end, "check_ds18b20_force")
tasmota.add_cron("10 */8 * * * *", def () tasmota.cmd("Ping4 192.168.22.1") end, "check_wifi")

# Wi-Fi watchdog: restart only once well past the boot-loop window
tasmota.add_rule("Ping#192.168.22.1#Success==0", def ()
  if restart_allowed
    log("gateway ping failed, restarting")
    tasmota.cmd("Restart 1")
  else
    log("gateway ping failed during boot window, ignored")
  end
end)
