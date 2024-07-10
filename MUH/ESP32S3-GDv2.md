# ESP32-S3 GARAGEDOOR
## Template
```
{"NAME":"ESP32-S3-DevKitC-GD","GPIO":[1,640,608,1,7840,7808,7776,5984,163,160,161,1,1,1,1,6016,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,256,257],"FLAG":0,"BASE":1}
```
## Table
| NAME | MODULE | GPIO | PIN | + | - | DESC |
|:--|:--|:--|--:|:--|---|---|
| **RTC** | | | | | | |
| SDA | I2C SDA | 1 | D01 | x | x | RTC DS3231 |
| SCL | I2C SCL | 2 | D02 | | | RTC DS3231 |
| **Reeds, Buttons & LEDS** | | | | | | |
| GD | Switch 1 | 9 | D09 | | x | Garage Door Reed |
| GDL | Switch 2 | 10 | D10 | 3v | x | Garage Door Lock Reed (with LED) |
| G | Switch 3 | 11 | D11 |   | x | Garage Reed |
| GD_BTN | Button 1 | 12 | D12 |   | x | Garage Door Button |
| GD_LEDHDL | Relay 4 | 13 | D13 |   | x | Garage Door LED for HDL |
| xxx | xxx | 38 | D38 |   | x | |
| **Relays** | | | | | | |
| GD_L | Relay_i 1 | 48 | D48 | | | Relay |
| GD_U | Relay_i 2 | 49 | D49 | | | Relay |
| G_T | Relay_i 3 | 14 | D14 | | | Relay |
| **I2S Audio** | | | | | | |
| LRC | I2S_WS | 4 | D04 | 5v | x | i2s |
| BCLK | I2S_BCLK | 5 | D05 | | | i2s |
| DIN | I2S_DOUT | 6 | D05 | | | i2s |
| **PIR** | | | | | | |
| GDP | Switch 4 | 8 | D08 | 3v | x | Garage Door PiR |
| **RFID** | | | | | | |
| xxx | RDM6300 RX | 21 | D21 | x | x | RFID |
| **FPRINT** | | | | | | |
| FPrint | As608 TX | 7 | D07 | x | x | RFID |
| FPrint | As608 RX | 15 | D15 | x | x | RFID |

```
        ~~~~~
i2s     ----- rtc
fprint  -ESP- relay
pir     -+ -- rfid
sensors 
```

## Settings
```
Backlog Template {"NAME":"ESP32S3-GD","GPIO":[1,640,608,1,7840,7808,7776,5984,163,160,161,162,1,1,258,6016,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,256,257],"FLAG":0,"BASE":1}; Module 0;
Backlog IPAddress1 192.168.22.91; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName GD; FriendlyName1 GD_L; FriendlyName2 GD_U; FriendlyName3 G_T;
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode3 2; SwitchMode4 1; SwitchTopic 0; SwitchDebounce 100;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
PulseTime1 2; PulseTime2 2; PulseTime3 2;
TelePeriod 3600;
#SetOption56 1;
```
### Fingerprint
```
FPEnroll <x>
FPDelete <x>
FPCount
```
### Rules
#### Rule 1
- Publish switches
#### Rule 2
- Autolock after 10m
- Event HTTP for relays
- Event MQTT for relays
- Publish RFID
- Fingerprint
#### Rule 3
- Sounds

### Commands
```
http://192.168.22.91/cm?cmnd=event%20G%5FT=1
http://192.168.22.91/cm?cmnd=event%20GD%5FL=1
http://192.168.22.91/cm?cmnd=event%20GD%5FU=1
http://192.168.22.91/cm?cmnd=event%20GD%5FO=1
muh/portal/RLY/cmnd G_T
muh/portal/RLY/cmnd GD_L
muh/portal/RLY/cmnd GD_U
muh/portal/RLY/cmnd GD_O
```
