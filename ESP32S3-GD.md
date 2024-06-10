# ESP32-S3 GARAGEDOOR
## Template
```
{"NAME":"ESP32-S3-DevKitC-GD","GPIO":[1,640,608,1,7840,7808,7776,5984,163,160,161,1,1,1,1,6016,1,1,1,1,1,3616,0,0,0,0,0,1,1,1,1,1,1,1,1,1,256,257],"FLAG":0,"BASE":1}
```
## Table
| NAME | MODULE | GPIO | PIN | + | - | DESC |
|:--|:--|:--|--:|:--|---|---|
| **RTC** | | | | | | |
| SDA | I2C SDA | 1 | D01 | x | x | RTC DS3231 |
| SCL | I2C SCL | 2 | D02 | | | RTC DS3231 |
| **Reeds, Buttons & LEDS** | | | | | | |
| GD | Switch 1 | 9 | D09 | | x | Garage Door Reed |
| GDL | Switch 2 | 10 | D10 | 3v | x | Garage Door Lock Reed (with LED) |
| GDW | Switch 3 | 11 | D11 |   | x | Garage Door Window Reed |
| GD_BTN | Button | 12 | D12 |   | x | Garage Door Button |
| GD_LEDHDL | Relay 1 | 13 | D13 |   | x | Garage Door LED for HDL |
| G | Switch 4 | 38 | D38 |   | x | Garage Switch |
| **Relays** | | | | | | |
| GD_L | Relay_i 1 | 48 | D48 | | | Relay |
| GD_U | Relay_i 2 | 49 | D49 | | | Relay |
| G_T | Relay_i 3 | 14 | D14 | | | Relay |
| **I2S Audio** | | | | | | |
| LRC | I2S_WS | 4 | D04 | 5v | x | i2s |
| BCLK | I2S_BCLK | 5 | D05 | | | i2s |
| DIN | I2S_DOUT | 6 | D05 | | | i2s |
| **PIR** | | | | | | |
| GDP | Switch 4 | 8 | D08 | 3v | x | Garage Door PiR |
| **RFID** | | | | | | |
| RFID | RDM6300 RX | 21 | D21 | x | x | RFID |
| **FPRINT** | | | | | | |
| FPrint | As608 TX | 7 | D07 | x | x | RFID |
| FPrint | As608 RX | 15 | D15 | x | x | RFID |

```
        ~~~~~
i2s     ----- rtc
fprint  -ESP- relay
pir     -+ -- rfid
sensors 
```

## Settings
```
Backlog IPAddress1 192.168.22.91; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1
Backlog DeviceName GD; FriendlyName1 GD; 
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 1; SwitchTopic 0; SwitchDebounce 100;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
PulseTime1 2; PulseTime2 0;
```
### Rules
#### Rule 1
- Publish switches
#### Rule 2
- Autolock after 10m
- Event HTTP for relays
- Event MQTT for relays
- Publish RFID
- Fingerprint
#### Rule 3
- Sounds

```
Rule1
ON Switch1#Boot DO var1 %value% ENDON
ON Switch2#Boot DO var2 %value% ENDON
ON Switch3#Boot DO var3 %value% ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/portal/GD/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON System#Boot DO IF (%var2%!=%mem2%) mem2 %var2%; Publish2 muh/portal/GDL/json {"state": %var2%, "time": "%timestamp%"} ENDIF ENDON
ON System#Boot DO IF (%var3%!=%mem3%) mem3 %var3%; Publish2 muh/portal/GDW/json {"state": %var3%, "time": "%timestamp%"} ENDIF ENDON
ON Switch1#state!=%mem1% DO Backlog mem1 %value%; mem6 %timestamp%; Publish2 muh/portal/GD/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch2#state!=%mem2% DO Backlog mem2 %value%; mem7 %timestamp%; Publish2 muh/portal/GDL/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch3#state!=%mem3% DO Backlog mem3 %value%; mem8 %timestamp%; Publish2 muh/portal/GDW/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch4#state DO Publish muh/portal/GDP/json {"state": %value%, "time": "%timestamp%"} ENDON

Rule2
ON Time#Minute|1 DO Publish2 muh/portal/GD/json {"state": %mem1%, "time": "%mem6%"} ENDON
ON Time#Minute|1 DO Publish2 muh/portal/GDL/json {"state": %mem2%, "time": "%mem7%"} ENDON
ON Switch1#Boot=1 DO RuleTimer1 600 ENDON
ON Switch2#Boot=1 DO RuleTimer1 0 ENDON
ON Switch1#state=1 DO RuleTimer1 600 ENDON
ON Switch1#state=0 DO RuleTimer1 0 ENDON
ON Switch2#state=1 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 1 ENDON
ON FPrint#Id DO var9 %value% ENDON
ON FPrint#Confidence>20 DO Publish muh/portal/RLY/cmnd G_T ENDON
ON FPrint#Confidence>20 DO Publish muh/portal/FPRINT/json {"uid": %var9%, "confidence": %value%, "time": "%timestamp%", "source": "GD"} ENDON

Rule3
ON System#Boot DO i2sgain 100 ENDON
ON RDM6300#UID DO i2splay +/RFID1.mp3 ENDON
ON FPrint#Confidence>100 DO i2splay +/RFID1.mp3 ENDON
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD!=%mem11% DO Backlog mem11 %value%; i2splay +/HD%value%.mp3 ENDON
ON mqtt#connected DO Subscribe HDB, muh/portal/HDB/json, state ENDON
ON Event#HDB DO i2splay +/HDB.mp3 ENDON
```

-----

```
## SpeakerBox
Rule1
ON System#Boot DO i2sgain 100 ENDON
ON mqtt#connected DO Subscribe HDB, muh/portal/HDB/json, state ENDON
ON Event#HDB DO i2splay +/HDB.mp3 ENDON

Rule2
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD!=%mem10% DO Backlog mem10 %value%; i2splay +/HD%value%.mp3 ENDON
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G!=%mem11% DO Backlog mem11 %value%; i2splay +/G%value%.mp3 ENDON  
ON mqtt#connected DO Subscribe GD, muh/portal/GD/json, state ENDON
ON Event#GD!=%mem12% DO Backlog mem12 %value%; i2splay +/GD%value%.mp3 ENDIF ENDON
```
### Commands
```
http://192.168.22.91/cm?cmnd=event%20G%5FT=1
http://192.168.22.91/cm?cmnd=event%20GD%5FL=1
http://192.168.22.91/cm?cmnd=event%20GD%5FU=1
http://192.168.22.91/cm?cmnd=event%20GD%5FO=1
muh/portal/RLY/cmnd G_T
muh/portal/RLY/cmnd GD_L
muh/portal/RLY/cmnd GD_U
muh/portal/RLY/cmnd GD_O
```

## Berry
### autoexec.be
```
import string
import mqtt

var initBoot = true
var devicename = tasmota.cmd("DeviceName")['DeviceName']

var switch1 = 0
var switch2 = 0
var switch3 = 0
var switch4 = 0

# MQTT Publish & Store Status
def handleSwitch(name, value, memNameVal, memNameTstamp)
  if value != tasmota.cmd(memNameVal)[memNameVal]
    var tstamp = tasmota.time_str(tasmota.rtc()['local'])
    tasmota.cmd(string.format("%s %d", memNameVal, value))
    if memNameTstamp != nil
      tasmota.cmd(string.format("%s %s", memNameTstamp, tstamp))
    end
    tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{'state': %d, 'tstamp': '%s'}", value, tstamp), true)
  end
end

def publishSwitch(name, memNameVal, memNameTstamp)
  var value = tasmota.cmd(memNameVal)[memNameVal]
  var tstamp = tasmota.cmd(memNameTstamp)[memNameTstamp]
  tasmota.publish(string.format("muh/portal/%s/json", name), string.format("{'state': %d, 'tstamp': '%s'}", value, tstamp), true)
end

# AutoLock
def handleLock(value, setTimer)
  var timer_name = "timerLock"
  if setTimer == nil
    setTimer = value
  end
  if value == 1 && setTimer == 1
      tasmota.set_timer(60000, tasmota.set_power(0, true), timer_name)
  else
    tasmota.remove_timer(timer_name)
  end
end

# MQTT Publish Status WatchDog
if devicename == "GD"
  tasmota.add_cron("*/59 * * * * *", def (value) publishSwitch("GD","Mem1","Mem6") end, "wd_GD")
  tasmota.add_cron("*/59 * * * * *", def (value) publishSwitch("GDL","Mem2","Mem7") end, "wd_GDL")
end

## GD
if devicename == "GD"
  tasmota.add_rule("Switch1#Boot", def (value) switch1 = value handleLock(value,1) end)
  tasmota.add_rule("Switch2#Boot", def (value) switch2 = value handleLock(value,0) end)
  tasmota.add_rule("Switch3#Boot", def (value) switch3 = value end)
  tasmota.add_rule("System#Boot", def (value) handleSwitch("GD",switch1,"Mem1") end)
  tasmota.add_rule("System#Boot", def (value) handleSwitch("GDL",switch2,"Mem2") end)
  #tasmota.add_rule("System#Boot", def (value) handleSwitch("GDW",switch3,"Mem3") end)
  tasmota.add_rule("Switch1#state", def (value) handleSwitch("GD",value,"Mem1","Mem6") handleLock(value) end)
  tasmota.add_rule("Switch2#state", def (value) handleSwitch("GDL",value,"Mem2","Mem7") handleLock(value,0) end)
  #tasmota.add_rule("Switch3#state", def (value) handleSwitch("GDW",value,"Mem3","Mem8") end)
  tasmota.add_rule("Switch4#state", def (value) tasmota.publish("muh/portal/GDP/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end)
end

# FPrint
def handleFprint(values)
 if devicename == "GD"
   tasmota.publish("muh/portal/RLY/cmnd", "G_T")
 end
 tasmota.cmd("i2splay +/RFID1.mp3")
 tasmota.publish("muh/portal/FPRINT/json", string.format("{'uid': %d, 'confidence': %d, 'tstamp': '%s', 'source': '%s'}", values[0], values[1], tasmota.time_str(tasmota.rtc()['local']), devicename), false)
end
tasmota.add_rule(["FPrint#Id","FPrint#Confidence>20"], def (values) handleFprint(values) end)

# MQTT & HTTP API
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe RLY, muh/portal/RLY/cmnd") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_L", def (value) tasmota.cmd("Power1 1") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_U", def (value) tasmota.cmd("Backlog Power2 1; Delay 2; Power2 0") end)
tasmota.add_rule("Event#RLY="+str(devicename)+"_O", def (value) tasmota.cmd("Backlog Power2 1; Delay 10; Power2 0") end)
tasmota.add_rule("Event#"+str(devicename)+"_L=1", def (value) tasmota.cmd("Power1 1") end)
tasmota.add_rule("Event#"+str(devicename)+"_U=1", def (value) tasmota.cmd("Backlog Power2 1; Delay 2; Power2 0") end)
tasmota.add_rule("Event#"+str(devicename)+"_O=1", def (value) tasmota.cmd("Backlog Power2 1; Delay 10; Power2 0") end)

# AUDIO
tasmota.add_rule("System#Boot", def (value) tasmota.cmd("i2sgain 90") end)
## HD
var hd = tasmota.cmd("Mem11")['Mem11']
def handleHD(value)
  if value != hd
    hd = value
    #tasmota.cmd(string.format("Backlog mem11 %s; i2splay +/HD%s.mp3", value, value))
    if initBoot
      tasmota.cmd(string.format("Backlog mem11 %s; i2splay +/HD%s.mp3", value, value))
    else
      tasmota.cmd(string.format("i2splay +/HD%s.mp3", value))
    end
  end
end
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HD, muh/portal/HD/json, state") end)
tasmota.add_rule("Event#HD", def (value) handleHD(value) end)
## HDB
tasmota.add_rule("mqtt#connected", def (value) tasmota.cmd("Subscribe HDB, muh/portal/HDB/json, state") end)
tasmota.add_rule("Event#HDB", def (value) tasmota.cmd("i2splay +/HDB.mp3") end)

# Pendeluhr
tasmota.add_cron("58 29 * * * *", def (value) tasmota.cmd("i2splay +/PC.mp3") end, "pndluhr_halb")
tasmota.add_cron("58 59 * * * *", def (value) tasmota.cmd("i2splay +/PC2.mp3") end, "pndluhr_voll")

# boot
if initBoot
  initBoot = false
end
```