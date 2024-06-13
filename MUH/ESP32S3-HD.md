# ESP32-S3 HD
## Template
```
{"NAME":"ESP32-S3-DevKitC-HD","GPIO":[1,640,608,1,7840,7808,7776,5984,163,160,161,32,33,226,1,6016,1,1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,256,257],"FLAG":0,"BASE":1}
```
## Table
| NAME | MODULE | GPIO | PIN | + | - | DESC |
|:--|:--|:--|--:|:--|---|---|
| **RTC** | | | | | | |
| SDA | I2C SDA | 1 | D01 | x | x | RTC DS3231 |
| SCL | I2C SCL | 2 | D02 | | | RTC DS3231 |
| **Reeds** | | | | | | |
| HD | Switch 1 | 9 | D09 | | x | Garage Door Reed |
| HDL | Switch 2 | 10 | D10 | 3v | x | Garage Door Lock Reed (with LED) |
| HDB | Button 1 | 11 | D11 |   | x | HD Bell |
| HDBTN | Button 2 | 12 | D12 |   | x | HD Button (G_INT,G) |
| **Relays** | | | | | | |
| HD_L | Relay_i 1 | 48 | D48 | | | Relay |
| HD_U | Relay_i 2 | 49 | D49 | | | Relay |
| HD_LED | Relay 5 | 13 | D13 | | | Relay |
| **I2S Audio** | | | | | | |
| LRC | I2S_WS | 4 | D04 | 5v | x | i2s |
| BCLK | I2S_BCLK | 5 | D05 | | | i2s |
| DIN | I2S_DOUT | 6 | D05 | | | i2s |
| **PIR** | | | | | | |
| HDP | Switch 4 | 8 | D08 | 3v | x | Garage Door PiR |
| **RFID** | | | | | | |
| RFID | RDM6300 RX | 21 | D21 | x | x | RFID |
| **FPRINT** | | | | | | |
| FPrint | As608 TX | 7 | D07 | x | x | RFID |
| FPrint | As608 RX | 15 | D15 | x | x | RFID |

## Settings
```
Backlog IPAddress1 192.168.22.92; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1
Backlog DeviceName HD; FriendlyName1 HD; 
SetOption114 1; SwitchMode1 2; SwitchMode2 2; SwitchMode4 1; SwitchTopic 0; SwitchDebounce 100;
SetOption73 1; SetOption32 20; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
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
- Fingerprint
#### Rule 3
- Sounds
```
Rule1
ON Switch1#Boot DO var1 %value% ENDON
ON Switch2#Boot DO var2 %value% ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/portal/HD/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON System#Boot DO IF (%var2%!=%mem2%) mem2 %var2%; Publish2 muh/portal/HDL/json {"state": %var2%, "time": "%timestamp%"} ENDIF ENDON
ON Switch1#state!=%mem1% DO Backlog mem1 %value%; mem6 %timestamp%; Publish2 muh/portal/HD/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch2#state!=%mem2% DO Backlog mem2 %value%; mem7 %timestamp%; Publish2 muh/portal/HDL/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch4#state DO Publish muh/portal/HDP/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Button1#state DO Publish muh/portal/HDB/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Button2#state DO Publish muh/portal/HDBTN/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Button2#state=10 DO Publish tasmota/cmnd/tasmota_9521A4/POWER 2 ENDON
ON Button2#state=11 DO Publish muh/portal/RLY/cmnd G_T ENDON
ON Button2#state=12 DO Publish muh/portal/RLY/cmnd GD_O ENDON
ON Button2#state=13 DO Publish muh/portal/RLY/cmnd GD_L ENDON

Rule2
ON Switch1#state DO var1 %value% ENDON
ON Switch2#state DO var2 %value% ENDON
ON Time#Minute|1 DO Publish2 muh/portal/HD/json {"state": %mem1%, "time": "%mem6%"} ENDON
ON Time#Minute|1 DO Publish2 muh/portal/HDL/json {"state": %mem2%, "time": "%mem7%"} ENDON
ON Time#Minute=1 DO IF ((%var1%==1) AND (%var2%==0)) Power1 1 ENDIF ENDON
ON Time#Minute=1411 DO IF ((%var1%==1) AND (%var2%==0)) Power1 1 ENDIF ENDON
ON mqtt#connected DO Subscribe RLY, muh/portal/RLY/cmnd ENDON
ON Event#RLY=HD_L DO Power1 1 ENDON
ON Event#RLY=HD_U DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON Event#RLY=HD_O DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON mqtt#connected DO Subscribe LEDG, muh/portal/G/json, state ENDON
ON mqtt#connected DO Subscribe LEDGDL, muh/portal/GDL/json, state ENDON
ON Event#LEDG DO Backlog var3 %value%; IF ((%var3%==1) AND (%var4%==1)) Power3 1 ELSEIF ((%var3%==0) AND (%var4%==0)) Power3 0 ELSE Power3 3 ENDIF ENDON
ON Event#LEDGDL DO Backlog var4 %value%; IF ((%var3%==1) AND (%var4%==1)) Power3 1 ELSEIF ((%var3%==0) AND (%var4%==0)) Power3 0 ELSE Power3 3 ENDIF ENDON
ON System#Boot DO i2sgain 30 ENDON

Rule3
ON FPrint#Id DO var9 %value% ENDON
ON FPrint#Confidence>20 DO IF (%var2%==1) Power2 1; Delay 10; Power2 0 ELSE Power1 1 ENDIF ENDON
ON FPrint#Confidence>20 DO Publish muh/portal/FPRINT/HD/json {"uid": %var9%, "confidence": %value%, "time": "%timestamp%", "source": "HD"} ENDON
ON FPrint#Confidence>20 DO i2splay +/RFID1.mp3 ENDON
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G!=%mem11% DO Backlog mem11 %value%; i2splay +/G%value%.mp3 ENDON  
ON mqtt#connected DO Subscribe GD, muh/portal/GD/json, state ENDON
ON Event#GD!=%mem12% DO Backlog mem12 %value%; i2splay +/GD%value%.mp3 ENDON
ON Switch1#state DO i2splay +/HD%value%%Var16%.mp3 ENDON
ON Button1#state=10 DO Backlog i2sgain 100; i2splay +/HDB%Var16%.mp3; i2sgain 40 ENDON
ON Time#Minute|30 DO i2splay +/PC.mp3 ENDON
ON Time#Minute=60 DO Backlog event checkdate=%timestamp% ENDON
ON event#checkdate$|-12-24T DO Var16 X ENDON
ON event#checkdate$|-12-25T DO Var16 X ENDON
ON event#checkdate$|-12-26T DO Var16 " ENDON

ON event#HD_L=1 DO Power1 1 ENDON
ON event#HD_U=1 DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON event#HD_O=1 DO Backlog Power2 1; Delay 10; Power2 0 ENDON
ON mqtt#connected DO Subscribe RLY, muh/portal/RLY/cmnd ENDON
ON Event#RLY=HD_L DO Power1 1 ENDON
ON Event#RLY=HD_U DO Backlog Power2 1; Delay 2; Power2 0 ENDON
ON Event#RLY=HD_O DO Backlog Power2 1; Delay 10; Power2 0 ENDON
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
### autoexec.be
- Button Rules
- MQTT & HTTP API
- Pendeluhr

# 2024
### Hittl Plug
```
tasmota.add_cron("0 30 9 * 6-9 *", def (value) tasmota.set_power(0, true) end, "summer_on")
tasmota.add_cron("0 0 23 * 6-9 *", def (value) tasmota.set_power(0, false) end, "summer_off")
tasmota.add_cron("0 0 6,22 * 1-5,10-12 *", def (value) tasmota.set_power(0, false) end, "winter_off")
```