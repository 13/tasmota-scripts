# ESP32

## Template

```

```

## Table

| NO | NAME | MODULE | GPIO | PIN | + | - | DESC |
|--:|:--|:--|--:|:--|---|---|---|

## Settings

```
```

## Rules
- Send Temperature to MQTT
```
Rule1
ON DS18B20#Temperature!=%Var1% DO Backlog var1 %value%; Publish2 muh/sensors/%deviceid%/json {"TID":"%deviceid%", "DS18B20":{"Id":"041731C645FF", "Temperature":%value%}, "Time":"%timestamp%"} ENDON 
```

```
Rule1
ON mqtt#connected DO Subscribe SolarTemp, muh/sensors/DDD99C/json, DS18B20.Temperature ENDON
ON Event#SolarTemp<=40 DO TempMeasuredSet %value% ENDON
```
