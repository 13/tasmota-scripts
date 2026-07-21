#- gdhd.be — shared portal logic for HD + GD, then loads hd.be / gd.be -#

import string
import json
import mqtt
import persist

var volume = 80
var volume_default = volume

log(f"Loading gdhd.be on {DEVICENAME}...")

# Custom Relay Cmd
def powerCmd(id, time)
  tasmota.set_power(id, true)
  if time != nil
    tasmota.set_timer(time, def (value) tasmota.set_power(id, false) end)
  end
end

# MQTT Switch Publish & Store Status
def handleSwitchP(name, state, saveTimeOn)
  if int(state) != int(persist.member(name))
    var tstamp = tasmota.time_str(tasmota.rtc()['local'])
    persist.setmember(name, int(state))
    if !persist.has(f"{name}_TIME") || saveTimeOn != nil
      persist.setmember(f"{name}_TIME", str(tstamp))
    end
    mqtt.publish(f"muh/portal/{name}/json",
      json.dump({"state": int(state), "time": tstamp}), true)
  end
end

# MQTT Publish only
def publishSwitchP(name)
  var state = int(persist.member(name))
  var tstamp = persist.member(f"{name}_TIME")
  mqtt.publish(f"muh/portal/{name}/json",
    json.dump({"state": state, "time": tstamp}), true)
end

# MQTT Remote Switch
def handleRemoteSwitchP(name, state)
  if int(state) != int(persist.member(name))
    persist.setmember(name, int(state))
    tasmota.cmd(f"i2splay /sfx/{name}{int(state)}.mp3")
  end
end

# Fingerprint
#- RH:TH,IF,MF,RF,LF:[1,2,3,4,5] -#
#- LH:TH,IF,MF,RF,LF:[6,7,8,9,10] -#
#- ben:1-10,ann:11-20,mem:21:30,tre:31-40 -#
def publishFPrint(values, sound)
  tasmota.cmd(f"i2splay /sfx/FP{sound}.mp3")
  mqtt.publish("muh/portal/FP/json", json.dump({
    "fp_id": values[0],
    "confidence": values[1],
    "location": DEVICENAME,
    "ts": tasmota.time_str(tasmota.rtc()['local'])
  }), false)
end

def checkDNS()
  if tasmota.cmd('IPAddress4')['IPAddress4'] == "0.0.0.0"
    tasmota.cmd('IPAddress4 192.168.22.6')
  end
end

def chimePC()
  var hour = int(tasmota.strftime("%I", tasmota.rtc()['local'])) + 1
  if hour == 5 || hour == 8 || hour == 11
    hour = 2
  elif hour == 6 || hour == 9 || hour == 12
    hour = 3
  elif hour == 7 || hour == 10
    hour = 4
  end
  tasmota.cmd(f"i2splay /sfx/PC{hour}.mp3")
end

# CRON
## Persist
tasmota.add_cron("0 0 0 * * *", def (value) persist.save() end, "saveData")
tasmota.add_cron("10 10 */3 * * *", def (value) tasmota.cmd("ping4 192.168.22.1") end, "checkWifi")
tasmota.add_cron("15 1 */1 * * *", def (value) checkDNS() end, "checkDNS")
## PC chime
tasmota.add_cron("59 29 * * * *", def (value) tasmota.cmd("i2splay /sfx/PC1.mp3") end, "pcHalf")
tasmota.add_cron("59 59 * * * *", def (value) chimePC() end, "pcFull")

# RULES
## Restart when the gateway stops answering pings
tasmota.add_rule("Ping#192.168.22.1#Success==0", def (value) tasmota.cmd("restart 1") end)

# Load custom script
if DEVICENAME == "HD"
  load("hd.be")
elif DEVICENAME == "GD"
  load("gd.be")
else
  log(f"Unknown {DEVICENAME}")
end
