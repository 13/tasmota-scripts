#- Bad -#

import json

print(string.format("MUH: Loading bad.be on %s...", devicename))

# Berry Script to monitor power consumption and turn off the plug if the average wattage over the last 20 minutes is below 20 watts

# Define the threshold and time window
var watt_threshold = 20          # Threshold in watts
var time_window = 20 * 60        # 20 minutes in seconds
var interval = 600               # Check every 10 minutes
var power_readings = []          # List to store power readings

# Function to check the power consumption and control the plug
def check_power()
  var sensors = json.load(tasmota.read_sensors())
  var power = sensors['ENERGY']['Power']  # Get the current power consumption in watts
  power_readings.push(power)       # Add the current reading to the list

  # Remove readings older than the time window
  while power_readings.size() > time_window / interval
    power_readings.remove(0)     # Remove the oldest reading
  end

  # Calculate the average power over the last 20 minutes
  var total_power = 0
  for reading: power_readings
    total_power = total_power + reading
  end
  var average_power = total_power / power_readings.size()

  # Check if the average power is below the threshold
  if tasmota.get_power() && power < 10
    if average_power < watt_threshold
      tasmota.set_power(0, false) # Turn off the plug
      print("Average power consumption over the last 20 minutes is below threshold. Turning off the plug.")
    else
      print("Average power consumption over the last 20 minutes is above threshold. Plug remains on.")
    end
  end
end

# Schedule the function to run every 10 seconds
tasmota.add_cron("0 */10 * * * *", check_power, "check_power")

print("Washing machine power monitor script initialized.")
