# Stub `mqtt` module for offline tests. Forwards to the global
# mqtt_publish_hook(topic, payload, retain) defined by the test harness.
var m = module("mqtt")
m.publish = def (topic, payload, retain) mqtt_publish_hook(topic, payload, retain) end
m.connected = def () return mqtt_connected_hook() end
return m
