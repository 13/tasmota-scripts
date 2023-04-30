# ESP32 HDv2

## Template

```
{"NAME":"ESP32-HD","GPIO":[0,0,0,0,0,0,0,0,0,0,0,0,160,161,162,32,0,0,0,228,0,224,225,226,0,0,0,0,227,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | HD | Switch1 | 16 | RX2 | | x | Door Reed |
| 2 | HDL | Switch2 | 17 | TX2 | x | x | Door Reed Lock |
| 3 | HDP | Switch3 | 18 | D18 | x | x | Door PiR |
| 4 | HDB | Button1 | 19 | D19 |   | x | Door Bell |
| 5 | L_G | Relay1 | 23 | D23 | x | x | GLED (Garage/GarageDoor LED) |
| 6 | HDG | Button2 | 25 | D25 |   | x | G_Door OPEN Relay |
| 7 | R_B | Relay2 | 26 | D26 | | x | Bell Relay |
| 8 | DFPlayer | mp3player | 27 | D27 | | | |
| 9 | HDL_O | Relayi1 | 32 | D32 | | | |
| 10 | HDL_C | Relayi2 | 33 | D33 | | | |
| 11 | | | 21 | D21 | | | |
| 12 | | | 22 | D22 | | | |
| 13 | RFID | | 13 | D13 | | | |

## Settings

```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120

Backlog DeviceName HD; FriendlyName1 HD; 
GPIO5 256; GPIO7 257; GPIO9 258; GPIO11 259; GPIO12 260;
SwitchMode1 2; SwitchMode2 2; SwitchMode3 1; SwitchTopic 0;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0
```

## Rules

Publish to custom topics (with retain)
- Berry
```
import string
import mqtt

var stateSwitch1 = 0
var stateSwitch2 = 0

tasmota.add_rule("Switch1#Boot", def (value) stateSwitch1 = value end )
tasmota.add_rule("Switch2#Boot", def (value) stateSwitch2 = value end )

tasmota.add_rule("mqtt#connected", def (value) mqtt.publish("muh/portal/HD/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch1, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("mqtt#connected", def (value) mqtt.publish("muh/portal/HDL/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch2, tasmota.time_str(tasmota.rtc()['local'])), true) end )

tasmota.add_rule("Switch1#state", def (value) stateSwitch1 = value mqtt.publish("muh/portal/HD/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch2#state", def (value) stateSwitch2 = value mqtt.publish("muh/portal/HDL/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )

tasmota.add_rule("Switch3#state", def (value) mqtt.publish("muh/portal/HDP/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )
tasmota.add_rule("Button1#state", def (value) mqtt.publish("muh/portal/HDB/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )
tasmota.add_rule("Button2#state", def (value) mqtt.publish("muh/portal/HDG/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )
```
- Classic
```
Rule1
  on Switch1#Boot do var1 %value% endon
  on Switch2#Boot do var2 %value% endon
  on mqtt#connected do Publish2 muh/portal/HD/json {"state": %var1%, "tstamp": "%timestamp%"} endon
  on mqtt#connected do Publish2 muh/portal/HDL/json {"state": %var2%, "tstamp": "%timestamp%"} endon
  on Switch1#state do Backlog var1 %value%; Publish2 muh/portal/HD/json {"state": %value%, "tstamp": "%timestamp%"} endon
  on Switch2#state do Backlog var2 %value%; Publish2 muh/portal/HDL/json {"state": %value%, "tstamp": "%timestamp%"} endon
  on Switch3#state do Publish muh/portal/HDP/json {"state": %value%, "tstamp": "%timestamp%"} endon
  on Button1#state do Publish muh/portal/HDB/json {"state": %value%, "tstamp": "%timestamp%"} endon
  on Button2#state do Publish muh/portal/HDG/json {"state": %value%, "tstamp": "%timestamp%"} endon
  
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

## Berry

Keymatic unlock & open method over web ui

```
import webserver

class relayButtonsMethods : Driver

  def runRelay(numRelay, openDoor)
    log("Relay Button " + str(numRelay) + "pressed " + str(openDoor))
    var numDelay = 2
    if openDoor
      numDelay = 10
    end
    tasmota.cmd("Backlog Power" + str(numRelay) + " 1; Delay " + str(numDelay) + "; Power" + str(numRelay) + " 0")
  end

  def web_add_main_button()
    webserver.content_send("<p></p><button onclick='la(\"&o=5\");'>GARAGE</button><table style=\"width:100%\"><tbody><tr>
    <td style=\"width:33%\">
    <button onclick='la(\"&o=1\");'>GD LOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&rly=2&opendoor=0\");'>UNLOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&rly=2&opendoor=1\");'>OPEN</button></td></tr><tr><td style=\"width:33%\">
    <button onclick='la(\"&o=3\");'>HD LOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&rly=4&opendoor=0\");'>UNLOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&rly=4&opendoor=1\");'>OPEN</button></td></tr></tbody></table><p></p>")
  end

  def web_sensor()
    if webserver.has_arg("rly") && webserver.has_arg("opendoor")
      var numRelay = int(webserver.arg("rly"))
      var openDoor = toBool(webserver.arg("opendoor"))
      self.runRelay(numRelay, openDoor)
    end
  end
  
d1 = relayButtonsMethods()
tasmota.add_driver(d1)
```

LED G/GDL

```
bool stateG = 0
bool stateGDL = 0

def LEDG(value)
  stateG = toBool(value)
  setLED()
end

def LEDGDL(value)
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

mqtt.subscribe("tasmota/sensors/G", LEDG)
mqtt.subscribe("tasmota/sensors/GDL", LEDGDL)
```
