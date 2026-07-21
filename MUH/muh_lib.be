#- muh_lib.be — shared helpers for all MUH devices.
   Loaded by autoexec.be BEFORE the device script, so device scripts can
   override the config globals below (plain assignment, no `var`) and use
   every function here. Requires log() from autoexec.be. -#

import json
import mqtt
import string

# Config defaults — override in the device script if needed
DARK_OFFSET = 0           # minutes after sunrise until it counts as dark
DARK_OFFSET_SUNSET = 0    # minutes before sunset from which it counts as dark
POWER_TIMER_DURATION = 20 # seconds until set_power(_, _, true) reverts

# Sunrise/sunset state, refreshed via init_sun()
status_tim = nil

def get_status_tim()
  var resp = tasmota.cmd('Status 7')
  if resp != nil && resp.contains('StatusTIM')
    status_tim = resp['StatusTIM']
  else
    status_tim = nil
  end
  log(f"status_tim: {status_tim}")
end

# Dark = before sunrise+DARK_OFFSET or after sunset-DARK_OFFSET_SUNSET.
# Fail-safe: returns false while sunrise/sunset are unknown.
def is_dark()
  if status_tim == nil
    return false
  end

  var now = tasmota.rtc()['local']
  var d = tasmota.time_dump(now)
  var today = f"{d['year']}-{d['month']}-{d['day']}"

  var sunrise = tasmota.strptime(f"{today} {status_tim['Sunrise']}", "%Y-%m-%d %H:%M")
  var sunset = tasmota.strptime(f"{today} {status_tim['Sunset']}", "%Y-%m-%d %H:%M")
  if sunrise == nil || sunset == nil
    return false
  end

  var sunrise_threshold = sunrise['epoch'] + DARK_OFFSET * 60
  var sunset_threshold = sunset['epoch'] - DARK_OFFSET_SUNSET * 60
  var sunrise_str = tasmota.strftime("%H:%M", sunrise_threshold)
  var sunset_str = tasmota.strftime("%H:%M", sunset_threshold)
  log(f"Sunrise: {sunrise_str}, Sunset: {sunset_str}")

  return now < sunrise_threshold || now > sunset_threshold
end

# Set relay `id`; with timer=true revert after POWER_TIMER_DURATION seconds.
# Setting again while the timer runs restarts it.
def set_power(state, id, timer)
  if id == nil
    id = 0
  end
  tasmota.set_power(id, state)
  tasmota.remove_timer(f"power_timer_{id}")
  if timer
    tasmota.set_timer(POWER_TIMER_DURATION * 1000,
      def () tasmota.set_power(id, !state) end, f"power_timer_{id}")
  end
end

def publish_power_state(id, device_name)
  var payload = {
    "state": int(tasmota.get_power()[id]),
    "time": tasmota.time_str(tasmota.rtc()['local'])
  }
  mqtt.publish(f"muh/lights/{device_name}/json", json.dump(payload), true)
end

# Publish relay `id` as muh/lights/<name>/json whenever it changes
_last_power = {}
def init_power_publish(id, device_name)
  _last_power[device_name] = tasmota.get_power()[id]
  tasmota.add_rule(f"Power{id + 1}#state", def (value)
    var p = tasmota.get_power()[id]
    if _last_power[device_name] != p
      _last_power[device_name] = p
      publish_power_state(id, device_name)
    end
  end)
end

# Keep sunrise/sunset fresh: once time is synced, then every 3 hours
def init_sun()
  tasmota.add_rule("Time#Initialized", def () get_status_tim() end)
  tasmota.add_cron("0 30 */3 * * *", def () get_status_tim() end, "get_status_tim")
end
