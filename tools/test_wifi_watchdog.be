# tools/test_wifi_watchdog.be — offline test for init_wifi_watchdog() in MUH/muh_lib.be
# Run: berry tools/test_wifi_watchdog.be   (from repo root)

# Berry compiles this whole file in one pass before executing any of it, so
# a name that a separately-compiled unit (tools/test_env.be, MUH/muh_lib.be)
# assigns only becomes usable here once that unit's own compile()() call has
# actually run. Forward-declare every such name first (nil until then) so
# this file's own code compiles, then call compile()/load() to fill them in.
var timers, crons, rules, cmds, check, reset, finish, load, string
compile("tools/test_env.be", "file")()

var WATCHDOG_ARM_MS, init_wifi_watchdog
load("MUH/muh_lib.be")
init_wifi_watchdog("192.168.22.1", "10 */8 * * * *")

# registration
var arm = nil
for t: timers
  if t[2] == "wifi_watchdog_arm" arm = t end
end
check(arm != nil && arm[0] == WATCHDOG_ARM_MS && WATCHDOG_ARM_MS == 120000, "arm timer registered with WATCHDOG_ARM_MS = 120000")
check(crons.contains("wifi_watchdog_ping"), "ping cron registered")
check(rules.contains("Ping#192.168.22.1#Success==0"), "ping-fail rule registered")

# cron issues the ping
reset()
crons["wifi_watchdog_ping"]()
check(cmds.size() == 1 && string.tolower(cmds[0]) == "ping4 192.168.22.1", "cron pings the gateway")

# ping failure before the latch: no restart
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 0, "ping fail before arm timer fired: no restart")

# latch fires, then ping failure restarts
arm[1]()
reset()
rules["Ping#192.168.22.1#Success==0"](0, "Ping#192.168.22.1#Success", nil)
check(cmds.size() == 1 && string.tolower(cmds[0]) == "restart 1", "ping fail after arm timer fired: restart 1")

finish()
