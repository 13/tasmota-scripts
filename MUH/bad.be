#- Bad -#

import json

print(string.format("MUH: Loading bad.be on %s...", DEVICENAME))

# Monitor power consumption and turn off the plug if the average wattage over the last 20 minutes is below 20 watts

# Define the threshold and time window
var WATT_THRESHOLD = 20          # Threshold in watts
var TIME_WINDOW = 20             # minutes
var INTERVAL = 2                 # minutes
var power_readings = []          # List to store power readings

# Function to check the power consumption and control the plug
def check_power()
  var sensors = json.load(tasmota.read_sensors())
  var power = sensors['ENERGY']['Power']  # Get the current power consumption in watts
  power_readings.push(power)       # Add the current reading to the list

  # Remove readings older than the time window
  if power_readings.size() > TIME_WINDOW * 60 / INTERVAL * 60
    power_readings.remove(0)     # Remove the oldest reading
  end

  # Calculate the average power over the last 20 minutes
  var total_power = 0
  for reading: power_readings
    total_power += reading
  end
  var average_power = total_power / power_readings.size()

  # Check if the average power is below the threshold
  if tasmota.get_power()[0] && average_power < WATT_THRESHOLD
    tasmota.set_power(0, false) # Turn off the plug
    print(string.format("Washing machine finished. Current power: %s, Average power: %s", power, average_power))
  else
    print(string.format("Washing machine is running. Current power: %s, Average power: %s", power, average_power))
  end
end

# Schedule the function to run every 5 minutes
tasmota.add_cron("0 */5 * * * *", check_power, "check_power")

print("Washing machine power monitor script initialized.")
