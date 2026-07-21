#- HD -#

log(f"Loading hd.be on {DEVICENAME}...")

var switch1 = tasmota.get_switches()[0] # HD
var switch2 = tasmota.get_switches()[1] # HDL

var HD_LOCK_PIN = 0
var HD_UNLOCK_PIN = 1
var HD_LED_PIN = 2

var gState = false
var gdState = false
var gdlState = false
var ledChange = true
var xmas = ""           # Xmas Easteregg
var gdOffline = false

# Fingerprint
def handleFPrint(values, sw1, sw2)
  var soundFPrint = 1
  if sw1 && sw2
    powerCmd(HD_UNLOCK_PIN, 1000)
  elif sw1 && !sw2
    powerCmd(HD_LOCK_PIN)
  else
    soundFPrint = 2
  end
  publishFPrint(values, soundFPrint)
end

# Buttons
def handleButton(name, state)
  if name == "HDB"
    if state == 10
      tasmota.cmd(f"Backlog i2sgain 100; i2splay /sfx/HDB{xmas}.mp3; i2sgain {volume}")
    end
  elif name == "HDBTN"
    if state == 10
      mqtt.publish("tasmota/cmnd/tasmota_9521A4/POWER", "2")
      tasmota.cmd("i2splay /sfx/click0.mp3")
    elif state == 11 || state == 3
      mqtt.publish("muh/portal/RLY/cmnd", "G_T")
      tasmota.cmd("i2splay /sfx/click2.mp3")
    elif state == 12
      mqtt.publish("muh/portal/RLY/cmnd", "GD_O")
      tasmota.cmd("i2splay /say/GD_O.mp3")
    elif state == 13
      volume = volume > 0 ? 0 : volume_default
      tasmota.cmd(f"i2sgain {volume}")
    end
  else
    log(f"handleButton() {name}...")
  end
  mqtt.publish(f"muh/portal/{name}/json", json.dump({
    "state": state,
    "time": tasmota.time_str(tasmota.rtc()['local'])
  }), false)
end

# Blink LED
def blinkLED(id, time)
  tasmota.set_timer(time, def (value)
    tasmota.set_power(id, !tasmota.get_power()[id])
    blinkLED(id, time)
  end, "HD_LED")
end

# LED Status
def handleLED(name, value)
  if name == "G"
    if gState != value
      gState = value
      ledChange = true
    end
  elif name == "GD"
    if gdState != value
      gdState = value
      ledChange = true
    end
  elif name == "GDL"
    if gdlState != value
      gdlState = value
      ledChange = true
    end
  else
    log("handleLED() empty")
  end
  if ledChange
    tasmota.remove_timer("HD_LED")
    if gState && gdlState
      tasmota.set_power(HD_LED_PIN, true)
      tasmota.cmd("Color #005500") # green
    elif !gState && !gdlState
      tasmota.set_power(HD_LED_PIN, false)
      tasmota.cmd("Color #660000") # red
    elif gState && gdState && !gdlState
      tasmota.set_power(HD_LED_PIN, true)
      tasmota.cmd("Color #5A2F00") # yellow
    elif gState && !gdState && !gdlState
      tasmota.cmd("Color #5A2F00") # yellow
      blinkLED(HD_LED_PIN, 500)
    else
      tasmota.cmd("Color #660000") # red
      blinkLED(HD_LED_PIN, 1000)
    end
  end
  ledChange = false
end

def checkGD(state)
  if state == 0
    if gdOffline
      handleLED("G", 0)
      handleLED("GDL", 0)
    end
    gdOffline = true
  else
    gdOffline = false
  end
end

# CRON
## MQTT Publish Status WatchDog
tasmota.add_cron("20 */3 * * * *", def (value) publishSwitchP("HD") end, "wd_HD")
tasmota.add_cron("20 */3 * * * *", def (value) publishSwitchP("HDL") end, "wd_HDL")
## AutoLock Night
tasmota.add_cron("10 0 0,1 * * *", def (value) if switch1 && !switch2 tasmota.set_power(HD_LOCK_PIN, true) end end, "autolock")
## Xmas Easteregg
tasmota.add_cron("0 0,30 * 24-25 12 *", def (value) xmas = "X" end, "xmas_on")
tasmota.add_cron("0 0,30 * 26 12 *", def (value) xmas = "" end, "xmas_off")
## Check GD up
tasmota.add_cron("25 */3 * * * *", def (value) tasmota.cmd("ping4 192.168.22.91") end, "checkGD")

# RULES
## MQTT & HTTP API
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe RLY, muh/portal/RLY/cmnd") end)
tasmota.add_rule(f"Event#{DEVICENAME}_L=1", def (value) powerCmd(HD_LOCK_PIN) end)
tasmota.add_rule(f"Event#RLY={DEVICENAME}_L", def (value) powerCmd(HD_LOCK_PIN) end)
tasmota.add_rule(f"Event#{DEVICENAME}_U=1", def (value) powerCmd(HD_UNLOCK_PIN, 200) end)
tasmota.add_rule(f"Event#{DEVICENAME}_O=1", def (value) powerCmd(HD_UNLOCK_PIN, 1000) end)
tasmota.add_rule(f"Event#RLY={DEVICENAME}_U", def (value) powerCmd(HD_UNLOCK_PIN, 200) end)
tasmota.add_rule(f"Event#RLY={DEVICENAME}_O", def (value) powerCmd(HD_UNLOCK_PIN, 1000) end)
## Audio Volume
tasmota.cmd(f"i2sgain {volume}")
## FPrint
tasmota.add_rule(["FPrint#Id", "FPrint#Confidence>20"], def (values) handleFPrint(values, switch1, switch2) end)

## Switches
handleSwitchP("HD", switch1)
handleSwitchP("HDL", switch2)
tasmota.add_rule("Switch1#state", def (value)
  switch1 = value
  tasmota.cmd(f"i2splay /sfx/HD{value}{xmas}.mp3")
  handleSwitchP("HD", value, 1)
end)
tasmota.add_rule("Switch2#state", def (value)
  switch2 = value
  handleSwitchP("HDL", value, 1)
end)
tasmota.add_rule("Switch4#state", def (value)
  mqtt.publish("muh/portal/HDP/json", json.dump({
    "state": value,
    "time": tasmota.time_str(tasmota.rtc()['local'])
  }), false)
end)

## Buttons
tasmota.add_rule("Button1#state", def (value) handleButton("HDB", value) end)
tasmota.add_rule("Button2#state", def (value) handleButton("HDBTN", value) end)

## MQTT Subscribe Remote Switches (say & led)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe G, muh/portal/G/json, state") end)
tasmota.add_rule("Event#G", def (value) handleRemoteSwitchP("G", int(value)) handleLED("G", int(value)) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe GD, muh/portal/GD/json, state") end)
tasmota.add_rule("Event#GD", def (value) handleRemoteSwitchP("GD", int(value)) handleLED("GD", int(value)) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe GDL, muh/portal/GDL/json, state") end)
tasmota.add_rule("Event#GDL", def (value) handleLED("GDL", int(value)) end)

## checkGD
tasmota.add_rule("Ping#192.168.22.91#Success", def (value) checkGD(value) end)
