#- PlugUD -#

#-
Backlog Template {"NAME":"Athom Plug V3","GPIO":[0,0,0,32,0,224,576,0,0,0,0,0,0,0,0,0,0,0,0,0,3104,0],"FLAG":0,"BASE":1}
; Module 0; Restart 1;

Backlog
Backlog
IPAddress1 192.168.22.31; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName PlugUD; FriendlyName1 PlugUD;
PowerOnState 1;
Restart 1;
-#

import string

print(string.format("MUH: Loading plugud.be on %s...", DEVICENAME))

var data = [
  { "id": 0, "ip": "192.168.22.20", "state": true, "fails": 0 }, # samstv
  { "id": 1, "ip": "192.168.22.28", "state": true, "fails": 0 }, # wzr ap
  { "id": 2, "ip": "192.168.22.11", "state": true, "fails": 0 }, # gold
  { "id": 3, "ip": "192.168.22.12", "state": true, "fails": 0 }  # g1
]

# Number of consecutive failed pings required before a device is marked
# unreachable. Single dropped packets (ping1 has no retry) must not flip
# state, since this plug powers the DVB-T antenna.
var PING_FAIL_THRESHOLD = 3

# Minimum time the plug stays on after any single reachable ping, even if
# every device goes unreachable right after. Each new reachable ping pushes
# this window out again, so the plug stays on continuously as long as pings
# keep landing within 10m of each other.
var KEEP_ON_SECONDS = 600
var keepOnUntil = 0

var buttonOverride = false

# FIX: replaces the old hardcoded "!data[0]&&!data[1]&&!data[2]" check, which
# silently ignored data[3] (g1). This loops over every entry in `data`, so it
# stays correct even if devices are added/removed later.
def allUnreachable()
  for device : data
    if device["state"]
      return false
    end
  end
  return true
end

def checkPing(state, id)
  if buttonOverride
    return
  end
  if state == nil && id == nil
    if allUnreachable() && tasmota.rtc()['local'] >= keepOnUntil && tasmota.get_power()[0]
      print(string.format("%s MUH: All devices are unreachable, turning off the plug", tasmota.time_str(tasmota.rtc()['local'])))
      tasmota.set_power(0, false)
    end
  else
    for device : data
      if device["id"] == id
        if state
          device["fails"] = 0
          device["state"] = true
          keepOnUntil = tasmota.rtc()['local'] + KEEP_ON_SECONDS
        else
          device["fails"] += 1
          if device["fails"] >= PING_FAIL_THRESHOLD
            device["state"] = false
          end
        end
        break
      end
    end

    if allUnreachable()
      # Even though every device is currently unreachable, don't turn off
      # until the 10m keep-on window from the last reachable ping has
      # elapsed. Otherwise a device flapping in and out would also flap the
      # antenna's power.
      if tasmota.rtc()['local'] >= keepOnUntil && tasmota.get_power()[0]
        print(string.format("%s MUH: All devices are unreachable, turning off the plug", tasmota.time_str(tasmota.rtc()['local'])))
        tasmota.set_power(0, false)
      end
    else
      if !tasmota.get_power()[0]
        # FIX: previously logged "data[id]['ip']" as "reachable" even when
        # this exact call was the device going DOWN. This branch just means
        # "at least one device is still up", not that `id` specifically is.
        print(string.format("%s MUH: At least one device is reachable, turning ON the plug", tasmota.time_str(tasmota.rtc()['local'])))
        tasmota.set_power(0, true)
      end
    end
  end
end

# CRON
for device : data
  tasmota.add_cron(string.format("*/5 * * * * *"), def (value)
    tasmota.cmd("ping1 " .. device["ip"])
  end, "checkPing" .. device["id"])
end

#tasmota.add_cron(string.format("0 0,30 23,0-3 * * *"), def ()
#  checkPing()
#end, "turn_off")

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
