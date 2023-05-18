# ESP32 HDv2

## Template

```
{"NAME":"ESP32-HD","GPIO":[0,0,0,0,7776,0,0,0,0,3616,7840,0,160,161,162,32,0,640,608,228,0,33,258,7808,0,0,0,0,256,257,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | HD | Switch 1 | 16 | RX2 | | x | Door Reed |
| 2 | HDL | Switch 2 | 17 | TX2 | x | x | Door Reed Lock |
| 3 | HDP | Switch 3 | 18 | D18 | x | x | Door PiR |
| 4 | HDB | Button 1 | 19 | D19 |   | x | HD Bell |
| 5 | G_LED | Relay 5 | 23 | D23 | x | x | G/GDL LED) |
| 6 | HDBG | Button 2 | 25 | D25 |   | x | HD MQTT G Toggle |
| 7 | HDB_R | Relay_i 3 | 26 | D26 | | x | Bell Relay |
| 8 | HD_L | Relay_i 1 | 32 | D32 | | | |
| 9 | HD_U | Relay_i 2 | 33 | D33 | | | |
| 10 | SDA | I2C SDA | 21 | D21 | x | x | RTC DS3231 |
| 11 | SCL | I2C SCL | 22 | D22 | | | RTC DS3231 |
| 12 | RFID | RDM6300 RX | 13 | D13 | x | x | RFID |
| 13 | LRC | I2S_WS | 14 | D14 | x | x | i2s |
| 14 | BCLK | I2S_BCLK | 27 | D27 | | | i2s |
| 15 | DIN | I2S_DOUT | 4 | D4 | | | i2s |

## Settings

```
Backlog IPAddress1 192.168.22.92; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120
Backlog DeviceName HD; FriendlyName1 HD; 
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode3 1; SwitchTopic 0; SwitchDebounce 100;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
PulseTime3 4; PulseTime1 2; PulseTime2 0;
```

## Rules
### Rule 1
- Publish states
- Publish RFID
- Button 1c G_INT LIGHT
- Button 2c G OPEN
- Button 3c GD OPEN
- Button 4c GD LOCK
```
Rule1
ON Switch1#Boot DO var1 %value% ENDON
ON Switch2#Boot DO var2 %value% ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/portal/HD/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON System#Boot DO IF (%var2%!=%mem2%) mem2 %var2%; Publish2 muh/portal/HDL/json {"state": %var2%, "time": "%timestamp%"} ENDIF ENDON
ON Switch1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/portal/HD/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch2#state!=%mem2% DO Backlog mem2 %value%; Publish2 muh/portal/HDL/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch3#state DO Publish muh/portal/HDP/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Button1#state DO Publish muh/portal/HDB/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Button2#state DO Publish muh/portal/HDG/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Button2#state=10 DO Publish tasmota/cmnd/tasmota_9521A4/POWER 2 ENDON
ON Button2#state=11 DO Publish muh/portal/RLY/cmnd G_T ENDON
ON Button2#state=12 DO Publish muh/portal/RLY/cmnd GD_O ENDON
ON Button2#state=13 DO Publish muh/portal/RLY/cmnd GD_L ENDON
```
### Rule 2
- HTTP Relay API
- MQTT Relay API
- Publish RFID
- LED for state of G & GDL
```
Rule2
ON event#HD_L=1 DO Power1 1 ENDON
ON event#HD_U=1 DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON event#HD_O=1 DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON mqtt#connected DO Subscribe RLY, muh/portal/RLY/cmnd ENDON
ON Event#RLY=HD_L DO Power1 1 ENDON
ON Event#RLY=HD_U DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON Event#RLY=HD_O DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON RDM6300#UID DO Publish muh/portal/RFID/json {"uid": %value%, "time": "%timestamp%", "source": "HD"} ENDON
ON mqtt#connected DO Subscribe LEDG, muh/portal/G/json, state ENDON
ON mqtt#connected DO Subscribe LEDGDL, muh/portal/GDL/json, state ENDON
ON Event#LEDG DO Backlog var3 %value%; IF ((var3==1) AND (var4==1)) Power4 1 ELSEIF ((var3==0) AND (var4==0)) Power4 0 ELSE Power4 3 ENDIF ENDON
ON Event#LEDGDL DO Backlog var4 %value%; IF ((var3==1) AND (var4==1)) Power4 1 ELSEIF ((var3==0) AND (var4==0)) Power4 0 ELSE Power4 3 ENDIF ENDON
```
### Rule 3
- Play sounds
- Play Pendulum Clock
- Play Christmas Easteregg sounds
```
Rule3
ON System#Boot DO i2sgain 40 ENDON
ON RDM6300#UID DO i2splay +/RFID1.mp3 ENDON
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G!=%mem11% DO Backlog mem11 %value%; i2splay +/G%value%.mp3 ENDON  
ON mqtt#connected DO Subscribe GD, muh/portal/GD/json, state ENDON
ON Event#GD!=%mem12% DO Backlog mem12 %value%; i2splay +/GD%value%.mp3 ENDIF ENDON
ON Switch1#state DO i2splay +/HD%value%%Var16%.mp3 ENDON
ON Button1#state=10 DO Backlog i2sgain 100; i2splay +/HDB%Var16%.mp3; i2sgain 40 ENDON
ON Time#Minute|30 DO i2splay +/PC.mp3 ENDON
ON Time#Minute=60 DO Backlog event checkdate=%timestamp% ENDON
ON event#checkdate$|-12-24T DO Var16 X ENDON
ON event#checkdate$|-12-25T DO Var16 X ENDON
ON event#checkdate$|-12-26T DO Var16 " ENDON
  
ON Time#Minute|30 DO IF (((%time%) % 60) == 30) i2splay +/PC.mp3 ELSE IF (((%time%) % 60) == 0) var10=%time%/60; i2swr http://192.168.22.99:3000/sounds/PC/PC%var10%.mp3 ENDIF ENDON
```

## Berry
- Publish to custom topics (with retain)
```
import string
import mqtt

var stateSwitch1 = 0
var stateSwitch2 = 0

tasmota.add_rule("Switch1#Boot", def (value) stateSwitch1 = value end )
tasmota.add_rule("Switch2#Boot", def (value) stateSwitch2 = value end )
tasmota.add_rule("System#Boot", def (value) mqtt.publish("muh/portal/HD/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch1, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("System#Boot", def (value) mqtt.publish("muh/portal/HDL/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch2, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch1#state", def (value) mqtt.publish("muh/portal/HD/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch2#state", def (value) mqtt.publish("muh/portal/HDL/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch3#state", def (value) mqtt.publish("muh/portal/HDP/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )
tasmota.add_rule("Button1#state", def (value) mqtt.publish("muh/portal/HDB/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )
tasmota.add_rule("Button2#state", def (value) mqtt.publish("muh/portal/HDG/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )

bool stateG = 0
bool stateGDL = 0

def setLEDG(value)
  stateG = toBool(value)
  setLED()
end

def setLEDGDL(value)
  stateGDL = toBool(value)
  setLED()
end

def setLED()
  if stateLEDG && stateLEDGDL
    tasmota.set_power(1, true)
  elif !stateLEDG && !stateLEDGDL
    tasmota.set_power(1, true)
  else 
    tasmota.cmd("Power1 3") 
  end
end

mqtt.subscribe("muh/portal/G/json, state", setLEDG)
mqtt.subscribe("tasmota/sensors/GDL", setLEDGDL)
```
LED G/GDL
```
bool stateG = 0
bool stateGDL = 0

def LEDG(value)
  stateG = bool(value)
  setLED()
end

def LEDGDL(value)
  stateGDL = bool(value)
  setLED()
end

def setLED()
  if stateLEDG && stateLEDGDL
    tasmota.set_power(1, true)
  elif !stateLEDG && !stateLEDGDL
    tasmota.set_power(1, true)
  else 
    tasmota.cmd("Power1 3") 
  end
end

mqtt.subscribe("tasmota/sensors/G", LEDG)
mqtt.subscribe("tasmota/sensors/GDL", LEDGDL)
```
