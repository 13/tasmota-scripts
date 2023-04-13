# ESP32S2 G

## Template

```

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
Backlog SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0
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

  def runRelay(numRelay, numDelay)
    log("Relay Button " + str(numRelay) + "pressed with delay " + str(numRelay))
    tasmota.cmd("Backlog Power" + str(numRelay) + " 1; Delay " + str(numDelay) + "; Power" + str(numRelay) + " 0")
  end

  def web_add_main_button()
    webserver.content_send("<p></p><button onclick='la(\"&o=5\");'>GARAGE</button><table style=\"width:100%\"><tbody><tr>
    <td style=\"width:33%\">
    <button onclick='la(\"&o=1\");'>GD LOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&mrly=2&mdly=2\");'>UNLOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&mrly=2&mdly=10\");'>OPEN</button></td></tr><tr><td style=\"width:33%\">
    <button onclick='la(\"&o=3\");'>HD LOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&mrly=4&mdly=2\");'>UNLOCK</button></td><td style=\"width:33%\">
    <button onclick='la(\"&mrly=4&mdly=10\");'>OPEN</button></td></tr></tbody></table><p></p>")
  end

  def web_sensor()
    if webserver.has_arg("mrly") && webserver.has_arg("mdly")
      var numRelay = int(webserver.arg("mrly"))
      var numDelay = int(webserver.arg("mdly"))
      self.runRelay(numRelay, numDelay)
    end
  end
  
d1 = relayButtonsMethods()
tasmota.add_driver(d1)
```
