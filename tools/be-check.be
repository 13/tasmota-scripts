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
var WATCHDOG_ARM_MS, _watchdog_armed, init_wifi_watchdog
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

# Static cron-spec lint: every add_cron("...") / init_wifi_watchdog(..., "...")
# literal must have 6 whitespace-separated fields (sec min hour dom month dow).
# A bad spec fails to parse on the device and the cron silently never fires.
# Count only; field contents are not validated. Scans the whole file text, so
# multi-line calls and single-quoted literals are covered.
def is_space(c) return c == " " || c == "\n" || c == "\t" || c == "\r" end

# nth string-literal argument of the call whose argument list starts at index
# `start` (just past the opening paren). Returns nil unless arguments 1..n are
# all string literals in sequence, so a variable argument like `cron_spec`
# yields nil rather than a later, unrelated literal.
def nth_call_string_arg(text, start, n)
  var i = start
  var arg = 1
  while true
    while i < size(text) && is_space(text[i]) i += 1 end
    if i >= size(text) return nil end
    var q = text[i]
    if q != '"' && q != "'" return nil end
    var j = s2.find(text, q, i + 1)
    if j < 0 return nil end
    var value = text[i + 1 .. j - 1]
    if arg == n return value end
    i = j + 1
    while i < size(text) && is_space(text[i]) i += 1 end
    if i >= size(text) || text[i] != "," return nil end
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

def line_of(text, idx)
  var n = 1
  var i = 0
  while i < idx
    if text[i] == "\n" n += 1 end
    i += 1
  end
  return n
end

var lint_failed = 0
for f : os.listdir("MUH")
  if s2.split(f, -3)[1] == ".be"
    var path = "MUH/" + f
    var fh = open(path)
    var text = fh.read()
    fh.close()
    for call : [["add_cron(", 1], ["init_wifi_watchdog(", 2]]
      var marker = call[0]
      var pos = s2.find(text, marker)
      while pos >= 0
        var spec = nth_call_string_arg(text, pos + size(marker), call[1])
        if spec != nil
          var n = cron_spec_field_count(spec)
          if n != 6
            print(f"FAIL {path}:{line_of(text, pos)}: cron spec \"{spec}\" has {n} fields, need 6")
            lint_failed += 1
          end
        end
        pos = s2.find(text, marker, pos + size(marker))
      end
    end
  end
end

print(f"{checked - failed}/{checked} scripts OK, {lint_failed} bad cron specs")
if failed > 0 || lint_failed > 0
  raise "be_check_failed"
end
