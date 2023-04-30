# ESP32 GARAGE

## Template

```
{"NAME":"ESP32-GARAGE","GPIO":[0,0,0,0,0,0,0,0,0,0,0,0,160,161,162,32,0,0,0,228,0,224,225,226,0,0,0,0,227,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | G | Switch1 | 16 | RX2 | | x | Garage Reed |
| 2 | GD | Switch2 | 17 | TX2 | | x | Garage Door Reed |
| 3 | GDL | Switch3 | 18 | D18 | x | x | Garage Door Lock Reed |
| 4 | GDW | Switch4 | 19 | D19 |   | x | Garage Door Window Reed |
| 5 | GDP | Switch5 | 23 | D23 | x | x | Garage Door PiR |
| 6 | G_T | Relay | 25 | D25 | | |  |
| 8 | DFPlayer | mp3player | 27 | D27 | | | |
| 9 | GDL_O | Relayi1 | 32 | D32 | | | |
| 10 | GDL_C | Relayi2 | 33 | D33 | | | |
| 11 | | | 21 | D21 | | | |
| 12 | | | 22 | D22 | | | |
| 13 | RFID | | 13 | D13 | | | RDM6300 |

## Settings

```
Backlog FriendlyName1 GARAGE; 
GPIO5 256; GPIO7 257; GPIO9 258; GPIO11 259; GPIO12 260;
SwitchMode1 2; SwitchMode2 2; SwitchMode3 1; SwitchTopic 0;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0
```
