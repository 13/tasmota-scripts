# Shelly Dimmer 2
## Template
```
{"NAME":"Shelly Dimmer 2","GPIO":[0,3200,0,3232,5568,5600,0,0,193,0,192,0,320,4736],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120;
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 1;

Backlog Ledtable 0; DimmerRange 45,100; ShdLeadingEdge 1; ShdLeadingEdge 0;
SwitchMode 11; SetOption32 10; Rule1 1;
```
## Rules
### Rule 1
```
Rule1 
  on system#boot do var1 + ENDON
  on switch1#state=2 do POWER TOGGLE ENDON
  on switch1#state=4 do DIMMER %var1% ENDON
  on switch1#state=7 do event upordown=%var1% ENDON
  on event#upordown=+ do var1 - ENDON
  on event#upordown=- do var1 + ENDON
```
### Rule 2
- timer to turn off after 3 hours
- winter sunrise emulator
```
Rule2
  ON Power1#state=1 DO RuleTimer1 10800 ENDON
  ON Power1#state=0 DO RuleTimer1 0 ENDON
  ON Rules#timer=1 DO Power1 0 ENDON
  ON Time#Minute=360 DO Backlog event smr=%timestamp% ENDON
  ON event#smr$|-11- DO Power1 1 ENDON
  ON event#smr$|-12- DO Power1 1 ENDON
  ON event#smr$|-01- DO Power1 1 ENDON
  ON event#smr$|-02- DO Power1 1 ENDON
  ON event#smr$|-03- DO Power1 1 ENDON
  ON Time#Minute=480 DO Power1 0 ENDON
```
