# Shelly Plus 1

## Template
```
{"NAME":"Shelly Plus 1","GPIO":[288,0,0,0,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
```
{"NAME":"Shelly Plus 1 ADDON","GPIO":[288,1,0,1,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
```
{"NAME":"Shelly Plus 1 RTC","GPIO":[1,1,0,1,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120;
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 1;
```

## HZ_UD
- Turn OFF after 5h (1800)
- RTC
- Kommertemp >= 21 OFF
```
Rule1
ON Power1#state=1 DO RuleTimer1 1800 ENDON
ON Power1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe TEMPK1, muh/sensors/22/json, T2 ENDON
ON mqtt#connected DO Subscribe TEMPK2, muh/sensors/22/json, T4 ENDON
ON mqtt#connected DO Subscribe TEMPK3, muh/sensors/87/json, T1 ENDON
ON mqtt#connected DO Subscribe TEMPK3, muh/sensors/87/json, T2 ENDON
ON Event#TEMPK1>=21 DO Power1 0 ENDON
ON Event#TEMPK2>=21 DO Power1 0 ENDON
ON Event#TEMPK3>=21 DO Power1 0 ENDON
ON Event#TEMPK4>=21 DO Power1 0 ENDON
```
