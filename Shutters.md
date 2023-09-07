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
- ROLLERK1 (RIGHT)
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
- ROLLERK2 (LEFT)
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
```
Rule1
ON Shutter1#Position DO Publish2 tasmota/status/%topic%/pos %value% ENDON
ON Time#Minute=%sunrise% DO ShutterOpen ENDON
ON Time#Minute=%sunset% DO ShutterClose ENDON
ON Time#Minute=%sunset% DO Backlog event scs=%timestamp% ENDON
ON event#scs$|-06- DO ShutterPosition 25 ENDON
ON event#scs$|-07- DO ShutterPosition 25 ENDIF ENDON
ON event#scs$|-08- DO ShutterPosition 25 ENDIF ENDON
ON event#scs$|-09- DO ShutterPosition 25 ENDON
```
### Rule 2
- Summer close/open at 11:00/18:00 if HOT
```
Rule2
ON mqtt#connected DO Subscribe SolarTemp, muh/sensors/DDD99C/json, DS18B20.Temperature ENDON
ON Event#SolarTemp>=40 DO Var1 1 ENDON
ON Event#SolarTemp<40 DO Var1 0 ENDON
ON Time#Minute=660 DO Backlog event smrc=%timestamp% ENDON
ON event#smrc$|-06- DO IF (Var1 == 1) ShutterClose ENDIF ENDON
ON event#smrc$|-07- DO IF (Var1 == 1) ShutterClose ENDIF ENDON
ON event#smrc$|-08- DO IF (Var1 == 1) ShutterClose ENDIF ENDON
ON Time#Minute=1020 DO Backlog event smro=%timestamp% ENDON
ON event#smro$|-06- DO ShutterOpen ENDON
ON event#smro$|-07- DO ShutterOpen ENDON
ON event#smro$|-08- DO ShutterOpen ENDON
```
### Rule 3
- Winter close at 09:00
```
Rule3
ON Time#Minute=540 DO Backlog event smrc=%timestamp% ENDON
ON event#smrc$|-01- ShutterClose ENDON
ON event#smrc$|-02- ShutterClose ENDON
ON event#smrc$|-03- ShutterClose ENDON
ON event#smrc$|-04- ShutterClose ENDON
ON event#smrc$|-05- ShutterClose ENDON
ON event#smrc$|-09- ShutterClose ENDON
ON event#smrc$|-10- ShutterClose ENDON
ON event#smrc$|-11- ShutterClose ENDON
ON event#smrc$|-12- ShutterClose ENDON
```
## Commands
```
Publish tasmota/cmnd/tasmota_XXXXXX/ShutterStop
```

## TODO

