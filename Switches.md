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
- var1 = 0=open, 1=close, 2=stop
- var1 = Last Command (open, close)

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
/      Triple = 10% Sunlight protection
/  BT3 Single = Toggle Open/Stop/Close
/      Double = Open
/      Hold = Close
/      Triple = 10% Sunlight protection
*/
```

```
Rule1
ON Button1#state=10 DO Publish tasmota/cmnd/tasmota_3381CE/Power 2 ENDON
ON Button1#state=11 DO Publish tasmota/cmnd/tasmota_3381CE/Dimmer 15 ENDON
ON Button1#state=3 DO Publish tasmota/cmnd/tasmota_3381CE/Dimmer 100 ENDON
ON Button1#state=13 DO Publish muh/cmnd PLUGUD ENDON
ON mqtt#connected DO Subscribe HzOn, tasmota/tele/tasmota_F982EC/STATE, POWER ENDON
ON Event#HzOn=ON DO LedPower1 1 ENDON
ON Event#HzOn=OFF DO LedPower1 0 ENDON
ON Button1#state=13 DO Publish muh/cmnd PLUGUD ENDON
```

```
Rule2
ON mqtt#connected DO Subscribe Pos1, tasmota/status/tasmota_6B07DC/pos ENDON
ON Event#Pos1=0 DO var1 0 ENDON
ON Event#Pos1=100 DO var1 1 ENDON
ON Button2#state=10 DO event ROLLER1=%var1% ENDON
ON event#ROLLER1="" DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterOpen; var1 2; var2 1 ENDON
ON event#ROLLER1==0 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterOpen; var1 2; var2 1 ENDON
ON event#ROLLER1==1 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterClose; var1 2; var2 0 ENDON
ON event#ROLLER1==2 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterStop; var1 %var2% ENDON
ON Button2#state=11 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterOpen; var1 2; var2 1 ENDON
ON Button2#state=3 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterClose; var1 2; var2 0 ENDON
ON Button2#state=12 DO Backlog Publish tasmota/cmnd/tasmota_6B07DC/ShutterPosition 4; var1 2; var2 1 ENDON
```

- Shelly 2PM with ShellyOS

```
Rule2
ON mqtt#connected DO Subscribe Pos1, shellies/rollerk1/status/cover:0, current_pos ENDON
ON Event#Pos1=0 DO var1 0 ENDON
ON Event#Pos1=100 DO var1 1 ENDON
ON Button2#state=10 DO event ROLLER1=%var1% ENDON
ON event#ROLLER1="" DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Open","params": { "id":0 }}; var1 2; var2 1 ENDON
ON event#ROLLER1==0 DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Open","params": { "id":0 }}; var1 2; var2 1 ENDON
ON event#ROLLER1==1 DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Close","params": { "id":0 }}; var1 2; var2 0 ENDON
ON event#ROLLER1==2 DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Stop","params": { "id":0 }}; var1 %var2% ENDON
ON Button2#state=11 DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Open","params": { "id":0 }}; var1 2; var2 1 ENDON
ON Button2#state=3 DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Close","params": { "id":0 }}; var1 2; var2 0 ENDON
ON Button2#state=12 DO Backlog Publish shellies/rollerk1/rpc { "method":"Cover.Open","params": { "id":0, "pos":5 }}; var1 2; var2 1 ENDON
```

```
Rule3
ON mqtt#connected DO Subscribe Pos2, shellies/rollerk2/status/cover:0, current_pos ENDON
ON Event#Pos2=0 DO var3 0 ENDON
ON Event#Pos2=100 DO var3 1 ENDON
ON Button3#state=10 DO event ROLLER2=%var3% ENDON
ON event#ROLLER2="" DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Open","params": { "id":0 }}; var3 2; var4 1 ENDON
ON event#ROLLER2==0 DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Open","params": { "id":0 }}; var3 2; var4 1 ENDON
ON event#ROLLER2==1 DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Close","params": { "id":0 }}; var3 2; var4 0 ENDON
ON event#ROLLER2==2 DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Stop","params": { "id":0 }}; var3 %var4% ENDON
ON Button3#state=11 DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Open","params": { "id":0 }}; var3 2; var4 1 ENDON
ON Button3#state=3 DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Close","params": { "id":0 }}; var3 2; var4 0 ENDON
ON Button3#state=12 DO Backlog Publish shellies/rollerk2/rpc { "method":"Cover.Open","params": { "id":0, "pos":5 }}; var3 2; var4 1 ENDON
```

```
Rule3
ON mqtt#connected DO Subscribe Pos2, tasmota/status/tasmota_5FB259/pos ENDON
ON Event#Pos2=0 DO var3 0 ENDON
ON Event#Pos2=100 DO var3 1 ENDON
ON Button3#state=10 DO event ROLLER2=%var3% ENDON
ON event#ROLLER2="" DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterOpen; var3 2; var4 1 ENDON
ON event#ROLLER2==0 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterOpen; var3 2; var4 1 ENDON
ON event#ROLLER2==1 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterClose; var3 2; var4 0 ENDON
ON event#ROLLER2==2 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterStop; var3 %var4% ENDON
ON Button3#state=11 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterOpen; var3 2; var4 1 ENDON
ON Button3#state=3 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterClose; var3 2; var4 0 ENDON
ON Button3#state=12 DO Backlog Publish tasmota/cmnd/tasmota_5FB259/ShutterPosition 4; var3 2; var4 1 ENDON
```

### OLD

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

