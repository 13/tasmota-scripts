#-
Backlog Template {"NAME":"Shelly Mini1PMG3","GPIO":[576,32,0,4736,0,224,3200,8161,0,0,192,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}; Module 0; Restart 1;

Backlog IPAddress1 192.168.22.72; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;
DeviceName HZ_DGB; FriendlyName1 HZ_DGB_BTN;
PowerOnState 0; SetOption0 0;

SwitchMode 5; SwitchTopic 0; SetOption114 1;
SetOption1 1; SetOption32 30;
ButtonTopic 0; SetOption73 1;

TelePeriod 60;
Restart 1;

Rule1
  ON System#Boot DO var1 0 ENDON
  ON mqtt#connected DO Subscribe HzOn, tasmota/tele/tasmota_BDC5E0/STATE, POWER ENDON
  ON Event#HzOn=ON DO IF (%var1%==0) Power1 1; var1 1 ENDIF ENDON
  ON Event#HzOn=OFF DO IF (%var1%==1) Power1 0; var1 0 ENDIF ENDON
  ON Button1#state=10 DO Backlog Publish tasmota/cmnd/tasmota_BDC5E0/POWER 2; Power1 2 ENDON

-#
