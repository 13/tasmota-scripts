# Switches

## Template
```
{"NAME":"Athom SW013EU","GPIO":[576,322,0,33,225,34,0,0,32,224,321,226,320,0],"FLAG":0,"BASE":18}
```

## Settings
```
Backlog DeviceName KMMR_SW1; FriendlyName1 KMMR_SW1;
Backlog DeviceName KMMR_SW2; FriendlyName1 KMMR_SW2; 
Backlog ButtonTopic 0; SetOption73 1; SetOption32 20;
```

## Rules
- Position (0-100%) 100 open
- Mem1 = 0=open, 1=close, 2=stop
- Mem1 = Last Command (open, close)

```
/*
/  Tasmota DS-102 3 Gang Switch Rules
/  ---
/  KommerDoorSwitch
/  ---
/  BT1 Single = Toggle Nachtlicht
/      Double = 15% Nachtlicht
/      Hold = 100% Nachtlicht
/      Quad = Toggle Heizung
/  BT2 Single = Toggle Open/Stop/Close
/      Double = Open
/      Hold = Close
/  BT3 Single = Toggle Open/Stop/Close
/      Double = Open
/      Hold = Close
*/
```

```
Rule1
ON Button1#state=10 DO Publish tasmota/cmnd/tasmota_3381CE/Power 2 ENDON
ON Button1#state=11 DO Publish tasmota/cmnd/tasmota_3381CE/Dimmer 15 ENDON
ON Button1#state=3 DO Publish tasmota/cmnd/tasmota_3381CE/Dimmer 100 ENDON
ON mqtt#connected DO Subscribe HzOn, shellies/HZ_DG/status/switch:0, output ENDON
ON Event#HzOn=true DO LedPower1 1 ENDON
ON Event#HzOn=false DO LedPower1 0 ENDON
ON Button1#state=13 DO Publish shellies/HZ_DG/rpc { "method":"Switch.Toggle","params": { "id":0 }} ENDON
```

```
Rule2
ON mqtt#connected DO Subscribe Pos1, tasmota/status/tasmota_6B07DC/pos ENDON
ON Event#Pos1=0 DO mem1 0 ENDON
ON Event#Pos1=100 DO mem1 1 ENDON
ON Button2#state=10 DO event ROLLER1=%mem1% ENDON
ON event#ROLLER1="" DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterOpen; mem1 2; mem2 1 ENDON
ON event#ROLLER1==0 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterOpen; mem1 2; mem2 1 ENDON
ON event#ROLLER1==1 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterClose; mem1 2; mem2 0 ENDON
ON event#ROLLER1==2 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterStop; mem1 %mem2% ENDON
ON Button2#state=11 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterOpen; mem1 2; mem2 1 ENDON
ON Button2#state=3 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterClose; mem1 2; mem2 0 ENDON
```

```
Rule3
ON mqtt#connected DO Subscribe Pos2, tasmota/status/tasmota_5FB259/pos ENDON
ON Event#Pos2=0 DO mem3 0 ENDON
ON Event#Pos2=100 DO mem3 1 ENDON
ON Button3#state=10 DO event ROLLER2=%mem3% ENDON
ON event#ROLLER2="" DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterOpen; mem3 2; mem4 1 ENDON
ON event#ROLLER2==0 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterOpen; mem3 2; mem4 1 ENDON
ON event#ROLLER2==1 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterClose; mem3 2; mem4 0 ENDON
ON event#ROLLER2==2 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterStop; mem3 %mem4% ENDON
ON Button3#state=11 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterOpen; mem3 2; mem4 1 ENDON
ON Button3#state=3 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterClose; mem3 2; mem4 0 ENDON
```
