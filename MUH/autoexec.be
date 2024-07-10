#- autoexec.be -#

import string
import mqtt
import persist

var devicename = tasmota.cmd("DeviceName")['DeviceName']

var volume = 30

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
    tasmota.cmd(string.format("i2splay +/sfx/%s%d.mp3",name,state))
  end
end

# Fingerprint
#- RH:TH,IF,MF,RF,LF:[1,2,3,4,5] -#
#- LH:TH,IF,MF,RF,LF:[6,7,8,9,10] -#
#- ben:1-10,ann:11-20,mem:21:30,tre:31-40 -#
def handleFPrint(values,sw1,sw2)
 var soundFPrint = 1
 if devicename == "HD"
   if sw1 && sw2
     powerCmd(1,1000)
   elif sw1 && !sw2
     powerCmd(0)
   else
     soundFPrint = 2
   end
 elif devicename == "GD"
   if values[0] % 5 == 0
     powerCmd(1)
   else
     powerCmd(2)
   end
 else
   print(string.format("MUH: FPrint missing: %s", devicename))
 end
 tasmota.cmd(string.format("i2splay +/sfx/FP%d.mp3", soundFPrint))
 tasmota.publish("muh/portal/FPRINT/json", string.format("{\"uid\": %d, \"confidence\": %d, \"time\": \"%s\", \"source\": \"%s\"}", values[0], values[1], tasmota.time_str(tasmota.rtc()['local']), devicename), false)
end

def checkDNS()
  if tasmota.cmd('IPAddress4')['IPAddress4'] == "253.0.0.0"
    tasmota.cmd('IPAddress4 192.168.22.6')
    tasmota.set_timer(5000, def (value) restart 1 end)
  end
end

# CRON
## Persist
tasmota.add_cron("0 0 0 * * *", def (value) persist.save() end, "saveData")
tasmota.add_cron("8 */5 * * * *", def (value) tasmota.cmd("ping8 192.168.22.1") end, "checkWifi")
#tasmota.add_cron("0 0 2 * * *", def (value) tasmota.cmd("restart 1") end, "restartAll")
## PC
tasmota.add_cron("59 29 * * * *", def (value) tasmota.cmd("i2splay +/sfx/PC.mp3") end, "pcHalf")
tasmota.add_cron("59 59 * * * *", def (value) tasmota.cmd("i2splay +/sfx/PC3.mp3") end, "pcFull")

# RULES
## MQTT & HTTP API
### DOORS
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe RLY, muh/portal/RLY/cmnd") end)
tasmota.add_rule("Event#"+str(devicename)+"_L=1", def (value) powerCmd(0) end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_L", def (value) powerCmd(0) end)
## checkWifi 
tasmota.add_rule("Ping#192.168.22.1#Success==0", def (value) tasmota.cmd("restart 1") end)

# Load custom script
if devicename == "HD"
  load("hd.be")
elif devicename == "GD"
  load("gd.be")
else
  print(string.format("MUH: Unknown %s", devicename))
end
