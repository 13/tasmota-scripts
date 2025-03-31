# Shelly 3EM

## Settings

```
Backlog Template {"NAME":"Shelly 3EM","GPIO":[1,1,288,1,32,8065,0,0,640,8064,608,224,8096,0],"FLAG":0,"BASE":18}; Module 0; restart 1;

Backlog IPAddress1 192.168.22.60; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName 3EM; FriendlyName1 3EM;
SetOption162 1; PowerOnState 1; TelePeriod 10;
PowerDelta 101;
PowerDelta 5;
Restart 1;

```

## Rules

```

Rule2
  ON Time#Minute|5 DO Ping4 192.168.22.1 ENDON
  ON Ping#192.168.22.1#Reachable=false DO Restart 1 ENDON

Rule3
  ON file#calib.dat DO {"state":0,"rms":{"current_a":3211982,"current_b":3189648,"current_c":3199282,"current_n":-1399975513,"current_s":266717838,"voltage_a":-731348,"voltage_b":-719234,"voltage_c":-732765},"angles":{"angle0":184,"angle1":172,"angle2":192},"powers":{"totactive":{"a":-1345486,"b":-1347556,"c":-1352447},"apparent":{"a":214497,"b":214494,"c":214496}},"energies":{"totactive":{"a":8731,"b":8730,"c":8730},"apparent":{"a":40353,"b":40352,"c":40361}}} ENDON
```

### calib.dat

```
{
  "state": 0,
  "rms": {
    "current_a": 3211982,
    "current_b": 3189648,
    "current_c": 3199282,
    "current_n": -1399975513,
    "current_s": 266717838,
    "voltage_a": -731348,
    "voltage_b": -719234,
    "voltage_c": -732765
  },
  "angles": {
    "angle0": 184,
    "angle1": 172,
    "angle2": 192
  },
  "powers": {
    "totactive": {
      "a": -1345486,
      "b": -1347556,
      "c": -1352447
    },
    "apparent": {
      "a": 214497,
      "b": 214494,
      "c": 214496
    }
  },
  "energies": {
    "totactive": {
      "a": 8731,
      "b": 8730,
      "c": 8730
    },
    "apparent": {
      "a": 40353,
      "b": 40352,
      "c": 40361
    }
  }
}
```

### Compiling tasmota-4M

```
#define USE_I2C
#define USE_ENERGY_SENSOR
#define USE_ADE7880
#define ADE7880_AIGAIN_INIT 3211982 // rms, current_a
#define ADE7880_BIGAIN_INIT 3189648 // rms, current_b
#define ADE7880_CIGAIN_INIT 3199282 // rms, current_c
#define ADE7880_NIGAIN_INIT 266717838 // rms, current_s !!
#define ADE7880_AVGAIN_INIT -731348 // rms, voltage_a
#define ADE7880_BVGAIN_INIT -719234 // rms, voltage_b
#define ADE7880_CVGAIN_INIT -732765 // rms, voltage_c
#define ADE7880_APHCAL_INIT 184 // angles, angle0
#define ADE7880_BPHCAL_INIT 172 // angles, angle1
#define ADE7880_CPHCAL_INIT 192 // angles, angle2
#define ADE7880_APGAIN_INIT -1345486 // powers, totactive, a
#define ADE7880_BPGAIN_INIT -1347556 // powers, totactive, b
#define ADE7880_CPGAIN_INIT -1352447 // powers, totactive, c
```
