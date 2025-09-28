#-
Backlog Template {"NAME":"Shelly Mini1PMG3","GPIO":[576,32,0,4736,0,224,3200,8161,0,0,192,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; Restart 1;

Backlog IPAddress1 192.168.22.72; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName HZ_DGB; FriendlyName1 HZ_DGB_BTN;
PowerOnState 0; SetOption0 0;
SwitchMode1 5; SwitchTopic 0; SetOption1 1; SetOption32 30;
SetOption73 1; ButtonTopic 0;

TelePeriod 60;
Restart 1;

Rule1
  ON mqtt#connected DO Subscribe HzOn, tasmota/tele/tasmota_BDC5E0/SENSOR, Switch1 ENDON
  ON Event#HzOn=true DO LedPower1 1 ENDON
  ON Event#HzOn=false DO LedPower1 0 ENDON
  ON Button1#state=10 DO Publish tasmota/cmnd/tasmota_BDC5E0/POWER 2 ENDON

-#
