# Shelly Plus 1 PM

## Template
```
{"NAME":"Shelly Plus 1PM","GPIO":[0,0,0,0,192,2720,0,0,0,0,0,0,0,0,2656,0,0,0,0,2624,0,32,224,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120;
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 1;
```

## G_INT
### Settings
```
Backlog SwitchMode 1
```
### Rules
#### Rule1
- Turn OFF after 10m
- Turn OFF after 60m with Switch1=1
### Rule2
- Turn ON (5m) if G=0 && GDP=0
- Turn ON (5m) if GD=0 && GDP=0
- Extend ON (5m) if GDP=1
```
Rule1
ON Power1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 300 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/G_INT/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Power1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/G_INT/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Power1#state DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ELSE RuleTimer1 0 ENDIF ENDON
ON Switch1#state=1 DO Backlog Power1 1; RuleTimer1 3600 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
Rule2
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G=0 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO IF (var2==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss0>%sunset% DO IF (var2==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON mqtt#connected DO Subscribe GD, muh/portal/GD/json, state ENDON
ON Event#GD=0 DO Backlog event chcksr1=%time%; event chckss1=%time% ENDON
ON event#chcksr1<%sunrise% DO IF (var2==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss1>%sunset% DO IF (var2==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON mqtt#connected DO Subscribe GDP, muh/portal/GDP/json, state ENDON
ON Event#GDP=1 DO Backlog event chcksr2=%time%; event chckss2=%time% ENDON
ON Event#GDP DO var2 %value% ENDON
ON event#chcksr2<%sunrise% DO IF (var1==1) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss2>%sunset% DO IF (var1==1) Power1 1; RuleTimer1 300 ENDIF ENDON
```

## G_EXT
### Settings
Momentary switch
```
Backlog SwitchMode 5; SetOption1 1; SetOption32 30
```
### Rules
#### Rule1
- Turn OFF after 30m
- Turn OFF after 5s if Daylight
- Publish state to MQTT
- Turn ON Garage LIGHT
```
Rule1
ON Power1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 180 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/G_EXT/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Power1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/G_EXT/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Power1#state=1 DO IF ((%time% > %sunrise%) AND (%time% < %sunset%)) RuleTimer1 5 ELSE RuleTimer1 1800 ENDIF ENDON
ON Rules#Timer=1 DO Power1 0 ENDON

ON Switch1#state=3 DO Publish tasmota/cmnd/tasmota_9521A4/POWER 2 ENDON
```

## HD_INT
### Settings
```
Backlog SwitchMode 1
```
### Rules
- Turn OFF after 10m
- Turn ON (10m) if HD=0 & ShellyPiR=1
```
Rule1
ON Power1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/HD_INT/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Power1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/HD_INT/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Power1#state DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ELSE RuleTimer1 0 ENDIF ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe MTN, shellies/shellymotion2-8CF6811074B3/status, motion ENDON
ON Event#MTN=true DO var2 1 ENDON
ON Event#MTN=false DO var2 0 ENDON
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD=0 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO IF (var2==1) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss0>%sunset% DO IF (var2==1) Power1 1; RuleTimer1 300 ENDIF ENDON

ON mqtt#connected DO Subscribe HDP, muh/portal/HDP/json, state ENDON
ON Event#HDP=1 DO Backlog event chcksr2=%time%; event chckss2=%time% ENDON
ON event#chcksr2<%sunrise% DO IF (var1==1) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss2>%sunset% DO IF (var1==1) Power1 1; RuleTimer1 300 ENDIF ENDON

Rule1
ON Switch1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/HD_INT/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Switch1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/HD_INT/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Switch1#state DO Backlog var1 %value%; Power1 2; IF (%value%==1) RuleTimer1 600 ELSE RuleTimer1 0 ENDIF ENDON
ON Rules#Timer=1 DO Power1 2 ENDON
ON mqtt#connected DO Subscribe MTN, shellies/shellymotion2-8CF6811074B3/status, motion ENDON
ON Event#MTN=true DO var2 1 ENDON
ON Event#MTN=false DO var2 0 ENDON
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD=0 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO IF (var2==1) Power1 2; RuleTimer1 300 ENDIF ENDON
ON event#chckss0>%sunset% DO IF (var2==1) Power1 2; RuleTimer1 300 ENDIF ENDON
```

## HD_EXT
### Settings
```
Backlog SwitchMode 1
```
### Rules
- Turn OFF after 10m
- Turn ON (30s) if Shelly PiR2=1
- Turn ON (30s) if cam2mqtt
```
Rule1
ON Power1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 300 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/HD_EXT/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Power1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/HD_EXT/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Power1#state DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ELSE RuleTimer1 0 ENDIF ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe MTN, shellies/shellymotion2-8CF6811074B3/status, motion ENDON
ON Event#MTN=true DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss0>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON mqtt#connected DO Subscribe CP, cam2mqtt/camera/reolink_cam_1/event/onvif/object/people/detected ENDON
ON Event#CP=on DO Backlog event chcksr1=%time%; event chckss1=%time% ENDON
ON event#chcksr1<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss1>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON

Rule2
ON mqtt#connected DO Subscribe CPAI, cam2mqtt/camera/reolink_cam_1/event/reolink/aidetection/people/detected ENDON
ON Event#CPAI=on DO Backlog event chcksr2=%time%; event chckss2=%time% ENDON
ON event#chcksr2<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss2>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON mqtt#connected DO Subscribe CPET, cam2mqtt/camera/reolink_cam_1/event/onvif/object/pet/detected ENDON
ON Event#CPET=on DO Backlog event chcksr3=%time%; event chckss3=%time% ENDON
ON event#chcksr3<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss3>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON mqtt#connected DO Subscribe CPETAI, cam2mqtt/camera/reolink_cam_1/event/reolink/aidetection/pet/detected ENDON
ON Event#CPET=on DO Backlog event chcksr4=%time%; event chckss4=%time% ENDON
ON event#chcksr4<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss4>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
```
## STCK2_GANG
### Settings
```
Backlog SwitchMode1 1
Backlog SwitchMode2 5; SetOption1 1; SetOption32 30
```
### Rules
#### Rule1
- Turn OFF after 10m
```
Rule1
ON Power1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 300 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/STCK2_GANG/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Power1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/STCK2_GANG/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Power1#state DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ELSE RuleTimer1 0 ENDIF ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
```

## UD_GANG
### Settings
```
Backlog SwitchMode 0
```
### Rules
#### Rule1
- Turn OFF after 10m
```
Rule1
ON Power1#Boot DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 300 ENDIF ENDON
ON System#Boot DO IF (%var1%!=%mem1%) mem1 %var1%; Publish2 muh/lights/UD_GANG/json {"state": %var1%, "time": "%timestamp%"} ENDIF ENDON
ON Power1#state!=%mem1% DO Backlog mem1 %value%; Publish2 muh/lights/UD_GANG/json {"state": %value%, "time": "%timestamp%"} ENDON
ON Power1#state DO Backlog var1 %value%; IF (%value%==1) RuleTimer1 600 ELSE RuleTimer1 0 ENDIF ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
```

## STCK2_SW
## Template
```
{"NAME":"Shelly 1","GPIO":[1,1,0,1,224,192,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":46}
```
### Settings
```
Backlog SwitchMode 0
```
### Rules
#### Rule1
- Toggle HD_INT
```
Rule1
ON Switch1#state DO Publish tasmota/cmnd/tasmota_BE3540/POWER 2 ENDON
```
