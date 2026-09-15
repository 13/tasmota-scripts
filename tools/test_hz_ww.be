# tools/test_hz_ww.be — offline behaviour test for MUH/hz_ww.be
# Run: berry tools/test_hz_ww.be
import json
import string
import math

# ---- stubs for Tasmota built-ins ----
var published = []     # list of [topic, payload_map, retain]
var cmds = []          # tasmota.cmd() calls
var rules = {}         # trigger -> closure
var crons = {}         # id -> closure
var timers = []        # list of [delay_ms, closure]
var sensor_json = ""
var millis_now = 0

class TasmotaStub
  def read_sensors() return sensor_json end
  def rtc() return {'local': 0} end
  def time_str(t) return "2026-01-01T00:00:00" end
  def millis() return millis_now end
  def cmd(c) cmds.push(c) return {} end
  def add_rule(trigger, f) rules[trigger] = f end
  def add_cron(spec, f, id) crons[id] = f end
  def set_timer(ms, f, id) timers.push([ms, f]) end
  def remove_timer(id) end
end
class MqttStub
  def publish(topic, payload, retain)
    published.push([topic, json.load(payload), retain])
  end
end
var tasmota = TasmotaStub()
var mqtt = MqttStub()
var DEVICENAME = "HZ_WW"
var LOG_PREFIX = "MUH:"
var DEBUG = false
def log(m) if DEBUG print(m) end end
def load(filename)
  compile(filename, "file")()
end

# Globals provided by MUH/hz_ww.be
var boot_publish, MIN_UPTIME_FOR_RESTART_MS

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
def sensors(a, b)
  sensor_json = json.dump({
    'Time': 'x',
    'ANALOG': {'Temperature1': 19.5},
    'DS18B20-3628FF': {'Id': '00042B3628FF', 'Temperature': a},
    'DS18B20-1C16E1': {'Id': '0621C01C16E1', 'Temperature': b},
  })
end

# ---- load script under test with one sensor stuck at 85 ----
sensors(85, 40.0)
load("MUH/hz_ww.be")

# boot: valid sensor published, 85 sensor not, no restart, retry timer armed
reset()
rules["system#boot"]()
check(published.size() == 1, "boot publishes only valid sensor")
check(published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "boot topic")
check(published[0][1]['ds18b20']['temperature'] == 40.0, "boot payload temperature")
check(published[0][1]['tid'] == "HZ_WW", "boot payload tid")
check(published[0][2] == true, "boot publish retained")
check(cmds.size() == 0, "boot with 85 never restarts")
check(timers.size() == 1, "boot with 85 arms one retry timer")

# retry re-reads sensors fresh: now valid -> published
reset()
sensors(53.1, 40.0)
timers = []
boot_publish(1)
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-3628FF/json", "retry publishes recovered sensor")
check(cmds.size() == 0, "retry never restarts")

# delta publish: < 1 degree -> nothing, >= 1 -> publish
reset()
sensors(53.5, 40.0)
crons["check_ds18b20"]()
check(published.size() == 0, "delta below threshold not published")
sensors(54.2, 40.0)
crons["check_ds18b20"]()
check(published.size() == 1 && published[0][1]['ds18b20']['temperature'] == 54.2, "delta above threshold published")

# forced publish skips 85 readings
reset()
sensors(85, 41.0)
crons["check_ds18b20_force"]()
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "force publish skips 85")

# ping failure: no restart during boot window, restart after
reset()
millis_now = 5000
rules["Ping#192.168.22.1#Success==0"]()
check(cmds.size() == 0, "ping fail early uptime: no restart")
millis_now = MIN_UPTIME_FOR_RESTART_MS + 1
rules["Ping#192.168.22.1#Success==0"]()
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after uptime guard: restart")

print(f"{failures} failures")
if failures > 0 raise "test_failed" end
