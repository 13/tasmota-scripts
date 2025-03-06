#- Bad -#

import json

print(string.format("MUH: Loading bad.be on %s...", DEVICENAME))

# Monitor power consumption and turn off the plug if the average wattage over the last 30 minutes is below 20 watts

# Define the threshold and time window
var WATT_THRESHOLD = 20          # Threshold in watts
var TIME_WINDOW = 30 * 60        # 30 minutes in seconds
var INTERVAL = 5 * 60            # Check every 5 minutes in seconds
var power_readings = []          # List to store power readings

# Function to check the power consumption and control the plug
def check_power()
  var sensors = json.load(tasmota.read_sensors())
  var power = sensors['ENERGY']['Power']  # Get the current power consumption in watts
  power_readings.push(power)       # Add the current reading to the list

  # Remove readings older than the time window
  if power_readings.size() > TIME_WINDOW / INTERVAL
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
    print("Average power consumption over the last 30 minutes is below threshold. Turning off the plug.")
  else
    print("Average power consumption over the last 30 minutes is above threshold. Plug remains on.")
  end
end

# Schedule the function to run every 5 minutes
tasmota.add_cron("0 */5 * * * *", check_power, "check_power")

print("Washing machine power monitor script initialized.")
