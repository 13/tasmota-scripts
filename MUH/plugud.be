#- PlugUD -#

#-
Backlog Template {"NAME":"Athom Plug V3","GPIO":[0,0,0,32,0,224,576,0,0,0,0,0,0,0,0,0,0,0,0,0,3104,0],"FLAG":0,"BASE":1}
; Module 0; Restart 1;

Backlog 
DeviceName PlugUD; FriendlyName1 PlugUD;
PowerOnState 1;
Restart 1;
-#

import json
import string
import math

print(string.format("MUH: Loading plugud.be on %s...", DEVICENAME))

var data = [
  { "id": 0, "ip": "192.168.22.20", "state": true }, # samstv
  { "id": 1, "ip": "192.168.22.28", "state": true }, # wzr ap
  { "id": 2, "ip": "192.168.22.11", "state": true }, # gold
  { "id": 3, "ip": "192.168.22.12", "state": true }  # g1
]

var buttonOverride= false

def checkPing(state, id)
  if buttonOverride 
    return;
  end
  if state == nil && id == nil
    if !data[0]["state"] && !data[1]["state"] && !data[2]["state"]
      if tasmota.get_power()[0]
        print(string.format("%s MUH: All devices are unreachable, turning off the plug", tasmota.time_str(tasmota.rtc()['local'])))
        tasmota.set_power(0, false)
      end
    end
  else
    for device : data
      if device["id"] == id
        device["state"] = state
        break
      end
    end

    if !data[0]["state"] && !data[1]["state"] && !data[2]["state"]
      if tasmota.get_power()[0]
        print(string.format("%s MUH: All devices are unreachable, turning off the plug", tasmota.time_str(tasmota.rtc()['local'])))
        tasmota.set_power(0, false)
      end
    else
      if !tasmota.get_power()[0]
        print(string.format("%s MUH: Devices %s is reachable, turning ON the plug", tasmota.time_str(tasmota.rtc()['local']), data[id]["ip"]))
        tasmota.set_power(0, true)
      end
    end
  end
end

# CRON
# Always turn on
#-
tasmota.add_cron("0 */5 7-10,12 * * *", def (value)
#tasmota.add_cron("*/10 * 7-23 * * *", def (value)
  if !tasmota.get_power()[0]
    for device : data
      device["state"] = true
    end
    tasmota.set_power(0, true)
    print("Plug was off. Turning it on.")
  end
end, "TurnPlugOn")
-#

for device : data
  #tasmota.add_cron(string.format("%d 0,30 23,0,1,2 * * *", device["id"] * 20), def (value) 
  #tasmota.add_cron(string.format("%d * 7-23 * * *", device["id"] * 5), def (value) 
  tasmota.add_cron(string.format("*/5 * 7-23 * * *"), def (value) 
    tasmota.cmd("ping1 " .. device["ip"]) 
  end, "checkPing" .. device["id"])
end

tasmota.add_cron(string.format("0 0,30 23,0-3 * * *"), def ()
  checkPing() 
end, "turn_off")

# Rules
for device : data
  tasmota.add_rule("Ping#" .. device["ip"] .. "#Reachable", def (value) 
    checkPing(value, device["id"]) 
  end)
end

# buttonOverride via MQTT
# mqtt.publish("muh/cmnd", "PLUGUD")
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe CMND, muh/cmnd") end)
tasmota.add_rule("Event#CMND", def (value)
  if value == "PLUGUD"
    print("Remote toggle received!")
    if !tasmota.get_power()[0]
      # Einschalten + Override aktivieren
      tasmota.set_power(0, true)
      buttonOverride = true
      print("Manual override activated: Plug will stay ON")
    else
      # Ausschalten + Override deaktivieren
      tasmota.set_power(0, false)
      buttonOverride = false
      print("Manual override deactivated: Plug follows Ping logic again")
    end
  end
end)
