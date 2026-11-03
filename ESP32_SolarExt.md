# ESP32

## Template

```

```

## Table

|  NO | NAME | MODULE | GPIO | PIN | +   | -   | DESC |
| --: | :--- | :----- | ---: | :-- | --- | --- | ---- |

## Settings

```

```

## Rules

- Send Temperature to MQTT

  The trigger must be the sensor's JSON key, `DS18B20-C645FF` (the build
  names DS18x20 sensors by ID), not `DS18B20` — with the bare name the rule
  never fires (silently broken until 2026-11-03). Active on the device: the
  second variant (±2 °C band via Var1/Var2).

```
Rule1
ON DS18B20-C645FF#Temperature!=%Var1% DO Backlog var1 %value%; Publish2 muh/sensors/%deviceid%/json {"TID":"%deviceid%", "DS18B20":{"Id":"041731C645FF", "Temperature":%value%}, "Time":"%timestamp%"} ENDON

```

```
Rule1
ON DS18B20-C645FF#Temperature>%var1% DO Backlog var1 %value%; Publish2 muh/sensors/%deviceid%/json {"TID":"%deviceid%", "DS18B20":{"Id":"041731C645FF", "Temperature":%value%}, "Time":"%timestamp%"}; var2 %value%; add1 2; sub2 2 ENDON
ON DS18B20-C645FF#Temperature<%var2% DO Backlog var2 %value%; Publish2 muh/sensors/%deviceid%/json {"TID":"%deviceid%", "DS18B20":{"Id":"041731C645FF", "Temperature":%value%}, "Time":"%timestamp%"}; var1 %value%; add1 2; sub2 2 ENDON
```

```
Rule1
ON mqtt#connected DO Subscribe SolarTemp, muh/sensors/DDD99C/json, DS18B20.Temperature ENDON
ON Event#SolarTemp<=40 DO TempMeasuredSet %value% ENDON
```
