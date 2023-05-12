# Shelly 2.5
## Template
```
{"NAME":"Shelly 2.5","GPIO":[56,0,17,0,21,83,0,0,6,82,5,22,156],"FLAG":2,"BASE":18}
```
## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 2;
Backlog PowerOnState 0; SetOption80 1; ShutterRelay1 1; Interlock 1,2; Interlock ON;
Backlog DeviceName ROLLERK2; FriendlyName1 ROLLERK2; 
ShutterOpenDuration 17; ShutterCloseDuration 17;

Backlog DeviceName ROLLERK1; FriendlyName1 ROLLERK1; 
ShutterOpenDuration 17; ShutterCloseDuration 17;
```
## Rules
### Rule 1
- Open/Close at sunrise/sunset
- Summer close/open at 09:30/18:00 
```
Rule1
  ON Time#Minute=%sunrise% DO ShutterOpen ENDON
  ON Time#Minute=%sunset% DO ShutterClose ENDON
  ON Time#Minute=510 DO Backlog event smrc=%timestamp% ENDON
  ON event#smrc$|-06- DO ShutterClose ENDON
  ON event#smrc$|-07- DO ShutterClose ENDON
  ON event#smrc$|-08- DO ShutterClose ENDON
  ON Time#Minute=1080 DO Backlog event smro=%timestamp% ENDON
  ON event#smro$|-06- DO ShutterOpen ENDON
  ON event#smro$|-07- DO ShutterOpen ENDON
  ON event#smro$|-08- DO ShutterOpen ENDON
```
## Commands
```
Publish tasmota/cmnd/tasmota_XXXXXX/ShutterStop
```

## TODO

