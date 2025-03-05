#- GD -#

print(string.format("MUH: Loading gd.be on %s...", devicename))

var switch1 = tasmota.get_switches()[0] # GD
var switch2 = tasmota.get_switches()[1] # GDL
var switch3 = tasmota.get_switches()[2] # G
#var switch4 = tasmota.get_switches()[3] # PIR
#var switch5 = tasmota.get_switches()[3] # LD2410

var GD_LOCK_PIN = 0
var GD_UNLOCK_PIN = 1
var G_TOGGLE_PIN = 2

var timerMillis = 600000      # AutoLock Timer
volume = 90                   # Audio Volume

var ld2410MotionDetected = false
var ld2410DistanceSum = 0

# Fingerprint
# 1-10 = 2 hands = 1st person
# 11-20 = 2nd person, 21-30 = 3rd person
# x1:RT,x2:RI,x3:RM,x4:RR,x5:RP
# x6:LT,x7:LI,x8:LM,x9:LR,x10:LP
# x1,x2,x6,x7 = G_TOGGLE_PIN
# x3,x4,x5,x8,x9,x10 = GD_UNLOCK_PIN
def handleFPrint(values,sw1,sw2)
  var soundFPrint = 1
  #if (values[0] - 1) % 5 == 0 || (values[0] - 2) % 5 == 0
  if (values[0] - 3) % 5 == 0 || (values[0] - 4) % 5 == 0 || (values[0] - 5) % 5 == 0
    powerCmd(GD_UNLOCK_PIN)
  else
    powerCmd(G_TOGGLE_PIN)
  end
  publishFPrint(values,soundFPrint)
end

# LD2410
def handleLD2410(values)
  if values[0] > 0 && values[1] > 0 && values[2] > 0
    #print(string.format("MUH: LD2410 detected motion %d", values[0]))
    var distanceSum = values[0] + values[1] + values[2]
    #print(string.format("MUH: LD2410 distance sum %d", distanceSum))
    if !ld2410MotionDetected && ld2410DistanceSum != distanceSum
      ld2410MotionDetected = true
      ld2410DistanceSum = distanceSum
      tasmota.set_timer(60000, def (value) ld2410MotionDetected = false end, "ld2410timer")
      mqtt.publish("muh/portal/GDMW1/json", string.format("{\"state\": 1, \"moving\": %d, \"static\": %d, \"detect\": %d, \"time\": \"%s\", \"source\": \"%s\"}", values[0], values[1], values[2], tasmota.time_str(tasmota.rtc()['local']), devicename), false)
    end
  else
    ld2410MotionDetected = false
  end
end

# Buttons
def handleButton(name,state)
  if name == "GDBTN"
    if state == 3 # hold
      powerCmd(G_TOGGLE_PIN)
      #tasmota.cmd("i2splay /sfx/click2.mp3")
    elif state == 10 # single
      mqtt.publish("tasmota/cmnd/tasmota_9521A4/POWER", "2")
      mqtt.publish("tasmota/cmnd/tasmota_3905F0/POWER", "0")
      #tasmota.cmd("i2splay /sfx/click0.mp3")
    elif state == 11 # double
      mqtt.publish("tasmota/cmnd/tasmota_BCD50C/POWER", "2")
      #powerCmd(G_TOGGLE_PIN)
      #tasmota.cmd("i2splay /sfx/click2.mp3")
    #elif state == 12 # triple
    #  mqtt.publish("muh/portal/RLY/cmnd", "G_T")
    #  tasmota.cmd("i2splay /sfx/click2.mp3")
    elif state == 13 # quad
      volume = volume > 0 ? 0 : volume_default
      tasmota.cmd(string.format("i2sgain %d", volume))
    end
  else
    print(string.format("MUH: handleButton() %s...", name))
  end
  mqtt.publish(string.format("muh/portal/%s/json", name), string.format("{\"state\": %d, \"time\": \"%s\"}", state, tasmota.time_str(tasmota.rtc()['local'])), false)
end

# AutoLock
def handleLock(swState, timerOn)
  var timerName = "timerLock"
  if timerOn == nil
    timerOn = swState
  end
  if swState && timerOn
    print(string.format("MUH: Starting timer GDL"))
    tasmota.remove_timer(timerName)
    tasmota.set_timer(timerMillis, def (value) powerCmd(GD_LOCK_PIN) end, timerName)
  else
    print(string.format("MUH: Stopping timer GDL"))
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
tasmota.add_rule(["FPrint#Id","FPrint#Confidence>10"], def (values) handleFPrint(values) end)
## LD2410
#tasmota.add_rule(["LD2410#Distance[0]","LD2410#Distance[1]","LD2410#Distance[2]"], def (values) handleLD2410(values) end)
tasmota.add_rule("LD2410#Distance", def (values) handleLD2410(values) end)

## Switches
if switch1 && !switch2
  handleLock(switch1,1)
end
handleSwitchP("GD",switch1)
handleSwitchP("GDL",switch2)
handleSwitchP("G",switch3)
tasmota.add_rule("Switch1#state", def (value) switch1 = value handleSwitchP("GD",value,1) handleLock(value) end)
tasmota.add_rule("Switch2#state", def (value) switch2 = value handleSwitchP("GDL",value,1) handleLock(value,0) end)
tasmota.add_rule("Switch3#state", def (value) switch3 = value handleSwitchP("G",value,1) end)
tasmota.add_rule("Switch4#state", def (value) mqtt.publish("muh/portal/GDP/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)
tasmota.add_rule("Switch5#state>0", def (value) mqtt.publish("muh/portal/GDMW2/json", string.format("{\"state\": %d, \"time\": \"%s\"}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)

## Buttons
tasmota.add_rule("Button1#state", def (value) handleButton("GDBTN",value) end)

## MQTT Subscribe Remote Switches
### sfx
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HD, muh/portal/HD/json, state") end)
tasmota.add_rule("Event#HD", def (value) handleRemoteSwitchP("HD",int(value)) end)
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HDB, muh/portal/HDB/json, state") end)
tasmota.add_rule("Event#HDB", def (value) tasmota.cmd("i2splay /sfx/HDB.mp3") end)

## MQTT Mobile Garage Opener
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe MGO, muh/sensors/caa/json, B1") end)
tasmota.add_rule("Event#MGO=1", def (value) if int(value) == 1 powerCmd(G_TOGGLE_PIN) end end)

