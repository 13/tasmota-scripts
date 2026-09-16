# tools/test_env.be — shared stubs for the offline Berry harnesses.
# Execute from a test with: compile("tools/test_env.be", "file")()
# Top-level var/def here become globals visible to the test and to the
# scripts it loads (same as Tasmota's load() semantics).
import sys
sys.path().push("tools/stubs")
import json
import string
import math

var published = []     # list of [topic, payload_map, retain]
var cmds = []           # tasmota.cmd() calls
var rules = {}          # trigger -> closure
var crons = {}          # id -> closure
var timers = []         # list of [delay_ms, closure, id]
var sensor_json = ""
var DEVICENAME = "HZ_WW"

class TasmotaStub
  def read_sensors() return sensor_json end
  def rtc() return {'utc': 0, 'local': 0, 'restart': 0} end
  def time_str(t) return "2026-01-01T00:00:00" end
  def cmd(c)
    cmds.push(c)
    if c == "DeviceName"
      return {"DeviceName": DEVICENAME}
    end
    return {}
  end
  def publish(topic, payload, retain)
    published.push([topic, json.load(payload), retain])
  end
  def add_rule(trigger, f) rules[trigger] = f end
  # Tasmota crons are 6 fields (sec min hour dom month dow); a wrong count
  # fails to parse on the device and the cron silently never fires.
  def add_cron(spec, f, id)
    if string.split(spec, " ").size() != 6
      raise "bad_cron_spec", f"'{spec}' must have 6 fields (id {id})"
    end
    crons[id] = f
  end
  def set_timer(ms, f, id) timers.push([ms, f, id]) end
  def remove_timer(id) end
end
var tasmota = TasmotaStub()
def mqtt_publish_hook(topic, payload, retain)
  published.push([topic, json.load(payload), retain])
end
var mqtt_is_connected = false
def mqtt_connected_hook()
  return mqtt_is_connected
end

var LOG_PREFIX = "MUH:"
var DEBUG = false
def log(m) if DEBUG print(m) end end

var failures = 0
def check(cond, name)
  if cond
    print(f"ok   {name}")
  else
    print(f"FAIL {name}")
    failures += 1
  end
end
def reset()
  published = [] cmds = [] timers = []
end
def load(filename)
  compile(filename, "file")()
end
def finish()
  print(f"{failures} failures")
  if failures > 0 raise "test_failed" end
end
