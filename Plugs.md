# Plugs
## All
- Tele 1w change
```
PowerDelta 101
```
- Power always ON
```
PowerOnState 1
```
## Calibrate
- PowerSet = 60.0 (Lightbulb)
- VoltageSet = 225 (Multimeter + Lightbulb)
- CurrentSet = 1000*(60.0/225) = 266.66
```
Backlog PowerSet 60.0; VoltageSet 225; CurrentSet 266.67
Backlog PowerSet 60.0; VoltageSet 226; CurrentSet 265.49
Backlog PowerSet 60.0; VoltageSet 227; CurrentSet 264.32

Backlog PowerSet 60.0; VoltageSet 231; CurrentSet 259.74
```
### 227
- A33929
## ESP8266EX Athom Plug V2
- Upgrade first Tasmota-Minimal/Lite then Tasmota
## Template
```
{"NAME":"Athom Plug V2","GPIO":[0,0,0,3104,0,32,0,0,224,576,0,0,0,0],"FLAG":0,"BASE":18}

{"NAME":"Athom Plug V3","GPIO":[0,0,0,32,0,224,576,0,0,0,0,0,0,0,0,0,0,0,0,0,3104,0],"FLAG":0,"BASE":1}
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
- Under 10 Lux turn on Light
```
Rule1
ON Time#Initialized DO Backlog var11=%sunrise%; var12=%sunset%-30; event checksunrise=%time%; event checksunset=%time% ENDON
ON event#checksunrise>%var11% DO Var1 0 ENDON
ON event#checksunrise<%var11% DO Var1 1 ENDON
ON event#checksunset<%var12% DO Var2 0 ENDON
ON event#checksunset>%var12% DO Var2 1 ENDON
ON var2#state==%var1% DO Power 0 ENDON
ON var2#state!=%var1% DO Power 1 ENDON
ON Time#Minute=%var11% DO Power 0 ENDON
ON Time#Minute=%var12% DO Power 1 ENDON

## < 5 || < 12
Rule2
ON mqtt#connected DO Subscribe LightLux, muh/WStation/data/B327, light_klx ENDON
ON Event#LightLux<12 DO Power 1 ENDON
ON Event#LightLux>12 DO Power 0 ENDON

###
ON Time#Minute|10 DO Backlog event checksunrise=%time%; event checksunset=%time% ENDON

// ALTERNATIVE IF/ENDIF
Rule1
ON Time#Initialized DO Backlog event checksunrise=%time%; event checksunset=%time% ENDON
ON event#checksunrise>%sunrise% DO Var1 0 ENDON
ON event#checksunset<%sunset% DO Var2 0 ENDON
ON event#checksunrise<%sunrise% DO Var1 1 ENDON
ON event#checksunset>%sunset% DO Var2 1 ENDON
ON event#checkDark DO IF (%var1%==%var2%) Power 0 ELSE Power 1 ENDIF ENDON
```

###
- ping and turn of dvbt and switch
```
Rule1
ON Time#Minute=0 DO ping4 192.168.22.18 ENDON
ON Time#Minute=420 DO Power1 1 ENDON
ON Ping#192.168.22.18#Reachable=false DO Power1 0 ENDON
ON Ping#192.168.22.18#Reachable=true DO Power1 1 ENDON

Rule1 on Time#Minute|5 do backlog var1 0;ping4 8.8.8.8;ping4 1.1.1.1;ping4 208.67.222.222; RuleTimer1 60 endon
          on Ping#8.8.8.8#Reachable=true do var1 1 endon 
          on Ping#1.1.1.1#Reachable=true do var1 1 endon 
          on Ping#208.67.222.222#Reachable=true do var1 1 endon 
          on Rules#Timer=1 do Power %var1% endon
```

## Shelly 3EM
```
{"NAME":"Shelly 3EM","GPIO":[1,1,288,1,32,8065,0,0,640,8064,608,224,8096,0],"FLAG":0,"BASE":18}
```
- http://{ip}:8050/setMaxPower?p=800
```
- var1 Power_Total
- var2 Power_Inverter + Power_Total/2
- (var1 + var2) / 2

Rule2
  ON System#Boot DO Backlog var1 0; var2 200; ENDON
  ON Energy#Power[1] DO var1 %value% ENDON
  ON var1#state>=800 DO WebSend [192.168.22.59:8050] /setMaxPower?p=800 ENDON
  ON var1#state<800 DO WebSend [192.168.22.59:8050] /setMaxPower?p=%var2% ENDON
  ON mqtt#connected DO Subscribe PowerInv, tasmota/tele/tasmota_0C6423/SENSOR, ENERGY.Power ENDON
  ON Event#PowerInv DO Backlog CalcRes 0; var2 = (var1 + %value%)*2; ADD2 0 ENDON

- plugs2
- var1 = Total Watt 3EM
- var2 = Total Watt Inv
- var3 = Total Watt to Operate
Rule1
  ON System#Boot DO Backlog var1 200; var2 0; var3 200 ENDON
  ON Energy#Power DO var2 %value% ENDON
  ON mqtt#connected DO Subscribe PowerEM, tasmota/tele/tasmota_5FF8B2/SENSOR, ENERGY.Power[1] ENDON
  ON Event#PowerEM DO Backlog CalcRes 0; var3 = (var2 + %value%)*2; ADD3 0 ENDON
  ON var3#state>=800 DO WebSend [192.168.22.59:8050] /setMaxPower?p=800 ENDON
  ON var3#state<800 DO WebSend [192.168.22.59:8050] /setMaxPower?p=%var3% ENDON



```

```
Rule3
  ON file#calib.dat DO {"state":0,"rms":{"current_a":3211982,"current_b":3189648,"current_c":3199282,"current_n":-1399975513,"current_s":266717838,"voltage_a":-731348,"voltage_b":-719234,"voltage_c":-732765},"angles":{"angle0":184,"angle1":172,"angle2":192},"powers":{"totactive":{"a":-1345486,"b":-1347556,"c":-1352447},"apparent":{"a":214497,"b":214494,"c":214496}},"energies":{"totactive":{"a":8731,"b":8730,"c":8730},"apparent":{"a":40353,"b":40352,"c":40361}}} ENDON
```

### calib.dat
```
{
  "state": 0,
  "rms": {
    "current_a": 3211982,
    "current_b": 3189648,
    "current_c": 3199282,
    "current_n": -1399975513,
    "current_s": 266717838,
    "voltage_a": -731348,
    "voltage_b": -719234,
    "voltage_c": -732765
  },
  "angles": {
    "angle0": 184,
    "angle1": 172,
    "angle2": 192
  },
  "powers": {
    "totactive": {
      "a": -1345486,
      "b": -1347556,
      "c": -1352447
    },
    "apparent": {
      "a": 214497,
      "b": 214494,
      "c": 214496
    }
  },
  "energies": {
    "totactive": {
      "a": 8731,
      "b": 8730,
      "c": 8730
    },
    "apparent": {
      "a": 40353,
      "b": 40352,
      "c": 40361
    }
  }
}
```
### Compiling tasmota-4M
```
#define USE_I2C
#define USE_ENERGY_SENSOR
#define USE_ADE7880
#define ADE7880_AIGAIN_INIT 3211982 // rms, current_a
#define ADE7880_BIGAIN_INIT 3189648 // rms, current_b
#define ADE7880_CIGAIN_INIT 3199282 // rms, current_c
#define ADE7880_NIGAIN_INIT 266717838 // rms, current_s !!
#define ADE7880_AVGAIN_INIT -731348 // rms, voltage_a
#define ADE7880_BVGAIN_INIT -719234 // rms, voltage_b
#define ADE7880_CVGAIN_INIT -732765 // rms, voltage_c
#define ADE7880_APHCAL_INIT 184 // angles, angle0
#define ADE7880_BPHCAL_INIT 172 // angles, angle1
#define ADE7880_CPHCAL_INIT 192 // angles, angle2
#define ADE7880_APGAIN_INIT -1345486 // powers, totactive, a
#define ADE7880_BPGAIN_INIT -1347556 // powers, totactive, b
#define ADE7880_CPGAIN_INIT -1352447 // powers, totactive, c
```
