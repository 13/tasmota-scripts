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

print(string.format("MUH: Loading plugud.be on %s...", devicename))

var data = [
  { "id": 0, "ip": "192.168.22.20", "state": true },
  { "id": 1, "ip": "192.168.22.11", "state": true },
  { "id": 2, "ip": "192.168.22.12", "state": true }
]

def checkPing(state, id)
  for device : data
    if device["id"] == id
      device["state"] = state
      break
    end
  end

  if !data[0]["state"] && !data[1]["state"] && !data[2]["state"]
    print("All devices are unreachable, turning off the plug")
    tasmota.set_power(0, false)
  else
    if !tasmota.get_power()[0]
      print(string.format("Device %d is reachable, turning on the plug", id))
      tasmota.set_power(0, true)
    end
  end
end

# CRON
tasmota.add_cron("0 */5 7-10,12 * * *", def (value)
  if !tasmota.get_power()[0]
    for device : data
      device["state"] = true
    end
    tasmota.set_power(0, true)
    print("Plug was off. Turning it on.")
  end
end, "TurnPlugOn")

for device : data
  tasmota.add_cron(string.format("%d 0,30 23,0,1,2 * * *", device["id"] * 20), def (value) 
    tasmota.cmd("ping4 " .. device["ip"]) 
  end, "checkPing" .. device["id"])
end

# Rules
for device : data
  tasmota.add_rule("Ping#" .. device["ip"] .. "#Reachable", def (value) 
    checkPing(value, device["id"]) 
  end)
end
