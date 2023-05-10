```
Backlog Ledtable 0; DimmerRange 45,100; ShdLeadingEdge 1; ShdLeadingEdge 0;

Backlog SwitchMode 11; SetOption32 10; Rule1 1;

Rule1 
on system#boot do var1 + ENDON
on switch1#state=2 do POWER TOGGLE ENDON
on switch1#state=4 do DIMMER %var1% ENDON
on switch1#state=7 do event upordown=%var1% ENDON
on event#upordown=+ do var1 - ENDON
on event#upordown=- do var1 + ENDON
```
