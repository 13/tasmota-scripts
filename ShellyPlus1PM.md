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
- Turn OFF after 30m
- Turn ON (5m) if G=0 & GDP=0
- Turn ON (5m) if GD=0 & GDP=0
- Extend ON (5m) if GDP=1
```
Rule1
ON Switch1#state=1 DO RuleTimer1 1800 ENDON
ON Switch1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G=0 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO IF (var1==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss0>%sunset% DO IF (var1==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON mqtt#connected DO Subscribe GD, muh/portal/GD/json, state ENDON
ON Event#GD=0 DO Backlog event chcksr1=%time%; event chckss1=%time% ENDON
ON event#chcksr1<%sunrise% DO IF (var1==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss1>%sunset% DO IF (var1==0) Power1 1; RuleTimer1 300 ENDIF ENDON
ON mqtt#connected DO Subscribe GDP, muh/portal/GDP/json, state ENDON
ON Event#GDP=1 DO Backlog event chcksr2=%time%; event chckss2=%time% ENDON
ON Event#GDP DO var1 %value% ENDON
ON event#chcksr2<%sunrise% DO Backlog Power1 1; RuleTimer1 300 ENDON
ON event#chckss2>%sunset% DO Backlog Power1 1; RuleTimer1 300 ENDON
```

## G_EXT
- Turn OFF after 30m
- Turn ON (5m) if G=1
- Extend ON (5m) if GDP=1
```
Rule1
ON Switch1#state=1 DO RuleTimer1 1800 ENDON
ON Switch1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G=1 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO Backlog Power1 1; RuleTimer1 300 ENDON
ON event#chckss0>%sunset% DO Backlog Power1 1; RuleTimer1 300 ENDON
ON mqtt#connected DO Subscribe GDP, muh/portal/GDP/json, state ENDON
ON Event#GDP=1 DO Backlog event chcksr1=%time%; event chckss1=%time% ENDON
ON event#chcksr1<%sunrise% DO Backlog Power1 1; RuleTimer1 300 ENDON
ON event#chckss1>%sunset% DO Backlog Power1 1; RuleTimer1 300 ENDON
```

## HD_INT
- Turn OFF after 10m
- Turn ON (10m) if HD=0 & ShellyPiR=1
```
Rule1
ON Switch1#state=1 DO RuleTimer1 600 ENDON
ON Switch1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe HDPS, shellies/shellymotion2-8CF6811074B3/status, motion ENDON
ON Event#HDPS DO var1 %value% ENDON
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD=0 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO IF (var1==1) Power1 1; RuleTimer1 300 ENDIF ENDON
ON event#chckss0>%sunset% DO IF (var1==1) Power1 1; RuleTimer1 300 ENDIF ENDON

```

## HD_EXT
- Turn OFF after 10m
- Turn ON (30s) if Shelly PiR2=1
- Turn ON (30s) if cam2mqtt
```
Rule1
ON Switch1#state=1 DO RuleTimer1 1800 ENDON
ON Switch1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe G, shellies/shellymotion2-8CF6811074B3/status, motion ENDON
ON Event#G=1 DO Backlog event chcksr0=%time%; event chckss0=%time% ENDON
ON event#chcksr0<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss0>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON mqtt#connected DO Subscribe P, cam2mqtt/camera/reolink_cam_1/event/onvif/object/people/detected ENDON
ON Event#P=1 DO Backlog event chcksr1=%time%; event chckss1=%time% ENDON
ON event#chcksr1<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss1>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON mqtt#connected DO Subscribe PAI, cam2mqtt/camera/reolink_cam_1/event/onvif/object/people_ai/detected ENDON
ON Event#PAI=1 DO Backlog event chcksr2=%time%; event chckss2=%time% ENDON
ON event#chcksr2<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#chckss2>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
```