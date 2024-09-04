# Shelly 2.5
## Template
```
{"NAME":"Shelly 2.5","GPIO":[320,0,0,0,224,193,0,0,640,192,608,225,3456,4736],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog SerialLog 0; PowerOnState 0; SetOption80 1; ShutterRelay1 1; Interlock 1,2; Interlock ON;

Backlog DeviceName ROLLERK1; FriendlyName1 ROLLERK1; 
Backlog ShutterOpenDuration 28; ShutterCloseDuration 28;

Backlog DeviceName ROLLERK2; FriendlyName1 ROLLERK2; 
ShutterOpenDuration 18; ShutterCloseDuration 18;

MqttWifiTimeout 1000
```
## Calibration
- ROLLERK1 DOOR (RIGHT)
```
ShutterSetClose
shutteropenduration 29
shuttercloseduration 29
ShutterSetHalfway 50
shuttermotordelay 0
shuttercloseduration 26.7
shuttermotordelay 0.35
shuttercalibration 29 72 125 192 202
ShutterSetHalfway 65
```
- ROLLERK2 WINDOW (LEFT)
```
ShutterSetClose
shutteropenduration 18
shuttercloseduration 18
ShutterSetHalfway 50
shuttermotordelay 0
shuttercloseduration 17.4
shuttermotordelay 0
shuttercalibration 15 37 83 95 97
ShutterSetHalfway 72
```

## Rules
### Rule 1
- Open/Close at sunrise/sunset
- Set shutter position MQTT
- // Window close complete
- // Door close 75%
- // Window open at 06:00
- Set Nautical Sunrise and Civil Sunset
```
Rule1
ON Shutter1#Position DO Publish2 tasmota/status/%topic%/pos %value% ENDON
ON Time#Minute=30 DO Sunrise 2 ENDON
ON Time#Minute=720 DO Sunrise 1 ENDON
ON Time#Minute=360 DO ShutterOpen ENDON
ON Time#Minute=%sunrise% DO ShutterPosition 60 ENDON
ON Time#Minute=%sunset% DO ShutterClose ENDON
// BIG
ON Time#Minute=%sunset% DO Backlog event scs=%timestamp% ENDON
ON event#scs$|-05- DO ShutterPosition 25 ENDON
ON event#scs$|-06- DO ShutterPosition 25 ENDON
ON event#scs$|-07- DO ShutterPosition 25 ENDON
ON event#scs$|-08- DO ShutterPosition 25 ENDON
ON event#scs$|-09- DO ShutterPosition 25 ENDON
ON event#scs$|-10- DO ShutterPosition 25 ENDON
```
### Rule 2
- Summer close/open at 10:00/18:00 if HOT (heat protection)
```
Rule2
ON mqtt#connected DO Subscribe SolarTemp, muh/wst/data/B327, temp_c ENDON
ON Event#SolarTemp>=20 DO Var1 1 ENDON
ON Event#SolarTemp<20 DO Var1 0 ENDON
ON Time#Minute=600 DO Backlog event smrc=%timestamp% ENDON
ON event#smrc$|-06- DO IF (Var1 == 1) ShutterClose ENDIF ENDON
ON event#smrc$|-07- DO IF (Var1 == 1) ShutterClose ENDIF ENDON
ON event#smrc$|-08- DO IF (Var1 == 1) ShutterClose ENDIF ENDON
ON Time#Minute=1020 DO Backlog event smro=%timestamp% ENDON
ON event#smro$|-06- DO ShutterOpen ENDON
ON event#smro$|-07- DO ShutterOpen ENDON
ON event#smro$|-08- DO ShutterOpen ENDON
```
### Rule 3
- Winter close at 09:00 to (shutter door to 4% sun protection)
- Winter close at 09:00 if UV Level (sun protection floor)
```
Rule3
ON Time#Minute=540 DO Backlog event sdwc=%timestamp% ENDON
ON event#sdwc$^-06- DO ShutterPosition 4 ENDON
ON event#sdwc$^-07- DO ShutterPosition 4 ENDON
ON event#sdwc$^-08- DO ShutterPosition 4 ENDON

ON mqtt#connected DO Subscribe SolarUv, muh/wst/data/B327, uv ENDON
ON Event#SolarUv>=1 DO Var2 1 ENDON
ON Event#SolarUv<1 DO Var2 0 ENDON
ON Time#Minute=540 DO Backlog event sdwc=%timestamp% ENDON
ON event#sdwc$^-06- DO IF (Var2 == 1) ShutterPosition 4 ENDIF ENDON
ON event#sdwc$^-07- DO IF (Var2 == 1) ShutterPosition 4 ENDIF ENDON
ON event#sdwc$^-08- DO IF (Var2 == 1) ShutterPosition 4 ENDIF ENDON
```
## Commands
```
Publish tasmota/cmnd/tasmota_XXXXXX/ShutterStop
```

# Shelly Plus 2PM
## Template
```
{}
```
## Settings
```
Backlog SerialLog 0; PowerOnState 0; SetOption80 1; ShutterRelay1 1; Interlock 1,2; Interlock ON;

Backlog DeviceName ROLLERK1; FriendlyName1 ROLLERK1; 
Backlog ShutterOpenDuration 28; ShutterCloseDuration 28;
```
## Calibration
- ROLLERK1 DOOR (RIGHT)
```
close the shutter until endstop is reached (repeat: backlog shuttersetopen;shutterclose until closed) - interlock 1,2 - interlock on - shutterrelay1 1 - shuttersetup (shutter will start moving....)
```
## Rules
### Rule 1
- Open/Close at sunrise/sunset
- Set shutter position MQTT
- // Window close complete
- // Door close 75%
- // Window open at 06:00
- Set Nautical Sunrise and Civil Sunset
```
Rule1
ON Shutter1#Position DO Publish2 tasmota/status/%topic%/pos %value% ENDON
ON Time#Minute=30 DO Sunrise 2 ENDON
ON Time#Minute=720 DO Sunrise 1 ENDON
ON Time#Minute=360 DO ShutterOpen ENDON
ON Time#Minute=%sunrise% DO ShutterOpen ENDON
ON Time#Minute=%sunset% DO ShutterClose ENDON
// BIG
ON Time#Minute=%sunset% DO Backlog event scs=%timestamp% ENDON
ON event#scs$|-05- DO ShutterPosition 25 ENDON
ON event#scs$|-06- DO ShutterPosition 25 ENDON
ON event#scs$|-07- DO ShutterPosition 25 ENDON
ON event#scs$|-08- DO ShutterPosition 25 ENDON
ON event#scs$|-09- DO ShutterPosition 25 ENDON
ON event#scs$|-10- DO ShutterPosition 25 ENDON
```
