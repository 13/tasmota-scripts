# Plugs

1. [Shelly Plug S](##shelly-plug-s)

   - [ebike](#ebike)
   - [mop](#mop)
   - [desklight](#desklight)

2. [Athom Plug V2](#athom-plug-v2)

   - [HZ_BRENNER](#hz_brenner)
   - [GartenPlug](#gartenplug)

## Shelly Plug S

- Upgrade first Tasmota-Minimal/Lite then Tasmota

### ebike

```
Backlog
Template {"NAME":"Shelly Plug S","GPIO":[320,1,576,1,1,2720,0,0,2624,32,2656,224,1,4736],"FLAG":0,"BASE":45};
Module 0; Restart 1;

Backlog
IPAddress1 192.168.22.56; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName ebike; FriendlyName1 ebike;
PowerDelta 5; PowerOnState 1; TelePeriod 10;
Restart 1;

Backlog
Timer1 {"Enable":1,"Mode":0,"Time":"08:15","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":1};
Timer2 {"Enable":1,"Mode":0,"Time":"22:30","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer3 {"Enable":1,"Mode":0,"Time":"23:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer4 {"Enable":1,"Mode":0,"Time":"00:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer5 {"Enable":1,"Mode":0,"Time":"01:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timers 1;
Restart 1;

Rule1
  ON System#Boot DO Backlog var1 15; var2 0; ENDON
  ON Energy#Power DO var2 %value% ENDON
  ON Clock#Timer=2 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON
  ON Clock#Timer=3 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON
  ON Clock#Timer=4 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON
  ON Clock#Timer=5 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON

Backlog Rule1 1;
Restart 1;

Backlog PowerSet 14.0; VoltageSet 230; CurrentSet 60.87
```

### mop

```
Backlog
Template {"NAME":"Shelly Plug S","GPIO":[320,1,576,1,1,2720,0,0,2624,32,2656,224,1,4736],"FLAG":0,"BASE":45};
Module 0; Restart 1;

Backlog
IPAddress1 192.168.22.56; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName mop; FriendlyName1 mop;
PowerDelta 5; PowerOnState 0;
Restart 1;

Backlog
Timer1 {"Enable":1,"Mode":0,"Time":"09:00","Window":0,"Days":"0100010","Repeat":1,"Output":1,"Action":1};
Timer2 {"Enable":1,"Mode":0,"Time":"14:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":0};
Timers 1;
Restart 1;
```

### desklight

## Rules

- on boot check last state
- every minute check if sunset nautical on
- sunrise off
- change sunrise/sunset +-Minutes
- Under 10 Lux turn on Light

```
Backlog
Template {"NAME":"Shelly Plug S","GPIO":[320,1,576,1,1,2720,0,0,2624,32,2656,224,1,4736],"FLAG":0,"BASE":45};
Module 0; Restart 1;

Backlog
IPAddress1 192.168.22.56; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName desklight; FriendlyName1 desklight;
PowerDelta 5; PowerOnState 1;
Restart 1;

Backlog
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

## < 5 || < 12 || < 10
Rule2
ON mqtt#connected DO Subscribe LightLux, muh/WStation/data/B327, light_klx ENDON
ON Event#LightLux<10 DO Power 1 ENDON
ON Event#LightLux>10 DO Power 0 ENDON

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

## Athom Plug V2

### HZ_BRENNER

```
Backlog
Template {"NAME":"Athom Plug V2","GPIO":[0,0,0,3104,0,32,0,0,224,576,0,0,0,0],"FLAG":0,"BASE":18};
Module 0; Restart 1;

Backlog
IPAddress1 192.168.22.73; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName HZ_BRENNER; FriendlyName1 HZ_BRENNER;
PowerDelta 5; PowerOnState 1;
Restart 1;
```

#### Rule 1

- Wintermode (Months 01,02,03,11,12)
- Turn ON from 05:30 - 21:30

```
Backlog
Timers 1;
Timer1 {"Enable":1,"Mode":0,"Time":"05:30","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer2 {"Enable":1,"Mode":0,"Time":"21:30","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":0};
Restart 1;

Rule1
  ON Clock#Timer=1 DO Backlog Event wintermode=%timestamp% ENDON
  ON Event#wintermode$|-01- DO Power 1 ENDON
  ON Event#wintermode$|-02- DO Power 1 ENDON
  ON Event#wintermode$|-03- DO Power 1 ENDON
  ON Event#wintermode$|-11- DO Power 1 ENDON
  ON Event#wintermode$|-12- DO Power 1 ENDON

Rule1 1
```

### GartenPlug

```
Backlog
Template {"NAME":"Athom Plug V2","GPIO":[0,0,0,3104,0,32,0,0,224,576,0,0,0,0],"FLAG":0,"BASE":18};
Module 0; Restart 1;

Backlog
IPAddress1 192.168.22.73; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName GartenPlug; FriendlyName1 GartenPlug;
PowerDelta 5; PowerOnState 0;
Restart 1;

Backlog
Timer1 {"Enable":1,"Mode":0,"Time":"18:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer2 {"Enable":1,"Mode":0,"Time":"22:30","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":0};
Timers 1;
Restart 1;

Rule1
  ON Clock#Timer=1 DO Backlog Event wintermode=%timestamp% ENDON
  ON Event#wintermode$|-01- DO Power 0 ENDON
  ON Event#wintermode$|-02- DO Power 0 ENDON
  ON Event#wintermode$|-03- DO Power 0 ENDON
  ON Event#wintermode$|-04- DO Power 0 ENDON
  ON Event#wintermode$|-10- DO Power 0 ENDON
  ON Event#wintermode$|-11- DO Power 0 ENDON
  ON Event#wintermode$|-12- DO Power 0 ENDON

Backlog Rule1 1;
Restart 1;
```
