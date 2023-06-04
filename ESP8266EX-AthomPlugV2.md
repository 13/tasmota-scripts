# ESP8266EX Athom Plug V2
- Upgrade first Tasmota-Minimal/Lite then Tasmota
## Template
```
{"NAME":"Athom Plug V2","GPIO":[0,0,0,3104,0,32,0,0,224,576,0,0,0,0],"FLAG":0,"BASE":18}
```
## Settings
```
Backlog DeviceName HZ_BRENNER; FriendlyName1 HZ_BRENNER; 
Backlog PowerOnState 0
```
## Rules
### Rule 1
- At boot turn ON if Warmwater under 45
```
Rule1

```
