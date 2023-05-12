# Shelly Dimmer 2
## Template
```
{"NAME":"Shelly Dimmer 2","GPIO":[0,3200,0,3232,5568,5600,0,0,193,0,192,0,320,4736],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 2;

Backlog Ledtable 0; DimmerRange 45,100; ShdLeadingEdge 1; ShdLeadingEdge 0;
SwitchMode 11; SetOption32 10; Rule1 1;
```
## Rules
```
Rule1 
  on system#boot do var1 + ENDON
  on switch1#state=2 do POWER TOGGLE ENDON
  on switch1#state=4 do DIMMER %var1% ENDON
  on switch1#state=7 do event upordown=%var1% ENDON
  on event#upordown=+ do var1 - ENDON
  on event#upordown=- do var1 + ENDON
```
- timer to turn off after 3 hours
```
Rule2
  ON Power1#state=1 DO RuleTimer1 10800 ENDON
  ON Power1#state=0 DO RuleTimer1 0 ENDON
  ON Rules#timer=1 DO Power1 0 ENDON
  
```

## TODO
- add sunrise emulation for winter 