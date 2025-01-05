# ESP32-S3 HD

## Table

| NAME          | MODULE    | GPIO | PIN | +   | -   | DESC                             |
| :------------ | :-------- | :--- | --: | :-- | --- | -------------------------------- |
| **RTC**       |           |      |     |     |     |                                  |
| SDA           | I2C SDA   | 1    | D01 | x   | x   | RTC DS3231                       |
| SCL           | I2C SCL   | 2    | D02 |     |     | RTC DS3231                       |
| **Reeds**     |           |      |     |     |     |                                  |
| HD            | Switch 1  | 9    | D09 |     | x   | Garage Door Reed                 |
| HDL           | Switch 2  | 10   | D10 | 3v  | x   | Garage Door Lock Reed (with LED) |
| HDB           | Button 1  | 11   | D11 |     | x   | HD Bell                          |
| HDBTN         | Button 2  | 12   | D12 |     | x   | HD Button (G_INT,G_T)            |
| **Relays**    |           |      |     |     |     |                                  |
| HD_L          | Relay_i 1 | 47   | D47 |     |     | Relay                            |
| HD_U          | Relay_i 2 | 48   | D48 |     |     | Relay                            |
| **LED**       |           |      |     |     |     |                                  |
| HD_LED R      | PWM 1     | 13   | D13 |     |     | PWM                              |
| HD_LED G      | PWM 2     | 14   | D14 |     |     | PWM                              |
| HD_LED B      | PWM 3     | 21   | D21 |     |     | PWM                              |
| **I2S Audio** |           |      |     |     |     |                                  |
| LRC           | I2S_WS    | 4    | D04 | 5v  | x   | i2s                              |
| BCLK          | I2S_BCLK  | 5    | D05 |     |     | i2s                              |
| DIN           | I2S_DOUT  | 6    | D05 |     |     | i2s                              |
| **PIR**       |           |      |     |     |     |                                  |
| HDP           | Switch 4  | 8    | D08 | 3v  | x   | Garage Door PiR                  |
| **FPRINT**    |           |      |     |     |     |                                  |
| FPrint        | As608 TX  | 7    | D07 | x   | x   | Fingerprint                      |
| FPrint        | As608 RX  | 15   | D15 | x   | x   | Fingerprint                      |

## Settings

```
Backlog Template
{"NAME":"ESP32S3-HD","GPIO":[1,640,608,1,7840,7808,7776,5984,163,160,161,32,33,416,417,6016,1,1,1,1,1,418,0,0,0,0,0,1,1,1,1,1,1,1,1,1,256,257],"FLAG":0,"BASE":1};
Module 0;
Backlog IPAddress1 192.168.22.92; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName HD; FriendlyName1 HD_L; FriendlyName2 HD_U; FriendlyName3 HD_LED;
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode4 1; SwitchTopic 0; SwitchDebounce 100;
SetOption73 1; SetOption32 20; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
SetOption0 0; PowerOnState 0; PulseTime1 2; PulseTime2 0;
TelePeriod 3600;
SetOption20 1; Dimmer 100;
Webbutton1 LOCK; Webbutton2 UNLOCK; Webbutton3 LED;
SaveData 3600;
Restart 1;
```

### Rules

- Publish switches
- Autolock after 10m
- Event HTTP for relays
- Event MQTT for relays
- Publish RFID
- Fingerprint
- Sounds

- Buttons
  - HDB (Bell)
  - HDBTN
    - 1x G_INT
    - 2x G_T
    - 3x G_O
    - 4x Toggle Audio Mute
    - Long Press G_T
- LED
  - ON (G & GDL closed)
  - OFF (G & GDL open)
  - BLINK (G || GDL open)

### Commands

```
http://192.168.22.92/cm?cmnd=event%20G%5FT=1
http://192.168.22.92/cm?cmnd=event%20GD%5FL=1
http://192.168.22.92/cm?cmnd=event%20GD%5FU=1
http://192.168.22.92/cm?cmnd=event%20GD%5FO=1
muh/portal/RLY/cmnd G_T
muh/portal/RLY/cmnd GD_L
muh/portal/RLY/cmnd GD_U
muh/portal/RLY/cmnd GD_O
```
