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
```
{"NAME":"Bresser7in1","GPIO":[1,1,1,1,1,1,0,0,1,1,1,1,1,0],"FLAG":0,"BASE":54,"CMND":"SO97 1 | TuyaMcu 99,1 | weblog 4"}
```
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
wind=TuyaReceived#DpType2Id56*36/100
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
=>publish2 /muh/wsr/json {"temp_in":%1tin%}
=>publish2 /muh/wsr/json {"hum_in":%0hin%}
=>publish2 /muh/wsr/json {"temp_out":%1tout%}
=>publish2 /muh/wsr/json {"hum_out":%0hout%}
=>publish2 /muh/wsr/json {"wind_speed:%1wind%}
=>publish2 /muh/wsr/json {"wind_dir":%0windr%}
=>publish2 /muh/wsr/json {"pressure":%1luftd%}
=>publish2 /muh/wsr/json {"rain_rate":%1regenrate%}
=>publish2 /muh/wsr/json {"rain_day":%1regenprotag%}
=>publish2 /muh/wsr/json {"uv":%1uv%}
=>publish2 /muh/wsr/json {"illuminance":%1licht%}
>WS
Temperature In{m} %1tin% °C
Humidity In{m} %0hin% %%
Temperature Out{m} %1tout% °C
Humidity Out{m} %0hout% %%
Windspeed{m} %1wind% km/h
Winddirection{m} %0windr% °
Pressure{m} %1luftd% hPa
Rainrate{m} %1regenrate% l/h
Rain{m} %1regenprotag% l/d
UV{m} %1uv%
Illuminance{m} %1licht% kLux
```
