# ESP32S2 G

## Template

```

```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | GDL_O | Relay_i1 | 5 | D5 | | x | GDL open |
| 2 | GDL_C | Relay_i2 | 7 | D7 | | x | GDL close |
| 3 | HDL_O | Relay_i3 | 9 | D9 | | x | HDL open |
| 4 | HDL_C | Relay_i4 | 11 | D11 | | x | HDL close |
| 5 | G_T | Relay_i5 | 12 | D12 | | x | Garage Toggle |

## Settings

```
Backlog SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0
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
