# ESP32-S3 GARAGEDOOR

## Template

```
{"NAME":"ESP32S3-GD"}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | | | 16 | RX2 | | | |
| 2 | GD | Switch 2 | 17 | TX2 | | x | Garage Door Reed |
| 3 | GDL | Switch 3 | 18 | D18 | x | x | Garage Door Lock Reed |
| 4 | GDW | Switch 4 | 19 | D19 |   | x | Garage Door Window Reed |
| 5 | GDP | Switch 5 | 23 | D23 | x | x | Garage Door PiR |
| 6 | | | 25 | D25 | | | |
| 7 | GD_L | Relay_i 1 | 32 | D32 | | | Relay |
| 8 | GD_U | Relay_i 2 | 33 | D33 | | | Relay |
| 9 | SDA | I2C SDA | 21 | D21 | x | x | RTC DS3231 |
| 10 | SCL | I2C SCL | 22 | D22 | | | RTC DS3231 |
| 11 | RFID | RDM6300 RX | 13 | D13 | x | x | RFID |
| 12 | LRC | I2S_WS | 26 | D26 | x | x | i2s |
| 13 | BCLK | I2S_BCLK | 27 | D27 | | | i2s |
| 14 | DIN | I2S_DOUT | 4 | D4 | | | i2s |

## Settings
```
Backlog IPAddress1 192.168.22.91; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120
Backlog DeviceName GARAGEDOOR; FriendlyName1 GARAGEDOOR; 
SetOption114 1; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0; SwitchDebounce 100;
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
```
Rule1
ON Switch2#Boot DO var2 %value% ENDON
ON Switch3#Boot DO var3 %value% ENDON
ON Switch4#Boot DO var4 %value% ENDON
ON System#Boot DO IF (%var2%!=%mem2%) mem2 %var2%; Publish2 muh/portal/GD/json {"state": %var2%, "time": "%timestamp%"} ENDIF ENDON
ON System#Boot DO IF (%var3%!=%mem3%) mem3 %var3%; Publish2 muh/portal/GDL/json {"state": %var3%, "time": "%timestamp%"} ENDIF ENDON
ON System#Boot DO IF (%var4%!=%mem4%) mem4 %var4%; Publish2 muh/portal/GDW/json {"state": %var4%, "time": "%timestamp%"} ENDIF ENDON
ON Switch2#state!=%mem2% DO Backlog mem2 %value%; mem6 %timestamp%; Publish2 muh/portal/GD/json {"state": %value%, "time": "%timestamp%"} ENDON

Rule2
ON Switch2#Boot=1 DO RuleTimer1 600 ENDON
ON Switch3#Boot=1 DO RuleTimer1 0 ENDON
ON Switch2#state=1 DO RuleTimer1 600 ENDON
ON Switch2#state=0 DO RuleTimer1 0 ENDON
ON Switch3#state=1 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 1 ENDON
ON mqtt#connected DO Subscribe RLY, muh/portal/RLY/cmnd ENDON
ON Event#RLY=GD_L DO Power1 1 ENDON
ON Event#RLY=GD_U DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON Event#RLY=GD_O DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON RDM6300#UID DO Publish muh/portal/RFID/json {"uid": %value%, "time": "%timestamp%", "source": "GD"} ENDON
ON RDM6300#UID=XXXXXXXX DO Power3 1 ENDON

Rule3
ON System#Boot DO i2sgain 100 ENDON
ON RDM6300#UID DO i2splay +/RFID1.mp3 ENDON
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD!=%mem11% DO Backlog mem11 %value%; i2splay +/HD%value%.mp3 ENDON
ON mqtt#connected DO Subscribe HDB, muh/portal/HDB/json, state ENDON
ON Event#HDB DO i2splay +/HDB.mp3 ENDON
ON Time#Minute|30 DO i2splay +/PC.mp3 ENDON
ON Switch3#state!=%mem3% DO Backlog mem3 %value%; mem7 %timestamp%; Publish2 muh/portal/GDL/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch4#state!=%mem4% DO Backlog mem4 %value%; mem8 %timestamp%; Publish2 muh/portal/GDW/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch5#state DO Publish muh/portal/GDP/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Time#Minute|1 DO Publish2 muh/portal/GD/json {"state": %mem2%, "time": "%mem6%"} ENDON
ON Time#Minute|1 DO Publish2 muh/portal/GDL/json {"state": %mem3%, "time": "%mem7%"} ENDON
```
#### Rule 2
- Autolock after 10m
- Event HTTP for relays
- Event MQTT for relays
- Publish RFID
```
Rule2
ON Switch2#Boot=1 DO RuleTimer1 600 ENDON
ON Switch3#Boot=1 DO RuleTimer1 0 ENDON
ON Switch2#state=1 DO RuleTimer1 600 ENDON
ON Switch2#state=0 DO RuleTimer1 0 ENDON
ON Switch3#state=1 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 1 ENDON
ON mqtt#connected DO Subscribe RLY, muh/portal/RLY/cmnd ENDON
ON Event#RLY=GD_L DO Power1 1 ENDON
ON Event#RLY=GD_U DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON Event#RLY=GD_O DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON RDM6300#UID DO Publish muh/portal/RFID/json {"uid": %value%, "time": "%timestamp%", "source": "GD"} ENDON

ON event#GD_L=1 DO Power1 1 ENDON
ON event#GD_U=1 DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON event#GD_O=1 DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON RDM6300#UID=XXXX DO Power3 1 ENDON
```
#### Rule 3
- Play sounds
```
Rule3
ON System#Boot DO i2sgain 100 ENDON
ON RDM6300#UID DO i2splay +/RFID1.mp3 ENDON
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD!=%mem11% DO Backlog mem11 %value%; i2splay +/HD%value%.mp3 ENDON
ON mqtt#connected DO Subscribe HDB, muh/portal/HDB/json, state ENDON
ON Event#HDB DO i2splay +/HDB.mp3 ENDON
ON Time#Minute|30 DO i2splay +/PC.mp3 ENDON
```
### Commands
```
http://192.168.22.199/cm?cmnd=event%20G%5FT=1
http://192.168.22.199/cm?cmnd=event%20GD%5FL=1
http://192.168.22.199/cm?cmnd=event%20GD%5FU=1
http://192.168.22.199/cm?cmnd=event%20GD%5FO=1
muh/portal/RLY/cmnd G_T
muh/portal/RLY/cmnd GD_L
muh/portal/RLY/cmnd GD_U
muh/portal/RLY/cmnd GD_O
```

## Berry
autoexec.be

- Show Buttons
```
import string
import webserver 

class relayButtonsMethods : Driver

  def runRelay(numRelay, openDoor)
    var numDelay = 2
    if openDoor
      numDelay = 10
    end
    tasmota.cmd(string.format("Backlog Power%d 1; Delay %d; Power%d 0", numRelay, numDelay, numRelay))
  end

  def web_add_main_button()
    webserver.content_send("<p></p><button onclick='la(\"&o=3\");'>GARAGE</button><table style=\"width:100%\"><tbody><tr><td style=\"width:33%\"><button onclick='la(\"&o=1\");'>GD LOCK</button></td><td style=\"width:33%\"><button onclick='la(\"&rly=2&opendoor=0\");'>UNLOCK</button></td><td style=\"width:33%\"><button onclick='la(\"&rly=2&opendoor=1\");'>OPEN</button></td></tr></tbody></table><p></p>")
  end

  def web_sensor()
    if webserver.has_arg("rly") && webserver.has_arg("opendoor")
      var numRelay = int(webserver.arg("rly"))
      var openDoor = bool(webserver.arg("opendoor"))
      self.runRelay(numRelay, openDoor)
    end
  end
end
d1 = relayButtonsMethods()
tasmota.add_driver(d1)
```
#### Not longer used
##### 
```
import string
import mqtt

var stateSwitch1 = 0
var stateSwitch2 = 0
var stateSwitch3 = 0

tasmota.add_rule("Switch1#Boot", def (value) stateSwitch1 = value end )
tasmota.add_rule("Switch2#Boot", def (value) stateSwitch2 = value end )
tasmota.add_rule("Switch3#Boot", def (value) stateSwitch3 = value end )

tasmota.add_rule("mqtt#connected", def (value) mqtt.publish("muh/portal/G/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch1, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("mqtt#connected", def (value) mqtt.publish("muh/portal/GD/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch2, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("mqtt#connected", def (value) mqtt.publish("muh/portal/GDL/json", string.format("{'state': %d, 'tstamp': '%s'}", stateSwitch3, tasmota.time_str(tasmota.rtc()['local'])), true) end )

tasmota.add_rule("Switch1#state", def (value) stateSwitch1 = value mqtt.publish("muh/portal/G/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch2#state", def (value) stateSwitch2 = value mqtt.publish("muh/portal/GD/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch3#state", def (value) stateSwitch3 = value mqtt.publish("muh/portal/GDL/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch4#state", def (value) mqtt.publish("muh/portal/GDW/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), true) end )
tasmota.add_rule("Switch5#state", def (value) mqtt.publish("muh/portal/GDP/json", string.format("{'state': %d, 'tstamp': '%s'}", value, tasmota.time_str(tasmota.rtc()['local'])), false) end )
```
