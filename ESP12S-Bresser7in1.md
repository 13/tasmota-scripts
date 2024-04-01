#### Compiling
- Latest known version 12.3.1
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
- https://tasmota.github.io/docs/TuyaMCU/#tuyasend-command
- SerialSend5 55aa000100000
```
{"NAME":"Bresser7in1","GPIO":[1,1,1,1,1,1,0,0,1,1,1,1,1,0],"FLAG":0,"BASE":54,"CMND":"TelePeriod 10 | SO97 1 | weblog 4"}

working
{"NAME":"Bresser","GPIO":[1,1,1,1,1,1,0,0,1,1,1,1,1,0],"FLAG":0,"BASE":54,"CMND":"SO97 1 | TuyaMCU 73,2 | TuyaMCU 71,102"}

Backlog TelePeriod 10; SO97 1; TuyaMcu 99,1


```

```
>D
temp=""
tin=0
hin=0
tout=0
hout=0
wind=0
windr=0
winddirname=""
luftd=0
regenrate=0
regenprotag=0
uv=0
licht=0
>E
tin=TuyaReceived#DpType2Id1/10
hin=TuyaReceived#DpType2Id2
hout=TuyaReceived#DpType2Id39
wind=TuyaReceived#DpType2Id56*36/100
windr=TuyaReceived#DpType2Id101
if windr>=0 {
winddirname="N"
}
if windr>=22 {
winddirname="NE"
}
if windr>=67 {
winddirname="E"
}
if windr>=112 {
winddirname="SE"
}
if windr>=157 {
winddirname="S"
}
if windr>=202 {
winddirname="SW"
}
if windr>=247 {
winddirname="W"
}
if windr>=292 {
winddirname="NW"
}
if windr>=337 {
winddirname="N"
}
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
if luftd>0 and hout>0 {
=>publish2 muh/wsr/json {"temp_in":%1tin%, "hum_in":%0hin%, "temp_out":%1tout%, "hum_out":%0hout%, "wind_speed:%1wind%, "wind_dir":%0windr%, "pressure":%1luftd%, "rain_rate":%1regenrate%, "rain_day":%1regenprotag%, "uv":%1uv%, "illuminance":%1licht%}
}
if luftd<1 and hout>0 {
=>publish2 muh/wsr/json {"temp_out":%1tout%, "hum_out":%0hout%, "wind_speed:%1wind%, "wind_dir":%0windr%, "rain_rate":%1regenrate%, "rain_day":%1regenprotag%, "uv":%1uv%, "illuminance":%1licht%}
}
>WS
Temp In{m} %1tin% °C
Hum In{m} %0hin% %%
Temp Out{m} %1tout% °C
Hum Out{m} %0hout% %%
Wind Speed{m} %1wind% km/h
Winddirection{m} %0winddirname% %0windr%°
Rain Day{m} %1regenprotag% l/d
Rain Rate{m} %1regenrate% l/h
Pressure{m} %1luftd% hPa
UV{m} %1uv%
Illuminance{m} %1licht% kLux
```
