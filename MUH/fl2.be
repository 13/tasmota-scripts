#-
FL2

Backlog
Template {"NAME":"Shelly Plus 1PM","GPIO":[0,0,0,0,192,2720,0,0,0,0,0,0,0,0,2656,0,0,0,0,2624,0,32,224,0,0,0,0,0,0,0,0,0,0,0,0,0],"FLAG":0,"BASE":1};
Module 0; restart 1;

Backlog IPAddress1 192.168.22.70; IPAddress2 192.168.22.6; IPAddress3 255.255.255.0; IPAddress4 192.168.22.6; IPAddress5 192.168.22.1;

DeviceName FL2; FriendlyName1 FL2;
PulseTime1 600; SwitchMode 0;
Restart 1;
-#

# Uses muh_lib.be (loaded by autoexec.be)

var DEVICE_NAME = "FL2"

# muh_lib config (currently only used if is_dark()/set_power() get wired up)
DARK_OFFSET = -90
DARK_OFFSET_SUNSET = -90
POWER_TIMER_DURATION = 20

init_power_publish(0, DEVICE_NAME)
init_sun()

log(f"Loaded {DEVICE_NAME} ...")
