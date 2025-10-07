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

Backlog Ledtable 0; ShdLeadingEdge 0;
DimmerRange 21,48;  // E27
DimmerRange 40,120; // GU14
SwitchMode 11; SetOption32 5; DimmerStep 2;
PulseTime 3600;
Rule1 1;
Fade 1;
Emulation 2;
```

## Rules

### Rule 1

```
RULE1
ON System#boot DO var1 > ENDON 
ON Switch1#state=2 DO POWER TOGGLE ENDON 
ON Switch1#state=4 DO BACKLOG0 SPEED2 4; DIMMER %var1% ENDON 
ON Switch1#state=7 DO BACKLOG0 DIMMER !; EVENT upordown=%var1%; SPEED2 ! ENDON 
ON Event#upordown$<> DO var1 < ENDON 
ON Event#upordown$<< DO var1 > ENDON

Rule1
ON System#Boot DO var1 + ENDON
ON Switch1#state=2 DO POWER TOGGLE ENDON
ON Switch1#state=4 DO DIMMER %var1% ENDON
ON Switch1#state=7 DO Event upordown=%var1% ENDON
ON Event#upordown=+ DO var1 - ENDON
ON Event#upordown=- DO var1 + ENDON
```

