#- PlugUD -#

print(string.format("MUH: Loading plugud.be on %s...", devicename))

var states = [true, true, true]

def ckeckPing(state,id)
  states[id] = state
  if !states[0] && !states[1] && !states[2]
    tasmota.set_power(0,false)
  else
    tasmota.set_power(0,true)
  end
end

# CRON
## checkPing TV
tasmota.add_cron("0 0,30 23,0,1,2 * * *", def (value) tasmota.cmd("ping4 192.168.22.20") end, "checkPing0")
tasmota.add_cron("20 0,30 23,0,1,2 * * *", def (value) tasmota.cmd("ping4 192.168.22.10") end, "checkPing1")
tasmota.add_cron("40 0,30 23,0,1,2 * * *", def (value) tasmota.cmd("ping4 192.168.22.11") end, "checkPing2")

## checkPingTV
tasmota.add_rule("Ping#192.168.22.20#Success", def (value) checkPing(value,0) end)
tasmota.add_rule("Ping#192.168.22.10#Success", def (value) checkPing(value,1) end)
tasmota.add_rule("Ping#192.168.22.11#Success", def (value) checkPing(value,2) end)
