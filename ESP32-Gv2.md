# ESP32 GARAGE

## Template

```
{"NAME":"ESP32-GARAGE","GPIO":[0,0,0,0,0,0,0,0,0,3616,0,0,160,161,162,163,0,640,608,164,0,258,0,2144,0,0,0,0,256,257,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|
| 1 | G | Switch 1 | 16 | RX2 | | x | Garage Reed |
| 2 | GD | Switch 2 | 17 | TX2 | | x | Garage Door Reed |
| 3 | GDL | Switch 3 | 18 | D18 | x | x | Garage Door Lock Reed |
| 4 | GDW | Switch 4 | 19 | D19 |   | x | Garage Door Window Reed |
| 5 | GDP | Switch 5 | 23 | D23 | x | x | Garage Door PiR |
| 6 | G_T | Relay_i 3 | 25 | D25 | x | x | Relay |
| 8 | DFPlayer | MP3 Player | 27 | D27 | | | MP3 Mplayer |
| 9 | GDL_O | Relay_i 1 | 32 | D32 | | | Relay |
| 10 | GDL_C | Relay_i 2 | 33 | D33 | | | Relay |
| 11 | SDA | I2C SDA | 21 | D21 | x | x | RTC DS3231 |
| 12 | SCL | I2C SCL | 22 | D22 | | | RTC DS3231 |
| 13 | RFID | RDM6300 RX | 13 | D13 | x | x | RFID |

## Settings
### Switches
```
Backlog DeviceName GARAGE; FriendlyName1 GARAGE; 
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 2; SwitchMode5 1; SwitchTopic 0;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0
```
