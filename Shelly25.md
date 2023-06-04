# Shelly 2.5
## Template
```
{"NAME":"Shelly 2.5","GPIO":[320,0,0,0,224,193,0,0,640,192,608,225,3456,4736],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 0;
Backlog SerialLog 0; PowerOnState 0; SetOption80 1; ShutterRelay1 1; Interlock 1,2; Interlock ON;

Backlog DeviceName ROLLERK2; FriendlyName1 ROLLERK2; 
ShutterOpenDuration 18; ShutterCloseDuration 18;

Backlog DeviceName ROLLERK1; FriendlyName1 ROLLERK1; 
Backlog ShutterOpenDuration 28; ShutterCloseDuration 28;

MqttWifiTimeout 1000
```
## Calibration
```
ShutterSetClose
ShutterSetOpen
ShutterSetHalfway 50
```

## Rules
### Rule 1
- Open/Close at sunrise/sunset
- Set shutter position MQTT
```
Rule1
ON Time#Minute=%sunrise% DO ShutterOpen ENDON
ON Time#Minute=%sunset% DO ShutterClose ENDON
ON Shutter1#Position DO Publish2 tasmota/status/%topic%/pos %value% ENDON
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

## Commands
```
Publish tasmota/cmnd/tasmota_XXXXXX/ShutterStop
```

## TODO

