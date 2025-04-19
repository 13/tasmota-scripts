# Shelly Dimmer 2

## Settings

```
Backlog
Template {"NAME":"Shelly Dimmer 2","GPIO":[0,3200,0,3232,5568,5600,0,0,193,0,192,0,320,4736],"FLAG":0,"BASE":18};
Module 0; Restart 1;

Backlog
IPAddress1 192.168.22.56; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;

Backlog
DeviceName Dimmer2B; FriendlyName1 Dimmer2B;
PowerDelta 5; 
Restart 1;

Backlog Ledtable 0; DimmerRange 21,34; ShdLeadingEdge 0;
SwitchMode 11; SetOption32 5; DimmerStep 2;
PulseTime 3600;
Rule1 1;
Emulation 2;
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

