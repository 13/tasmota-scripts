# be-check.be — offline syntax/global check for the MUH Berry scripts.
# Run with the standalone berry interpreter from the repo root:
#   berry tools/be-check.be
#
# The standalone compiler resolves globals at compile time, so we seed the
# globals that exist on a real device before each script is compiled:
# Tasmota built-ins, autoexec.be, muh_lib.be and gdhd.be. Anything else an
# undeclared name refers to is a genuine bug (e.g. lowercase `devicename`).
import os

# Tasmota firmware built-ins
var tasmota, mqtt, persist, load
# Modules imported at top level somewhere in the load chain
var string, json, math
# autoexec.be
var log, DEBUG, LOG_PREFIX, DEVICENAME, DEVICE_SCRIPTS, load_script
# muh_lib.be
var DARK_OFFSET, DARK_OFFSET_SUNSET, POWER_TIMER_DURATION, status_tim
var get_status_tim, is_dark, set_power, publish_power_state
var init_power_publish, init_sun, _last_power
# gdhd.be (used by hd.be / gd.be)
var volume, volume_default, powerCmd, handleSwitchP, publishSwitchP
var handleRemoteSwitchP, publishFPrint, checkDNS, chimePC

var failed = 0
var checked = 0
for f : os.listdir("MUH")
  import string as s
  if s.split(f, -3)[1] == ".be"
    checked += 1
    try
      compile(f"MUH/{f}", "file")
    except .. as e, m
      print(f"FAIL {f}: {e}: {m}")
      failed += 1
    end
  end
end

print(f"{checked - failed}/{checked} scripts OK")
if failed > 0
  raise "be_check_failed"
end
