#-
WC

Backlog
Template {"NAME":"Shelly Plus1PMMini","GPIO":[576,32,0,4736,0,224,3200,8161,0,0,192,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1};
Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;

DeviceName WC; FriendlyName1 WC;
PulseTime1 600; SwitchMode 1;
Restart 1;
-#

# Uses muh_lib.be (loaded by autoexec.be)

var DEVICE_NAME = "WC"

# muh_lib config (currently only used if is_dark()/set_power() get wired up)
DARK_OFFSET = -90
DARK_OFFSET_SUNSET = -90
POWER_TIMER_DURATION = 20

init_power_publish(0, DEVICE_NAME)
init_sun()

log(f"Loaded {DEVICE_NAME} ...")
