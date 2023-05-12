# Shelly 2.5
## Template
```
{"NAME":"Shelly 2.5","GPIO":[56,0,17,0,21,83,0,0,6,82,5,22,156],"FLAG":2,"BASE":18}
```
## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 2;
Backlog DeviceName ROLLERK2; FriendlyName1 ROLLERK2; 
Backlog SetOption21 1
```
## Rules
- Endpoint
```
Rule1
  ON Time#Minute=%sunrise% DO ShutterOpen ENDON
  ON Time#Minute=%sunset% DO ShutterClose ENDON
  ON energy#current[2]>0.600 DO ShutterStop ENDON
  ON energy#current[1]>0.600 DO ShutterStop ENDON  
Rule1 5
```

```

  
```

## TODO

