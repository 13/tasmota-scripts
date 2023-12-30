# Plugs
## ESP8266EX Athom Plug V2
- Upgrade first Tasmota-Minimal/Lite then Tasmota
## Template
```
{"NAME":"Athom Plug V2","GPIO":[0,0,0,3104,0,32,0,0,224,576,0,0,0,0],"FLAG":0,"BASE":18}
```
## Settings
- Send MQTT on every 1 watt change
```
Backlog DeviceName HZ_BRENNER; FriendlyName1 HZ_BRENNER; 
PowerDelta 101
```
```
Backlog DeviceName KMMR_PC; FriendlyName1 KMMR_PC; 
```
## Rules
- F1: von Montag bis Freitag von 8:00 bis 19:00 Uhr, Feiertage ausgeschlossen
- F2: von 7:00 bis 8:00 Uhr, von 19:00 bis 23:00 Uhr von Montag bis Freitag, sowie Samstag von 7:00 bis 23:00 Uhr, Feiertage ausgeschlossen
- F3: von 00:00 bis 7:00 Uhr und von 23:00 bis 24:00 Uhr von Montag bis Samstag, Sonn- und Feiertage von 00:00 bis 24:00 Uhr.
### Rule 1
- Summermode
- At boot turn ON if Warmwater under 45
- Summer check if <= 40 and turn on 19:00 and turn off 21:30
### Rule 2
- Fallmode (Months 05,09,10)
- 06:30-08:00 ON
- 19:00-20:30 ON
### Rule 3
- Wintermode (Months 01,02,03,04,11,12)
- Turn ON from 05:00 - 23:00
```
Rule1
ON mqtt#connected DO Subscribe WwTemp, shellies/HZ_WW/status/temperature:102, tC ENDON
ON Event#WwTemp<=40 DO Var1 1 ENDON
ON Event#WwTemp>40 DO Var1 0 ENDON
ON Time#Minute=360 DO Backlog event bron1=%timestamp% ENDON
ON event#bron1$|-06- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON event#bron1$|-07- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON event#bron1$|-08- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON Time#Minute=1140 DO Backlog event bron2=%timestamp% ENDON
ON event#bron2$|-06- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON event#bron2$|-07- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON event#bron2$|-08- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON Time#Minute=480 DO Backlog event brsoff1=%timestamp% ENDON
ON event#brsoff1$|-06- DO Power 0 ENDON
ON event#brsoff1$|-07- DO Power 0 ENDON
ON event#brsoff1$|-08- DO Power 0 ENDON
ON Time#Minute=1260 DO Backlog event brsoff2=%timestamp% ENDON
ON event#brsoff2$|-06- DO Power 0 ENDON
ON event#brsoff2$|-07- DO Power 0 ENDON
ON event#brsoff2$|-08- DO Power 0 ENDON

Rule2
ON Time#Minute=360 DO Backlog event brfon=%timestamp% ENDON
ON event#brfon$|-05- DO Power 1 ENDON
ON event#brfon$|-09- DO Power 1 ENDON
ON event#brfon$|-10- DO Power 1 ENDON
ON Time#Minute=1140 DO Backlog event brfon=%timestamp% ENDON
ON event#brfon$|-05- DO Power 1 ENDON
ON event#brfon$|-09- DO Power 1 ENDON
ON event#brfon$|-10- DO Power 1 ENDON
ON Time#Minute=480 DO Backlog event brfoff=%timestamp% ENDON
ON event#brfoff$|-05- DO Power 0 ENDON
ON event#brfoff$|-09- DO Power 0 ENDON
ON event#brfoff$|-10- DO Power 0 ENDON
ON Time#Minute=1230 DO Backlog event brfoff=%timestamp% ENDON
ON event#brfoff$|-05- DO Power 0 ENDON
ON event#brfoff$|-09- DO Power 0 ENDON
ON event#brfoff$|-10- DO Power 0 ENDON

Rule3
ON Time#Minute=300 DO Backlog event brwon=%timestamp% ENDON
ON event#brwon$|-01- DO Power 1 ENDON
ON event#brwon$|-02- DO Power 1 ENDON
ON event#brwon$|-03- DO Power 1 ENDON
ON event#brwon$|-04- DO Power 1 ENDON
ON event#brwon$|-11- DO Power 1 ENDON
ON event#brwon$|-12- DO Power 1 ENDON
ON Time#Minute=1380 DO Backlog event brwoff=%timestamp% ENDON
ON event#brwoff$|-01- DO Power 0 ENDON
ON event#brwoff$|-02- DO Power 0 ENDON
ON event#brwoff$|-03- DO Power 0 ENDON
ON event#brwoff$|-04- DO Power 0 ENDON
ON event#brwoff$|-11- DO Power 0 ENDON
ON event#brwoff$|-12- DO Power 0 ENDON
```

## Shelly Plug S
- Upgrade first Tasmota-Minimal/Lite then Tasmota
## Template
```
{"NAME":"Shelly Plug S","GPIO":[56,255,158,255,255,134,0,0,131,17,132,21,255],"FLAG":2,"BASE":45}
```
## Settings
- Sunrise/Sunset GPS Villach ~ -10 Mins
```
Backlog DeviceName BROLICHT; FriendlyName1 BROLICHT;
Latitude 46.6086;  Longitude 13.8506;
```


## Rules
- on boot check last state
- every minute check if sunset nautical on
- sunrise off
- change sunrise/sunset +-Minutes
```
Rule1
ON Time#Initialized DO Backlog var11=%sunrise%+30; var12=%sunset%-30; event checksunrise=%time%; event checksunset=%time%; event checkDaylight=%var1% ENDON
ON event#checksunrise>%var11% DO Var1 0 ENDON
ON event#checksunset<%var12% DO Var2 0 ENDON
ON event#checksunrise<%var11% DO Var1 1 ENDON
ON event#checksunset>%var12% DO Var2 1 ENDON
ON event#checkDaylight==%var2% DO Power 0 ENDON
ON event#checkDaylight!=%var2% DO Power 1 ENDON
ON Time#Minute|5 DO Backlog event checksunrise=%time%; event checksunset=%time%; event checkDaylight=%var1% ENDON

// ALTERNATIVE IF/ENDIF
Rule1
ON Time#Initialized DO Backlog event checksunrise=%time%; event checksunset=%time%; event checkDark ENDON
ON event#checksunrise>%sunrise% DO Var1 0 ENDON
ON event#checksunset<%sunset% DO Var2 0 ENDON
ON event#checksunrise<%sunrise% DO Var1 1 ENDON
ON event#checksunset>%sunset% DO Var2 1 ENDON
ON event#checkDark DO IF (%var1%==%var2%) Power 0 ELSE Power 1 ENDIF ENDON
ON Time#Minute|5 DO Backlog event checksunrise=%time%; event checksunset=%time%; event checkDark ENDON
```
