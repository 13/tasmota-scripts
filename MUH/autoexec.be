#- autoexec.be -#

import string
import mqtt
import persist

var devicename = tasmota.cmd("DeviceName")['DeviceName']

var volume = 30

var cmdLock = "Power1 1"
var cmdUnlock = "Backlog Power2 1; Delay 2; Power2 0"
var cmdOpen = "Backlog Power2 1; Delay 10; Power2 0"

print(string.format("MUH: Loading autoexec.be %s...", devicename))

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
def handleFPrint(values,sw1,sw2)
 var soundFPrint = 1
 if devicename == "HD"
   if sw1 && sw2
     tasmota.cmd(str(cmdOpen))
   elif sw1 && !sw2
     tasmota.cmd(str(cmdLock))
   else
     soundFPrint = 2
   end
 elif devicename == "GD"
   #- RH TH,IF,MF,RF,LF [1,2,3,4,5] -#
   #- LH TH,IF,MF,RF,LF [6,7,8,9,10] -#
   if values[0] % 5 == 0
     tasmota.cmd(str(cmdOpen))
   else
   #  tasmota.cmd("Power3 1")
     tasmota.publish("muh/portal/RLY/cmnd", "G_T")
   end
 else
   print(string.format("MUH: FPrint missing: %s", devicename))
 end
 tasmota.cmd(string.format("i2splay +/sfx/FP%d.mp3", soundFPrint))
 tasmota.publish("muh/portal/FPRINT/json", string.format("{\"uid\": %d, \"confidence\": %d, \"time\": \"%s\", \"source\": \"%s\"}", values[0], values[1], tasmota.time_str(tasmota.rtc()['local']), devicename), false)
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
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe RLY, muh/portal/RLY/cmnd") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_L", def (value) tasmota.cmd(str(cmdLock)) end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_U", def (value) tasmota.cmd(str(cmdUnlock)) end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_O", def (value) tasmota.cmd(str(cmdOpen)) end)
tasmota.add_rule("Event#"+str(devicename)+"_L=1", def (value) tasmota.cmd(str(cmdLock)) end)
tasmota.add_rule("Event#"+str(devicename)+"_U=1", def (value) tasmota.cmd(str(cmdUnlock)) end)
tasmota.add_rule("Event#"+str(devicename)+"_O=1", def (value) tasmota.cmd(str(cmdOpen)) end)
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
