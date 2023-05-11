# ShellyDimmer2
## Template
```
{"NAME":"Shelly Dimmer 2","GPIO":[0,3200,0,3232,5568,5600,0,0,193,0,192,0,320,4736],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog Ledtable 0; DimmerRange 45,100; ShdLeadingEdge 1; ShdLeadingEdge 0;
Backlog SwitchMode 11; SetOption32 10; Rule1 1;
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
