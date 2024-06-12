import string
import mqtt

var devicename = tasmota.cmd("DeviceName")['DeviceName']
var switch1 = tasmota.get_switches()[0]
var switch2 = tasmota.get_switches()[1]
var switch3 = tasmota.get_switches()[2]

var volume = 30

print(string.format("MUH: Loading autoexec.be on %s...", devicename))

# CRON
## Pendeluhr
tasmota.add_cron("58 29 * * * *", def (value) tasmota.cmd("i2splay +/sfx/PC.mp3") end, "pndluhr_halb")
tasmota.add_cron("58 59 * * * *", def (value) tasmota.cmd("i2splay +/sfx/PC.mp3") end, "pndluhr_voll")

# MQTT Switch Publish & Store Status
def handleSwitch(name, value, memNameVal, memNameTstamp)
  if number(value) != number(tasmota.cmd(memNameVal)[memNameVal])
    var tstamp = tasmota.time_str(tasmota.rtc()['local'])
    tasmota.cmd(string.format("%s %d", memNameVal, value))
    if memNameTstamp != nil
      tasmota.cmd(string.format("%s %s", memNameTstamp, tstamp))
    end
    tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{\"state\": %d, \"time\": \"%s\"}", value, tstamp), true)
  end
end

# MQTT Publish only
def publishSwitch(name, memNameVal, memNameTstamp)
  var value = tasmota.cmd(memNameVal)[memNameVal]
  var tstamp = tasmota.cmd(memNameTstamp)[memNameTstamp]
  tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{\"state\": %d, \"time\": \"%s\"}", value, tstamp), true)
end

# MQTT Remote Switch
def handleRemoteSwitch(name,memName,value)
  var memNameValue = tasmota.cmd(string.format("%s", memName))[memName]
  if number(value) != number(memNameValue)
    tasmota.cmd(string.format("Backlog %s %s; i2splay +/sfx/%s%s.mp3", memName, value, name, value))
  end
end

# Fingerprint
def handleFPrint(values)
 var soundFPrint = 1
 if devicename == "HD"
   if switch1 && switch2
     tasmota.cmd("Backlog Power2 1; Delay 10; Power2 0")
   elif switch1 && !switch2
     tasmota.cmd("Power1 1")
   else
     soundFPrint = 2
   end
 elif devicename == "GD"
   tasmota.publish("muh/portal/RLY/cmnd", "G_T")
 else
   print(string.format("MUH: FPrint missing: %s", devicename))
 end
 tasmota.cmd(string.format("i2splay +/sfx/FP%d.mp3", soundFPrint))
 tasmota.publish("muh/portal/FPRINT/json", string.format("{\"uid\": %d, \"confidence\": %d, \"time\": \"%s\", \"source\": \"%s\"}", values[0], values[1], tasmota.time_str(tasmota.rtc()['local']), devicename), false)
end

# RULES
## FPrint
tasmota.add_rule(["FPrint#Id","FPrint#Confidence>20"], def (values) handleFPrint(values) end)
## MQTT & HTTP API
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe RLY, muh/portal/RLY/cmnd") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_L", def (value) tasmota.cmd("Power1 1") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_U", def (value) tasmota.cmd("Backlog Power2 1; Delay 2; Power2 0") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_O", def (value) tasmota.cmd("Backlog Power2 1; Delay 10; Power2 0") end)
tasmota.add_rule("Event#"+str(devicename)+"_L=1", def (value) tasmota.cmd("Power1 1") end)
tasmota.add_rule("Event#"+str(devicename)+"_U=1", def (value) tasmota.cmd("Backlog Power2 1; Delay 2; Power2 0") end)
tasmota.add_rule("Event#"+str(devicename)+"_O=1", def (value) tasmota.cmd("Backlog Power2 1; Delay 10; Power2 0") end)

# Load custom script
if devicename == "HD"
  load("hd.be")
elif devicename == "GD"
  load("gd.be")
else
  print(string.format("MUH: Unknown %s", devicename))
end