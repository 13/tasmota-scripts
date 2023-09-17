# ESP8266EX Athom Plug V2
- Upgrade first Tasmota-Minimal/Lite then Tasmota
## Template
```
{"NAME":"Athom Plug V2","GPIO":[0,0,0,3104,0,32,0,0,224,576,0,0,0,0],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog DeviceName HZ_BRENNER; FriendlyName1 HZ_BRENNER; 
PowerDelta 101
```
```
Backlog DeviceName KMMR_PC; FriendlyName1 KMMR_PC; 
```
## Rules
### Rule 1
- Summermode
- Zeitzone F1 MO-FR 08-19
- Zeitzone F2/F3 MO-FR 19-08, SA-SO 0-24, FEIERTAGE
- At boot turn ON if Warmwater under 45
- Summer check if <= 40 and turn on 19:00 and turn off 21:30
### Rule 2
- Wintermode
- Zeitzone F1 MO-FR 08-19
- Zeitzone F2/F3 MO-FR 19-08, SA-SO 0-24, FEIERTAGE
- 07-08 ON
- 19-20 ON
### Rule 3
- Wintermode
- Zeitzone F1 MO-FR 08-19
- Zeitzone F2/F3 MO-FR 19-08, SA-SO 0-24, FEIERTAGE
- Turn Off from 23-05
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
ON Time#Minute=1140 DO Backlog event brfon=%timestamp% ENDON
ON event#brfon$|-05- DO Power 1 ENDON
ON event#brfon$|-09- DO Power 1 ENDON
ON Time#Minute=420 DO Backlog event brfoff=%timestamp% ENDON
ON event#brfoff$|-05- DO Power 0 ENDON
ON event#brfoff$|-09- DO Power 0 ENDON
ON Time#Minute=1200 DO Backlog event brfoff=%timestamp% ENDON
ON event#brfoff$|-05- DO Power 0 ENDON
ON event#brfoff$|-09- DO Power 0 ENDON

Rule3
ON Time#Minute=420 DO Backlog event brwon=%timestamp% ENDON
ON event#brwon$|-01- DO Power 1 ENDON
ON event#brwon$|-02- DO Power 1 ENDON
ON event#brwon$|-03- DO Power 1 ENDON
ON event#brwon$|-04- DO Power 1 ENDON
ON event#brwon$|-10- DO Power 1 ENDON
ON event#brwon$|-11- DO Power 1 ENDON
ON event#brwon$|-12- DO Power 1 ENDON
ON Time#Minute=1380 DO Backlog event brwoff=%timestamp% ENDON
ON event#brwoff$|-01- DO Power 0 ENDON
ON event#brwoff$|-02- DO Power 0 ENDON
ON event#brwoff$|-03- DO Power 0 ENDON
ON event#brwoff$|-04- DO Power 0 ENDON
ON event#brwoff$|-10- DO Power 0 ENDON
ON event#brwoff$|-11- DO Power 0 ENDON
ON event#brwoff$|-12- DO Power 0 ENDON
```