# Sehlly Plus 1 PM

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
- Turn off after 30m
- Turn on if G=1
- Extend light Timer
```
Rule1
ON Switch1#state=1 DO Backlog Power1 1; RuleTimer1 1800 ENDON
ON Switch1#state=0 DO Backlog Power1 0; RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON

ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G=1 DO Backlog event checksunrise=%time%; event checksunset=%time% ENDON
ON event#checksunrise<%sunrise% DO Backlog Power1 1; RuleTimer1 300 ENDON
ON event#checksunset>%sunset% DO Backlog Power1 1; RuleTimer1 300 ENDON

ON mqtt#connected DO Subscribe GDP, muh/portal/GDP/json, state ENDON
ON Event#GDP=1 DO Backlog Power1 1; RuleTimer1 300 ENDON
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
ON Event#G=1 DO Backlog event checksunrise=%time%; event checksunset=%time% ENDON
ON event#checksunrise<%sunrise% DO Backlog Power1 1; RuleTimer1 30 ENDON
ON event#checksunset>%sunset% DO Backlog Power1 1; RuleTimer1 30 ENDON
```
