# ESP32 GARAGE

## Template

```
{"NAME":"ESP32-GARAGE","GPIO":[0,0,0,0,0,0,0,0,0,3616,0,0,160,161,162,163,0,640,608,164,0,258,0,2144,0,0,0,0,256,257,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | G | Switch1 | 16 | RX2 | | x | Garage Reed |
| 2 | GD | Switch2 | 17 | TX2 | | x | Garage Door Reed |
| 3 | GDL | Switch3 | 18 | D18 | x | x | Garage Door Lock Reed |
| 4 | GDW | Switch4 | 19 | D19 |   | x | Garage Door Window Reed |
| 5 | GDP | Switch5 | 23 | D23 | x | x | Garage Door PiR |
| 6 | G_T | Relay | 25 | D25 | | | Relay |
| 8 | DFPlayer | mp3player | 27 | D27 | | | MP3 Mplayer |
| 9 | GDL_O | Relayi1 | 32 | D32 | | | Relay |
| 10 | GDL_C | Relayi2 | 33 | D33 | | | Relay |
| 11 | SDA | | 21 | D21 | | | RTC DS3231 |
| 12 | SCL | | 22 | D22 | | | RTC DS3231 |
| 13 | RFID | | 13 | D13 | | | RDM6300 |

## Settings
### Switches
```
Backlog DeviceName GARAGE; FriendlyName1 GARAGE; 
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0
```
