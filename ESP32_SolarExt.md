```
Rule1
ON DS18B20#Temperature!=%Var1% DO Backlog var1 %value%; publish muh/sensors/%deviceid%/json {"Time":"%timestamp%", "Id":"041731C645FF", "Temperature":%value%} ENDON 
```
