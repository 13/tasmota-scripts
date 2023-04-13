# ESP32S2 G

## Template

```

```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | GDL_O | Relay1 | 15 | D25 | | x | GDL OPEN Relay |
| 2 | GDL_C | Relay2 | 17 | D26 | | x | GDL CLOSE Relay |
| 3 | HDL_O | Relay3 | 27 | D27 | | x | HDL OPEN Relay |
| 4 | HDL_C | Relay4 | 32 | D32 | | x | HDL CLOSE Relay |
| 5 | G_T | Relay5 | 32 | D32 | | x | HDL CLOSE Relay |

## Settings

```
Backlog SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0;
```

## Rules

```
Backlog Rule1 1;
PulseTime5 6;
PulseTime1 0;
PulseTime2 2;
PulseTime3 0;
PulseTime4 2
```

Backlog
PulseTime5 6;
PulseTime1 0;
PulseTime2 0;
PulseTime3 0;
PulseTime4 0
// PulseTime2 5
LOCK/UNLOCK
 Backlog Power1 1; Delay 2; Power1 0
OPEN 
 Backlog Power1 1; Delay 10; Power1 0
TOGGLE G
 Backlog Power1 1; Delay 8; Power1 0
 
Rule1
  ON mqtt#connected DO Subscribe RLY, tasmota/sensors/RLY/cmnd ENDON
  ON Event#RLY=HDOPEN DO Backlog Power2 1; Delay 2; Power2 0 ENDON
  ON Event#RLY=HDLOPEN DO Backlog Power2 1; Delay 10; Power2 0 ENDON
  ON Event#RLY=GDOPEN DO Backlog Power4 1; Delay 2; Power4 0 ENDON
  ON Event#RLY=GDLOPEN DO Backlog Power4 1; Delay 10; Power4 0 ENDON
  
```
