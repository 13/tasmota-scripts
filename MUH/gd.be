####### GD #######
print(string.format("MUH: Loading %s...", devicename))

# Audio Volume
volume = 90
# AutoLock Timer
var timerMillis = 600000

# AutoLock
def handleLock(switchState, timerOn)
  var timerName = "timerLock"
  if timerOn == nil
    timerOn = switchState
  end
  if switchState && timerOn
    tasmota.set_timer(timerMillis, def (value) tasmota.set_power(0, true) end, timerName)
  else
    tasmota.remove_timer(timerName)
  end
end

# CRON
## MQTT Publish Status WatchDog
tasmota.add_cron("*/59 * * * * *", def (value) publishSwitch("GD","Mem1","Mem6") end, "wd_GD")
tasmota.add_cron("*/59 * * * * *", def (value) publishSwitch("GDL","Mem2","Mem7") end, "wd_GDL")

# RULES
## Audio Volume
tasmota.add_rule("System#Boot", def (value) tasmota.cmd(string.format("i2sgain %d", volume)) end)

## Switches
tasmota.add_rule("System#Init", def (value) handleLock(switch1,1) end)
tasmota.add_rule("System#Init", def (value) handleLock(switch2,0) end)
tasmota.add_rule("System#Boot", def (value) handleSwitch("GD",switch1,"Mem1") end)
tasmota.add_rule("System#Boot", def (value) handleSwitch("GDL",switch2,"Mem2") end)
#tasmota.add_rule("System#Boot", def (value) handleSwitch("GDW",switch3,"Mem3") end)
tasmota.add_rule("Switch1#state", def (value) switch1 = value handleSwitch("GD",value,"Mem1","Mem6") handleLock(value) end)
tasmota.add_rule("Switch2#state", def (value) switch2 = value handleSwitch("GDL",value,"Mem2","Mem7") handleLock(value,0) end)
#tasmota.add_rule("Switch3#state", def (value) switch3 = value handleSwitch("GDW",value,"Mem3","Mem8") end)
tasmota.add_rule("Switch4#state", def (value) tasmota.publish("muh/portal/GDP/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)

## MQTT Subscribe Remote Switches
### sfx
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HD, muh/portal/HD/json, state") end)
tasmota.add_rule("Event#HD", def (value) handleRemoteSwitch("HD","Mem11",value) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HDB, muh/portal/HDB/json, state") end)
tasmota.add_rule("Event#HDB", def (value) tasmota.cmd("i2splay +/sfx/HDB.mp3") end)