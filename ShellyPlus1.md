# Shelly Plus 1

## Template
```
{"NAME":"Shelly Plus 1","GPIO":[288,0,0,0,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```

## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120;
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 1;
```

## HZ_UD
- Turn OFF after 5h
- RTC
- Kommertemp >= 21.5 OFF
```
Rule1
ON Power1#state=1 DO RuleTimer1 1800 ENDON
ON Power1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe TEMPK, muh/sensors/22/json, T2 ENDON
ON Event#TEMPK>=21.5 DO Power1 0 ENDON
```
