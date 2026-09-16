# tools/test_hz_ww.be — offline behaviour test for MUH/hz_ww.be
# Run: berry tools/test_hz_ww.be   (from repo root)

# Berry compiles this whole file in one pass before executing any of it, so
# a name that a separately-compiled unit (tools/test_env.be, MUH/hz_ww.be)
# assigns only becomes usable here once that unit's own compile()() call has
# actually run. Forward-declare every such name first (nil until then) so
# this file's own code compiles, then call compile() to fill them in.
var published, cmds, rules, crons, timers, sensor_json, check, reset, load, finish, json, string
compile("tools/test_env.be", "file")()

# Globals provided by MUH/muh_lib.be
var WATCHDOG_ARM_MS

# Globals provided by MUH/hz_ww.be
var boot_publish, BOOT_RETRIES, BOOT_RETRY_MS, last_temp

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
load("MUH/muh_lib.be")
load("MUH/hz_ww.be")
check(cmds.size() == 0, "script does not call tasmota.cmd at load (no DeviceName re-query)")

# wifi watchdog wired through muh_lib: arm timer + cron + rule registered by hz_ww.be
var arm = nil
for t: timers
  if t[2] == "wifi_watchdog_arm_192.168.22.1" arm = t end
end
check(arm != nil && arm[0] == WATCHDOG_ARM_MS, "hz_ww registers the shared wifi watchdog arm timer")
check(crons.contains("wifi_watchdog_ping_192.168.22.1") && !crons.contains("check_wifi"), "hz_ww uses the shared ping cron, old check_wifi cron gone")
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 0, "ping fail before arm: no restart")
arm[1]()
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after arm: restart")

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

# retry chain: permanent 85 -> exactly BOOT_RETRIES re-arms, then give up, never a restart
reset()
mock_sensors(85, 40.0)
last_temp = {}
rules["system#boot"](nil, "system#boot", nil)
var rounds = 0
while timers.size() > 0 && rounds < 20
  var t = timers.pop()
  check(t[2] == "hz_ww_boot_retry" && t[0] == BOOT_RETRY_MS, f"retry {rounds + 1} armed as hz_ww_boot_retry")
  t[1]()
  rounds += 1
end
check(rounds == BOOT_RETRIES, f"retry chain stops after BOOT_RETRIES ({BOOT_RETRIES}) attempts")
check(cmds.size() == 0, "retry chain never restarts")

finish()
