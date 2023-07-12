#### Compiling
```
/* Only Tuya (Bresser)*/
#ifndef USE_SCRIPT
#define USE_SCRIPT  // adds about 17k flash size, variable ram size
#endif
#ifdef USE_RULES
#undef USE_RULES
#endif
#define USE_SCRIPT_WEB_DISPLAY
```
### Settings
- disable switch on 1
- set 115200 bps
```
Backlog TuyaMcu 99,1; setoption97 1; weblog 4
```
{"NAME":"Bresser","GPIO":[1,1,1,1,1,1,0,0,1,1,1,1,1,0],"FLAG":0,"BASE":54,"CMND":"SO97 1 | TuyaMcu 99,1 | weblog 4"}
T: 38, 65, 67
H: 39
 Backlog TuyaMCU 73,39; TuyaMCU 71,67;

```
Backlog TuyaMCU 99,1; TuyaMCU 99,2; TuyaMCU 13,3; TuyaMCU 14,4; TuyaMCU 15,5; TuyaMCU 16,6; TuyaMCU 99,9; TuyaMCU 99,10; TuyaMCU 99,11; TuyaMCU 99,12; TuyaMCU 99,13; TuyaMCU 99,30; TuyaMCU 99,38; TuyaMCU 73,39; TuyaMCU 99,54; TuyaMCU 99,55; TuyaMCU 99,56; TuyaMCU 99,57; TuyaMCU 99,58; TuyaMCU 99,60; TuyaMCU 99,61; TuyaMCU 99,62; TuyaMCU 99,63; TuyaMCU 99,64; TuyaMCU 99,65; TuyaMCU 99,66; TuyaMCU 99,67; TuyaMCU 99,68; TuyaMCU 99,101; TuyaMCU 99,102; TuyaMCU 99,103;

>D
temp=""
tin=tin
hin=hin
tout=tout
hout=hout
wind=wind
windr=windr
luftd=luftd
regenrate=regenrate
regenprotag=regenprotag
uv=uv
licht=licht
>E
tin=TuyaReceived#DpType2Id1/10
hin=TuyaReceived#DpType2Id2
hout=TuyaReceived#DpType2Id39
wind=TuyaReceived#DpType2Id56/10
windr=TuyaReceived#DpType2Id101
luftd=TuyaReceived#DpType2Id54/10
temp=TuyaReceived#38#DpIdData
if ins(temp "FFFF")==-1 {
tout=hd(sb(temp 4 4))/10
}else{
tout=hd(sb(temp 4 4))-65536/10
}
regenrate=TuyaReceived#DpType2Id61/1000
regenprotag=TuyaReceived#DpType2Id60/1000
uv=TuyaReceived#DpType2Id62/10
licht=TuyaReceived#DpType2Id63/1000
>T
=>publish /Smarthome/%topic%/tele/SENSOR {"Temperatur innen":%1tin%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Freuchte innen":%0hin%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Temperatur aussen":%1tout%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Feuchte aussen":%0hout%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Wind m/s":%1wind%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Windrichtung":%0windr%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Luftdruck hPa":%1luftd%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Regenrate l/Std":%1regenrate%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Regen l/T":%1regenprotag%}
=>publish /Smarthome/%topic%/tele/SENSOR {"UV Pegel":%1uv%}
=>publish /Smarthome/%topic%/tele/SENSOR {"Lichtstaerke kLux":%3licht%}
>WS
Temperatur innen{m} %1tin% °C
Feuchte innen{m} %0hin% %%
Temperatur außen {m} %1tout% °C
Feuchte außen{m} %0hout% %%
Windstärke{m} %1wind% m/s
Windrichtung{m} %0windr%°
Luftdruck{m} %1luftd% hPa
Regen pro Std{m} %1regenrate% l/Std
Regen pro Tag{m} %1regenprotag% l/T
UV Pegel {m} %1uv%
Lichtstärke {m} %3licht% kLux
```
