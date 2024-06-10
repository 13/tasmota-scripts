# ESP32S2 Gv1

## Template

```
{"NAME":"S2 Mini v1.0.0","GPIO":[32,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | GDL_C | Relay_i1 | 5 | D5 | | x | GDL close |
| 2 | GDL_O | Relay_i2 | 7 | D7 | | x | GDL open |
| 3 | HDL_C | Relay_i3 | 9 | D9 | | x | HDL close |
| 4 | HDL_O | Relay_i4 | 11 | D11 | | x | HDL open |
| 5 | G_T | Relay_i5 | 12 | D12 | | x | G toggle |

## Settings

```
Backlog FriendlyName1 GRELAY; 
GPIO5 256; GPIO7 257; GPIO9 258; GPIO11 259; GPIO12 260;
SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0
```

## Rules

Keymatic unlock & open method over mqtt

```
Backlog Rule1 1;
PulseTime5 6;
PulseTime1 2;
PulseTime2 0;
PulseTime3 2;
PulseTime4 0
 
Rule1
  ON mqtt#connected DO Subscribe RLY, tasmota/sensors/RLY/cmnd ENDON
  ON Event#RLY=HDOPEN DO Backlog Power2 1; Delay 2; Power2 0 ENDON
  ON Event#RLY=HDLOPEN DO Backlog Power2 1; Delay 10; Power2 0 ENDON
  ON Event#RLY=GDOPEN DO Backlog Power4 1; Delay 2; Power4 0 ENDON
  ON Event#RLY=GDLOPEN DO Backlog Power4 1; Delay 10; Power4 0 ENDON
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

Lock Door after x Minutes
RULES
```
def lockGDL(value)
  if value == 1
    tasmota.set_timer(5000, tasmota.set_power(3, true), "GDL")
  else
    tasmota.remove_timer("GDL")
  end
end
tasmota.add_rule("Switch2#state",lockGDL)

tasmota.add_rule("Switch1#state",tasmota.publish("tasmota/sensors/G/state", value, true))
```

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
