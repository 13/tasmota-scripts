# ESP32 HDv2

## Template

```
{"NAME":"ESP32-HD","GPIO":[0,0,0,0,0,0,0,0,0,0,0,0,160,161,162,32,0,0,0,228,0,224,225,226,0,0,0,0,227,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | HD | Switch 1 | 16 | RX2 | | x | Door Reed |
| 2 | HDL | Switch 2 | 17 | TX2 | x | x | Door Reed Lock |
| 3 | HDP | Switch 3 | 18 | D18 | x | x | Door PiR |
| 4 | HDB | Button 1 | 19 | D19 |   | x | Door Bell |
| 5 | G_LED | Relay 5 | 23 | D23 | x | x | GLED (Garage/GarageDoor LED) |
| 6 | HDG | Button 2 | 25 | D25 |   | x | G_Door OPEN Relay |
| 7 | HDB_R | Relay_i 3 | 14 | D14 | | x | Bell Relay |
| 8 | HD_L | Relay_i 1 | 32 | D32 | | | |
| 9 | HD_U | Relay_i 2 | 33 | D33 | | | |
| 10 | SDA | I2C SDA | 21 | D21 | x | x | RTC DS3231 |
| 11 | SCL | I2C SCL | 22 | D22 | | | RTC DS3231 |
| 12 | RFID | RDM6300 RX | 13 | D13 | x | x | RFID |
| 13 | LRC | I2S_WS | 26 | D26 | x | x | i2s |
| 14 | BCLK | I2S_BCLK | 27 | D27 | | | i2s |
| 15 | DIN | I2S_DOUT | 4 | D4 | | | i2s |

## Settings

```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120
Backlog DeviceName HD; FriendlyName1 HD; 
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode3 1; SwitchTopic 0; SwitchDebounce 100;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
PulseTime3 4; PulseTime1 2; PulseTime2 0;
```

## Rules
- Classic
```
Rule1
  on Switch1#Boot do var1 %value% endon
  on Switch2#Boot do var2 %value% endon
  on System#Boot do Publish2 muh/portal/HD/json {"state": %var1%, "time": "%timestamp%"} endon
  on System#Boot do Publish2 muh/portal/HDL/json {"state": %var2%, "time": "%timestamp%"} endon
  on Switch1#state do Backlog var1 = %value%; Publish2 muh/portal/HD/json {"state": %value%, "time": "%timestamp%"} endon
  on Switch2#state do Backlog var2 = %value%; Publish2 muh/portal/HDL/json {"state": %value%, "time": "%timestamp%"} endon
  on Switch3#state do Publish muh/portal/HDP/json {"state": %value%, "time": "%timestamp%"} endon
  on Button1#state do Publish muh/portal/HDB/json {"state": %value%, "time": "%timestamp%"} endon
  on Button2#state do Publish muh/portal/HDG/json {"state": %value%, "time": "%timestamp%"} endon
  ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
  ON Event#HD IF (var1!=%value%) Backlog var1 = %value%; Publish2 muh/portal/HD/json {"state": %value%, "time": "%timestamp%"} ENDIF ENDON
  ON mqtt#connected DO Subscribe HDL, muh/portal/HDL/json, state ENDON
  ON Event#HDL IF (var1!=%value%) Backlog var2 = %value%; Publish2 muh/portal/HDL/json {"state": %value%, "time": "%timestamp%"} ENDIF ENDON
  
Rule2
  ON mqtt#connected DO Subscribe LEDG, muh/portal/G/json, state ENDON
  ON mqtt#connected DO Subscribe LEDGDL, muh/portal/GDL/json, state ENDON
  ON Event#LEDG DO Backlog var3 %value%;
  IF ((var3==1) AND (var4==1)) Power1 1 
  ELSEIF ((var3==0) AND (var4==0)) Power1 0 
  ELSE Power1 3 
  ENDIF
  ENDON
  ON Event#LEDGDL DO Backlog var4 %value%;
  IF ((var3==1) AND (var4==1)) Power1 1 
  ELSEIF ((var3==0) AND (var4==0)) Power1 0 
  ELSE Power1 3 
  ENDIF
  ENDON  
```


Publish to custom topics (with retain)
- Berry
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
## Berry

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
