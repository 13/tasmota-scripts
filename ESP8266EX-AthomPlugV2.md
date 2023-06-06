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
```
Rule1
ON mqtt#connected DO Subscribe WwTemp, shellies/HZ_WW/status/temperature:102, tC ENDON
ON Event#WwTemp<=40 DO Var1 1 ENDON
ON Event#WwTemp>40 DO Var1 0 ENDON
ON Time#Minute=1140 DO Backlog event bron=%timestamp% ENDON
ON event#bron$|-06- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON event#bron$|-07- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON event#bron$|-08- DO IF (Var1 == 1) Power 1 ENDIF ENDON
ON Time#Minute=480 DO Backlog event broff=%timestamp% ENDON
ON event#broff$|-06- DO Power 0 ENDON
ON event#broff$|-07- DO Power 0 ENDON
ON event#broff$|-08- DO Power 0 ENDON
```
