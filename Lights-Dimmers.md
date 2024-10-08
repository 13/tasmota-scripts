# Shelly Dimmer 2
## Template
```
{"NAME":"Shelly Dimmer 2","GPIO":[0,3200,0,3232,5568,5600,0,0,193,0,192,0,320,4736],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog Sunrise 1;

Backlog Ledtable 0; DimmerRange 45,100; ShdLeadingEdge 1; ShdLeadingEdge 0;
SwitchMode 11; SetOption32 10; Rule1 1
PulseTime 5400
A PulseTime 3600
```
## Rules
### Rule 1
```
Rule1 
ON system#boot DO var1 + ENDON
ON switch1#state=2 DO POWER TOGGLE ENDON
ON switch1#state=4 DO DIMMER %var1% ENDON
ON switch1#state=7 DO event upordown=%var1% ENDON
ON event#upordown=+ DO var1 - ENDON
ON event#upordown=- DO var1 + ENDON
```
### Rule 2
- timer to turn off after 1.5 hours
- Winter sunrise (ON at Mo-Fr 06:00 and Sa-So 06:35)

#### Timer
```
Timer1 {"Enable":1,"Mode":0,"Time":"06:00","Window":0,"Days":"0111110","Repeat":1,"Output":1,"Action":3}
Timer2 {"Enable":2,"Mode":0,"Time":"06:35","Window":0,"Days":"1000001","Repeat":1,"Output":1,"Action":3}
```
```
Rule2
ON Clock#Timer=1 DO Backlog Dimmer 10; Power1 1 ENDON
ON Clock#Timer=2 DO Backlog Dimmer 10; Power1 1 ENDON

ON Time#Minute=360 DO Backlog Timers 0; event smr=%timestamp% ENDON
ON event#smr$|-11- DO Backlog Timers 1 ENDON
ON event#smr$|-12- DO Backlog Timers 1 ENDON
ON event#smr$|-01- DO Backlog Timers 1 ENDON
ON event#smr$|-02- DO Backlog Timers 1 ENDON
ON event#smr$|-03- DO Backlog Timers 1 ENDON

--- old
ON Power1#state=1 DO RuleTimer1 5400 ENDON
ON Power1#state=0 DO RuleTimer1 0 ENDON
ON Rules#timer=1 DO Power1 0 ENDON
```
