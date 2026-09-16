# tools/test_hz_ww.be — offline behaviour test for MUH/hz_ww.be
# Run: berry tools/test_hz_ww.be   (from repo root)

# Berry compiles this whole file in one pass before executing any of it, so
# a name that a separately-compiled unit (tools/test_env.be, MUH/hz_ww.be)
# assigns only becomes usable here once that unit's own compile()() call has
# actually run. Forward-declare every such name first (nil until then) so
# this file's own code compiles, then call compile() to fill them in.
var published, cmds, rules, crons, timers, sensor_json, check, reset, load, finish, json, string
compile("tools/test_env.be", "file")()

# Globals provided by MUH/hz_ww.be
var boot_publish, MIN_UPTIME_FOR_RESTART_MS

def mock_sensors(a, b)
  sensor_json = json.dump({
    'Time': 'x',
    'ANALOG': {'Temperature1': 19.5},
    'DS18B20-3628FF': {'Id': '00042B3628FF', 'Temperature': a},
    'DS18B20-1C16E1': {'Id': '0621C01C16E1', 'Temperature': b},
  })
end

# ---- load script under test with one sensor stuck at 85 ----
mock_sensors(85, 40.0)
cmds = []
load("MUH/hz_ww.be")
check(cmds.size() == 0, "script does not call tasmota.cmd at load (no DeviceName re-query)")

var guard_timer = nil
for t: timers
  if t[2] == "hz_ww_restart_guard" guard_timer = t end
end

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
mock_sensors(53.1, 40.0)
timers = []
boot_publish(1)
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-3628FF/json", "retry publishes recovered sensor")
check(cmds.size() == 0, "retry never restarts")

# delta publish: < 1 degree -> nothing, >= 1 -> publish
reset()
mock_sensors(53.5, 40.0)
crons["check_ds18b20"]()
check(published.size() == 0, "delta below threshold not published")
mock_sensors(54.2, 40.0)
crons["check_ds18b20"]()
check(published.size() == 1 && published[0][1]['ds18b20']['temperature'] == 54.2, "delta above threshold published")

# forced publish skips 85 readings
reset()
mock_sensors(85, 41.0)
crons["check_ds18b20_force"]()
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "force publish skips 85")

# ping failure: no restart until the boot-window latch timer has fired, restart after
reset()
check(guard_timer != nil && guard_timer[0] == MIN_UPTIME_FOR_RESTART_MS, "restart guard timer armed at load with MIN_UPTIME_FOR_RESTART_MS")
rules["Ping#192.168.22.1#Success==0"]()
check(cmds.size() == 0, "ping fail before guard timer fired: no restart")
guard_timer[1]()
rules["Ping#192.168.22.1#Success==0"]()
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after guard timer fired: restart")

# nil Temperature is skipped, not published as null
reset()
sensor_json = json.dump({
  'DS18B20-3628FF': {'Id': '00042B3628FF'},
  'DS18B20-1C16E1': {'Id': '0621C01C16E1', 'Temperature': 44.0},
})
crons["check_ds18b20_force"]()
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "nil temperature sensor skipped, other still published")

# missing Id is skipped and does not abort the pass for the other sensor
reset()
sensor_json = json.dump({
  'DS18B20-3628FF': {'Temperature': 50.0},
  'DS18B20-1C16E1': {'Id': '0621C01C16E1', 'Temperature': 45.0},
})
crons["check_ds18b20_force"]()
check(published.size() == 1 && published[0][0] == "muh/sensors/HZ_WW/DS18B20-1C16E1/json", "missing Id sensor skipped, other still published")

# missing Temperature at boot counts as pending and arms a retry
reset()
sensor_json = json.dump({
  'DS18B20-3628FF': {'Id': '00042B3628FF'},
  'DS18B20-1C16E1': {'Id': '0621C01C16E1', 'Temperature': 45.0},
})
rules["system#boot"]()
check(timers.size() == 1, "missing temperature at boot arms retry timer")

finish()
