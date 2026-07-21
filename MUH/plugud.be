#- PlugUD -#

#-
Backlog Template {"NAME":"Athom Plug V3","GPIO":[0,0,0,32,0,224,576,0,0,0,0,0,0,0,0,0,0,0,0,0,3104,0],"FLAG":0,"BASE":1}
; Module 0; Restart 1;

Backlog IPAddress1 192.168.22.31; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName PlugUD; FriendlyName1 PlugUD;
PowerOnState 1;
Restart 1;
-#

log(f"Loading plugud.be on {DEVICENAME}...")

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
# keep landing within 10m of each other. millis()-based (monotonic), so an
# NTP step can't stretch or shrink the window; the subtraction below is
# wrap-safe. Initialized to boot time, which doubles as a boot grace period.
var KEEP_ON_MS = 600 * 1000
var lastReachableMs = tasmota.millis()

var buttonOverride = false

def allUnreachable()
  for device : data
    if device["state"]
      return false
    end
  end
  return true
end

def keepOnActive()
  return tasmota.millis() - lastReachableMs < KEEP_ON_MS
end

def checkPing(state, id)
  if buttonOverride
    return
  end

  for device : data
    if device["id"] == id
      if state
        device["fails"] = 0
        device["state"] = true
        lastReachableMs = tasmota.millis()
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
    # until the keep-on window from the last reachable ping has elapsed.
    # Otherwise a device flapping in and out would also flap the antenna's
    # power.
    if !keepOnActive() && tasmota.get_power()[0]
      log("All devices are unreachable, turning off the plug")
      tasmota.set_power(0, false)
    end
  else
    if !tasmota.get_power()[0]
      # This branch means "at least one device is still up", not that `id`
      # specifically is.
      log("At least one device is reachable, turning ON the plug")
      tasmota.set_power(0, true)
    end
  end
end

# CRON
for device : data
  tasmota.add_cron("*/5 * * * * *", def (value)
    tasmota.cmd(f"ping1 {device['ip']}")
  end, f"checkPing{device['id']}")
end

# Rules
for device : data
  tasmota.add_rule(f"Ping#{device['ip']}#Reachable", def (value)
    checkPing(value, device["id"])
  end)
end

# buttonOverride via MQTT
# mqtt.publish("muh/cmnd", "PLUGUD")
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe CMND, muh/cmnd") end)
tasmota.add_rule("Event#CMND", def (value)
  if value == "PLUGUD"
    log("Remote toggle received!")
    if !tasmota.get_power()[0]
      tasmota.set_power(0, true)
      buttonOverride = true
      log("Manual override activated: Plug will stay ON")
    else
      tasmota.set_power(0, false)
      buttonOverride = false
      log("Manual override deactivated: Plug follows Ping logic again")
    end
  end
end)
