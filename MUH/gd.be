#- GD -#

print(string.format("MUH: Loading gd.be on %s...", devicename))

var switch1 = tasmota.get_switches()[0] # GD
var switch2 = tasmota.get_switches()[1] # GDL
var switch3 = tasmota.get_switches()[2] # G

var GD_LOCK_PIN = 0
var GD_UNLOCK_PIN = 1
var G_TOGGLE_PIN = 2

var timerMillis = 600000      # AutoLock Timer
volume = 90                   # Audio Volume

# Fingerprint
def handleFPrint(values,sw1,sw2)
 var soundFPrint = 1
 if values[0] % 5 == 0
   powerCmd(GD_UNLOCK_PIN)
 else
   powerCmd(G_TOGGLE_PIN)
 end
 publishFPrint(values,soundFPrint)
end

# AutoLock
def handleLock(swState, timerOn)
  var timerName = "timerLock"
  if timerOn == nil
    timerOn = swState
  end
  if swState && timerOn
    tasmota.remove_timer(timerName)
    tasmota.set_timer(timerMillis, def (value) powerCmd(GD_LOCK_PIN) end, timerName)
  else
    tasmota.remove_timer(timerName)
  end
end

# CRON
## MQTT Publish Status WatchDog
tasmota.add_cron("30 */3 * * * *", def (value) publishSwitchP("GD") end, "wd_GD")
tasmota.add_cron("30 */3 * * * *", def (value) publishSwitchP("GDL") end, "wd_GDL")
tasmota.add_cron("30 */3 * * * *", def (value) publishSwitchP("G") end, "wd_G")

# RULES
## MQTT & HTTP API
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe RLY, muh/portal/RLY/cmnd") end)
tasmota.add_rule("Event#"+str(devicename)+"_L=1", def (value) powerCmd(GD_LOCK_PIN) end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_L", def (value) powerCmd(GD_LOCK_PIN) end)
tasmota.add_rule("Event#"+str(devicename)+"_U=1", def (value) powerCmd(GD_UNLOCK_PIN) end)
tasmota.add_rule("Event#"+str(devicename)+"_O=1", def (value) powerCmd(GD_UNLOCK_PIN) end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_U", def (value) powerCmd(GD_UNLOCK_PIN) end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_O", def (value) powerCmd(GD_UNLOCK_PIN) end)
tasmota.add_rule("Event#G_T=1", def (value) powerCmd(G_TOGGLE_PIN) end)
tasmota.add_rule("Event#RLY=G_T", def (value) powerCmd(G_TOGGLE_PIN) end)
## Audio Volume
tasmota.cmd(string.format("i2sgain %d", volume))
## FPrint
tasmota.add_rule(["FPrint#Id","FPrint#Confidence>20"], def (values) handleFPrint(values) end)

## Switches
handleLock(switch1,1)
handleLock(switch2,0)
handleSwitchP("GD",switch1)
handleSwitchP("GDL",switch2)
handleSwitchP("G",switch3)
tasmota.add_rule("Switch1#state", def (value) switch1 = value handleSwitchP("GD",value,1) handleLock(value) end)
tasmota.add_rule("Switch2#state", def (value) switch2 = value handleSwitchP("GDL",value,1) handleLock(value,0) end)
tasmota.add_rule("Switch3#state", def (value) switch3 = value handleSwitchP("G",value,1) end)
tasmota.add_rule("Switch4#state", def (value) tasmota.publish("muh/portal/GDP/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)

## MQTT Subscribe Remote Switches
### sfx
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HD, muh/portal/HD/json, state") end)
tasmota.add_rule("Event#HD", def (value) handleRemoteSwitchP("HD",int(value)) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HDB, muh/portal/HDB/json, state") end)
tasmota.add_rule("Event#HDB", def (value) tasmota.cmd("i2splay +/sfx/HDB.mp3") end)

