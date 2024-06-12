####### HD #######

import string
import mqtt

print(string.format("MUH: Loading %s...", devicename))

var gState = false
var gdlState = false
var ledChange = true
var xmas = ""

# Buttons
def handleButton(name,state)
  if name == "HDB"
    if state == 10
      tasmota.cmd(string.format("Backlog i2sgain 100; i2splay +/sfx/HDB%s.mp3; i2sgain %d", xmas, volume))
    end
  elif name == "HDBTN"
    if state == 10
      tasmota.publish("tasmota/cmnd/tasmota_9521A4/POWER", "2")
      tasmota.cmd("i2splay +/sfx/click0.mp3")
    elif state == 11 || state == 3
      tasmota.publish("muh/portal/RLY/cmnd", "G_T")
      tasmota.cmd("i2splay +/sfx/click2.mp3")
    elif state == 12
      tasmota.publish("muh/portal/RLY/cmnd", "GD_O")
      tasmota.cmd("i2splay +/say/GD_O.mp3")
    elif state == 13
      volume = volume > 0 ? 0 : 30
      tasmota.cmd(string.format("i2sgain %d", volume))
    end
  else
    print(string.format("MUH: handleButton() %s...", name))
  end
  tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{\"state\": %d, \"time\": \"%s\"}", state, tasmota.time_str(tasmota.rtc()['local'])), false) end)
end

# LED Status
def handleLED(name, value)
  if name == "G"
    if gState != value
      gState = value
      ledChange = true
    end
  elif name == "GDL"
    if gdlState != value
      gdlState = value
      ledChange = true
    end
  else
    print("MUH: handleLED() empty")
  end
  if ledChange
    if gState && gdlState
      tasmota.cmd("Power3 1")
    elif !gState && !gdlState
      tasmota.cmd("Power3 0")
    else
      tasmota.cmd("Power3 3")
    end
  end
  ledChange = false
end

# CRON
## MQTT Publish Status WatchDog
tasmota.add_cron("*/59 * * * * *", def (value) publishSwitch("HD","Mem1","Mem6") end, "wd_HD")
tasmota.add_cron("*/59 * * * * *", def (value) publishSwitch("HDL","Mem2","Mem7") end, "wd_HDL")
## AutoLock Night
tasmota.add_cron("0 0 0,1 * * *", def (value) if switch1 && !switch2 tasmota.set_power(0, true) end end, "autolock")
## Xmas Easteregg
tasmota.add_cron("0 0,30 * 24-26 12 *", def (value) xmas = "X" end, "xmas_on")
tasmota.add_cron("0 0,30 * 27 12 *", def (value) xmas = "" end, "xmas_off")

# RULES
## Audio Volume
#tasmota.add_rule("System#Boot", def (value) tasmota.cmd(string.format("i2sgain %d", volume)) end)
tasmota.cmd(string.format("i2sgain %d", volume))

## Switches
#tasmota.add_rule("System#Boot", def (value) handleSwitch("HD",switch1,"Mem1") end)
#tasmota.add_rule("System#Boot", def (value) handleSwitch("HDL",switch2,"Mem2") end)
handleSwitch("HD",switch1,"Mem1")
handleSwitch("HDL",switch2,"Mem2")
tasmota.add_rule("Switch1#state", def (value) switch1 = value tasmota.cmd(string.format("i2splay +/sfx/HD%s%s.mp3", value, xmas)) handleSwitch("HD",value,"Mem1","Mem6") end)
tasmota.add_rule("Switch2#state", def (value) switch2 = value handleSwitch("HDL",value,"Mem2","Mem7") end)
tasmota.add_rule("Switch4#state", def (value) tasmota.publish("muh/portal/HDP/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)

## Buttons
tasmota.add_rule("Button1#state", def (value) handleButton("HDB",value) end)
tasmota.add_rule("Button2#state", def (value) handleButton("HDBTN",value) end)
#tasmota.add_rule("Button1#state", def (value) tasmota.publish("muh/portal/HDB/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)
#tasmota.add_rule("Button1#state=10", def (value) tasmota.cmd(string.format("Backlog i2sgain 100; i2splay +/sfx/HDB%s.mp3; i2sgain %d", xmas, volume)) end)
#tasmota.add_rule("Button2#state", def (value) tasmota.publish("muh/portal/HDBTN/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)
#tasmota.add_rule("Button2#state=10", def (value) tasmota.publish("tasmota/cmnd/tasmota_9521A4/POWER", "2") tasmota.cmd("i2splay +/sfx/click0.mp3") end)
#tasmota.add_rule("Button2#state=11", def (value) tasmota.publish("muh/portal/RLY/cmnd", "G_T") tasmota.cmd("i2splay +/sfx/click2.mp3") end)
#tasmota.add_rule("Button2#state=12", def (value) tasmota.publish("muh/portal/RLY/cmnd", "GD_O") tasmota.cmd("i2splay +/say/GD_O.mp3") end)
#tasmota.add_rule("Button2#state=13", def (value) volume = volume > 0 ? 0 : 30 tasmota.cmd(string.format("i2sgain %d", volume)) end)
#tasmota.add_rule("Button2#state=3", def (value) tasmota.publish("muh/portal/RLY/cmnd", "G_T") tasmota.cmd("i2splay +/sfx/click2.mp3") end)


## MQTT Subscribe Remote Switches
### say & led
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe G, muh/portal/G/json, state") end)
tasmota.add_rule("Event#G", def (value) handleRemoteSwitch("G","Mem12",value) handleLED("G",number(value)) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe GDL, muh/portal/GDL/json, state") end)
tasmota.add_rule("Event#GDL", def (value) handleLED("GDL",number(value)) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe GD, muh/portal/GD/json, state") end)
tasmota.add_rule("Event#GD", def (value) handleRemoteSwitch("GD","Mem11",value) end)