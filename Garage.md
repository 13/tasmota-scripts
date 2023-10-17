# Garage

## Template
```
{"NAME":"Shelly Plus 1 ADDON","GPIO":[288,1,0,1,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
## Table
| GPIO | NAME |
|--:|:--|
| 1 | DATA |
| 3 | ANALOG IN |
| 19 | DIGITAL IN |

## Settings
```
Backlog DeviceName GARAGE; FriendlyName1 GARAGE; 
SetOption114 1; SwitchMode2 2;
SetOption73 1; SetOption1 1; ButtonTopic 0; LedPower 0; BlinkCount 0;
PulseTime1 6; 
```

### Rules
#### Rule 1
- Publish switch
- Event HTTP for relays
- Event MQTT for relays
```
Rule1
ON Switch2#Boot DO var2 %value% ENDON
ON System#Boot DO IF (%var2%!=%mem2%) mem2 %var2%; Publish2 muh/portal/G/json {"state": %var2%, "time": "%timestamp%"} ENDIF ENDON
ON Switch2#state!=%mem2% DO Backlog mem2 %value%; mem6 %timestamp%; Publish2 muh/portal/G/json {"state": %value%, "time": "%timestamp%"} ENDON
ON mqtt#connected DO Subscribe RLY, muh/portal/RLY/cmnd ENDON
ON Event#RLY=G_T DO Power1 1 ENDON
ON event#G_T=1 DO Power1 1 ENDON
ON Time#Minute|1 DO Publish2 muh/portal/G/json {"state": %mem2%, "time": "%mem6%"} ENDON
```
