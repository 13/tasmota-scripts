#- autoexec.be -#

import string
import mqtt
import persist

#var devicename = tasmota.cmd("DeviceName")['DeviceName']

var volume = 80
var volume_default = volume

var isOnline = true

print(string.format("MUH: Loading autoexec.be %s...", devicename))

# Custom Relay Cmd
def powerCmd(id,time)
  tasmota.set_power(id, true)
  if time != nil
    tasmota.set_timer(time, def (value) tasmota.set_power(id, false) end)
  end
end

#- MQTT Handler
def mqtt_handler(topic, idx, payload_s, payload_b)
  print("MUH: MQTT topic:",topic,", payload:",payload_s)
end-#
# MQTT Switch Publish & Store Status
def handleSwitchP(name, state, saveTimeOn)
  #print(string.format("MUH: handleSwitchP() %s %d,%s,%d...", name,state,saveTimeOn,int(persist.member(name))))
  if int(state) != int(persist.member(name))
    var tstamp = tasmota.time_str(tasmota.rtc()['local'])
    #print(string.format("MUH: handleSwitchP() %s write %d,%s...", name,state,tstamp))
    persist.setmember(string.format("%s",name),int(state))
    if !persist.has(string.format("%s_TIME",name)) || saveTimeOn != nil
      #print(string.format("MUH: handleSwitchP() #2 %s write %s,%s...", name,state,tstamp))
      persist.setmember(string.format("%s_TIME",name),string.format("%s",tstamp))
    end
    tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{\"state\": %d, \"time\": \"%s\"}", state, tstamp), true)
  end
end

# MQTT Publish only
def publishSwitchP(name)
  var state = int(persist.member(name))
  var tstamp = persist.member(string.format("%s_TIME",name))
  #print(string.format("MUH: publishSwitchP() %s %d,%s...", name,state,tstamp))
  tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{\"state\": %d, \"time\": \"%s\"}", state, tstamp), true)
end

# MQTT Remote Switch
def handleRemoteSwitchP(name,state)
  #print(string.format("MUH: handleRemoteSwitchP() %s %d,%d...", name,state,persist.member(name)))
  if int(state) != int(persist.member(name))
    #print(string.format("MUH: handleRemoteSwitchP() write %s %d,%d...", name,state,persist.member(name)))
    persist.setmember(string.format("%s",name),int(state))
    tasmota.cmd(string.format("i2splay /sfx/%s%d.mp3",name,state))
  end
end

# Fingerprint
#- RH:TH,IF,MF,RF,LF:[1,2,3,4,5] -#
#- LH:TH,IF,MF,RF,LF:[6,7,8,9,10] -#
#- ben:1-10,ann:11-20,mem:21:30,tre:31-40 -#
def publishFPrint(values,sound)
 tasmota.cmd(string.format("i2splay /sfx/FP%d.mp3", sound))
 tasmota.publish("muh/portal/FPRINT/json", string.format("{\"uid\": %d, \"confidence\": %d, \"time\": \"%s\", \"source\": \"%s\"}", values[0], values[1], tasmota.time_str(tasmota.rtc()['local']), devicename), false)
end

def checkDNS()
  if tasmota.cmd('IPAddress4')['IPAddress4'] == "0.0.0.0"
    tasmota.cmd('IPAddress4 192.168.22.6')
    tasmota.set_timer(5000, def (value) tasmota.cmd('restart 1') end)
  end
end

def checkIsOnline(state)
  if state == 0
    if !isOnline
      tasmota.cmd("restart 1")
    end
    isOnline= false
  else
    isOnline = true
  end
end

def chimePC()
  var hour =  int(tasmota.strftime("%I", tasmota.rtc()['local'])) + 1
  if hour == 5 || hour == 8 || hour == 11
    hour = 2
  elif hour == 6 || hour == 9 || hour == 12
    hour = 3
  elif hour == 7 || hour == 10
    hour = 4
  else
    #print(string.format("MUH: PC%d", hour))
  end
  tasmota.cmd(string.format("i2splay /sfx/PC%d.mp3", hour))
end

# CRON
## Persist
tasmota.add_cron("0 0 0 * * *", def (value) persist.save() end, "saveData")
tasmota.add_cron("10 */15 * * * *", def (value) tasmota.cmd("ping8 192.168.22.1") end, "checkWifi")
#tasmota.add_cron("8 0 21 * * *", def (value) tasmota.cmd("ping8 192.168.22.1") end, "checkWifi")
#tasmota.add_cron("0 0 2 * * *", def (value) tasmota.cmd("restart 1") end, "restartAll")
tasmota.add_cron("15 1 */1 * * *", def (value) checkDNS() end, "checkDNS")
## PC
tasmota.add_cron("59 29 * * * *", def (value) tasmota.cmd("i2splay /sfx/PC1.mp3") end, "pcHalf")
tasmota.add_cron("59 59 * * * *", def (value) chimePC() end, "pcFull")
#tasmota.add_cron("59 59 * * * *", def (value) tasmota.cmd(string.format("i2splay /sfx/PC%d.mp3", int(tasmota.strftime("%I", tasmota.rtc()['local'])))) end, "pcFull")

# RULES
## checkWifi 
#tasmota.add_rule("Ping#192.168.22.1#Success", def (value) checkIsOnline(value) end)
tasmota.add_rule("Ping#192.168.22.1#Success==0", def (value) tasmota.cmd("restart 1") end)

# Load custom script
if devicename == "HD"
  load("hd.be")
elif devicename == "GD"
  load("gd.be")
else
  print(string.format("MUH: Unknown %s", devicename))
end

