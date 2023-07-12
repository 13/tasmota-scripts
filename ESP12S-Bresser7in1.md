- disable switch on 1
- set 115200 bps
```
Backlog TuyaMcu 99,1; setoption97 1; weblog 4
```

T: 38, 65, 67
H: 39
 Backlog TuyaMCU 73,39; TuyaMCU 71,67;

```
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
Windrichtung{m} %0windr% ° -- 0°->Nord 90°->Ost...
Luftdruck{m} %1luftd% hPa
Regen pro Std{m} %1regenrate% l/Std
Regen pro Tag{m} %1regenprotag% l/T
UV Pegel {m} %1uv%
Lichtstärke {m} %3licht% kLux
```
