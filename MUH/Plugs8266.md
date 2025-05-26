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
Timer1 {"Enable":1,"Mode":0,"Time":"08:15","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer2 {"Enable":1,"Mode":0,"Time":"09:15","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer3 {"Enable":1,"Mode":0,"Time":"10:15","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer4 {"Enable":1,"Mode":0,"Time":"11:15","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer5 {"Enable":1,"Mode":0,"Time":"22:30","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer6 {"Enable":1,"Mode":0,"Time":"23:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer7 {"Enable":1,"Mode":0,"Time":"00:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timer8 {"Enable":1,"Mode":0,"Time":"01:00","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":3};
Timers 1;
Restart 1;

Rule1
  ON System#Boot DO Backlog var1 15; var2 0; var3 0; ENDON
  ON Energy#Power DO var2 %value% ENDON
  ON Clock#Timer=5 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON
  ON Clock#Timer=6 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON
  ON Clock#Timer=7 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON
  ON Clock#Timer=8 DO IF (%var2% < %var1%) Power 0 ENDIF ENDON

Rule2
  ON mqtt#connected DO Subscribe PowerTotal, tasmota/tele/tasmota_5FF8B2/SENSOR ENDON
  ON Event#PowerTotal#ENERGY#Power[1] DO IF (%value%<0) var3 1 ELSE var3 0 ENDIF ENDON
  ON Clock#Timer=1 DO IF (%var3%==1) Power 1 ENDIF ENDON
  ON Clock#Timer=2 DO IF (%var3%==1) Power 1 ENDIF ENDON
  ON Clock#Timer=3 DO IF (%var3%==1) Power 1 ENDIF ENDON
  ON Clock#Timer=4 DO IF (%var3%==1) Power 1 ENDIF ENDON

#Rule3
#  ON mqtt#connected DO Subscribe GartenPlug, tasmota/tele/tasmota_8F499A/LWT ENDON
#  ON Event#GartenPlug=Online DO Power 1 ENDON

Backlog Rule1 1; Rule2 1;
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
Timer1 {"Enable":1,"Mode":0,"Time":"09:00","Window":0,"Days":"0100010","Repeat":1,"Output":1,"Action":3};
Timer2 {"Enable":1,"Mode":0,"Time":"10:00","Window":0,"Days":"0100010","Repeat":1,"Output":1,"Action":3};
Timer3 {"Enable":1,"Mode":0,"Time":"11:00","Window":0,"Days":"0100010","Repeat":1,"Output":1,"Action":3};
Timer4 {"Enable":1,"Mode":0,"Time":"09:00","Window":0,"Days":"0100010","Repeat":1,"Output":1,"Action":1};
Timer5 {"Enable":1,"Mode":0,"Time":"16:30","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":0};
Timers 1;
Restart 1;

Rule2
  ON System#Boot DO Backlog var3 0; ENDON
  ON mqtt#connected DO Subscribe PowerTotal, tasmota/tele/tasmota_5FF8B2/SENSOR ENDON
  ON Event#PowerTotal#ENERGY#Power[1] DO IF (%value%<0) var3 1 ELSE var3 0 ENDIF ENDON
  ON Clock#Timer=1 DO IF (%var3%==1) Power 1 ENDIF ENDON
  ON Clock#Timer=2 DO IF (%var3%==1) Power 1 ENDIF ENDON
  ON Clock#Timer=3 DO IF (%var3%==1) Power 1 ENDIF ENDON
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

Rule1
  ON mqtt#connected DO Subscribe LightLux, muh/wst/data/B327, light_klx ENDON
  ON Event#LightLux<10 DO var1 1 ENDON
  ON Event#LightLux>10 DO var1 0 ENDON
  ON var1#state!=%var2% DO Backlog var2 %value%; Power %value% ENDON

Rule1 1
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
IPAddress1 192.168.22.30; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
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

Rule3
  ON button1#state=1 DO Publish tasmota/cmnd/tasmota_0C6423/power 1 ENDON

#  ON button1#state=1 DO Publish muh/plugs/garten/power 1 ENDON

Backlog Rule1 1;
Restart 1;
```
