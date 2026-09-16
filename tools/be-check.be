# be-check.be — offline syntax/global check for the MUH Berry scripts.
# Run with the standalone berry interpreter from the repo root:
#   berry tools/be-check.be
#
# The standalone compiler resolves globals at compile time, so we seed the
# globals that exist on a real device before each script is compiled:
# Tasmota built-ins, autoexec.be, muh_lib.be and gdhd.be. Anything else an
# undeclared name refers to is a genuine bug (e.g. lowercase `devicename`).
# `import strict` (below) makes that same compile() pass reject any other
# implicit-global typo. After compiling, a second pass statically lints every
# add_cron()/init_wifi_watchdog() spec literal for the 6-field Tasmota cron
# format (a wrong count silently never fires on the device).
import os
import strict

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
var WATCHDOG_ARM_MS, init_wifi_watchdog
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

# Static cron-spec lint: Tasmota crons are 6 whitespace-separated fields
# (sec min hour dom month dow); a wrong count compiles fine but silently
# never fires on the device. Scan every MUH/*.be source's text for
# add_cron("...") and init_wifi_watchdog(_, "...") spec literals (the first
# quoted argument for add_cron, the second for init_wifi_watchdog) and check
# the field count.
import string as s2

# Returns the nth (1-based) call argument on `line`, starting right after
# `marker` (which must end in the call's opening paren), but only if every
# argument up to and including the nth is itself a quoted string literal in
# sequence — a non-literal argument (e.g. a variable like `cron_spec`) makes
# this return nil rather than mistake a later, unrelated quoted string
# further down the line for the one we want.
def nth_call_string_arg(line, marker, n)
  var i = s2.find(line, marker)
  if i < 0 return nil end
  i += size(marker)
  var arg = 1
  while true
    while i < size(line) && line[i] == " " i += 1 end
    if i >= size(line) || line[i] != '"' return nil end
    var j = s2.find(line, '"', i + 1)
    if j < 0 return nil end
    var value = line[i + 1 .. j - 1]
    if arg == n return value end
    i = j + 1
    while i < size(line) && line[i] == " " i += 1 end
    if i >= size(line) || line[i] != "," return nil end
    i += 1
    arg += 1
  end
end

def cron_spec_field_count(spec)
  var n = 0
  for tok : s2.split(spec, " ")
    if tok != "" n += 1 end
  end
  return n
end

for f : os.listdir("MUH")
  if s2.split(f, -3)[1] == ".be"
    var path = "MUH/" + f
    var fh = open(path)
    var text = fh.read()
    fh.close()
    var lineno = 0
    for line : s2.split(text, "\n")
      lineno += 1
      var spec = nil
      if s2.find(line, "add_cron(") >= 0
        spec = nth_call_string_arg(line, "add_cron(", 1)
      elif s2.find(line, "init_wifi_watchdog(") >= 0
        spec = nth_call_string_arg(line, "init_wifi_watchdog(", 2)
      end
      if spec != nil
        var n = cron_spec_field_count(spec)
        if n != 6
          print(f"FAIL {path}:{lineno}: cron spec \"{spec}\" has {n} fields, need 6")
          failed += 1
        end
      end
    end
  end
end

print(f"{checked - failed}/{checked} scripts OK")
if failed > 0
  raise "be_check_failed"
end
