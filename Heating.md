# Shelly Plus 1

## Template
```
{"NAME":"Shelly Plus 1","GPIO":[288,0,0,0,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
```
{"NAME":"Shelly Plus 1 ADDON","GPIO":[288,1,0,1,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
```
{"NAME":"Shelly Plus 1 RTC","GPIO":[1,1,0,1,192,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,32,224,0,0,0,0,0,4736,4705,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
## Settings
```
Backlog0 Timezone 99; TimeStd 0,0,10,1,3,60; TimeDst 0,0,3,1,2,120;
Backlog Latitude 46.696153; Longitude 11.152056; Sunrise 1;
```

## HZ_UD
- Turn OFF after 5h (1800)
- RTC
- Kommertemp >= 21 OFF
```
Rule1
ON Power1#state=1 DO RuleTimer1 1800 ENDON ON Power1#state=0 DO RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON
ON mqtt#connected DO Subscribe TEMPK1, muh/sensors/22/json, T2 ENDON
ON mqtt#connected DO Subscribe TEMPK2, muh/sensors/22/json, T4 ENDON
ON mqtt#connected DO Subscribe TEMPK3, muh/sensors/87/json, T1 ENDON
ON mqtt#connected DO Subscribe TEMPK3, muh/sensors/87/json, T2 ENDON
ON Event#TEMPK1>=21 DO Power1 0 ENDON
ON Event#TEMPK2>=21 DO Power1 0 ENDON
ON Event#TEMPK3>=21 DO Power1 0 ENDON
ON Event#TEMPK4>=21 DO Power1 0 ENDON
```

##### Shelly Script
```
let temp_max = 20.5;
let tempk22;
let tempk87;
let tempkAll;
let switch0;

Shelly.call("switch.getstatus",{id: 0,},function (result, error_code, error_message) {
    //print(JSON.stringify(result));
    switch0 = result.output;
    print("Switch0: ", switch0);
  }
);

Shelly.addStatusHandler(function (status) {
  if (status.component === "switch:0") {
    switch0 = status.delta.output;
    print("Switch0: ", switch0);
  }
});

MQTT.subscribe("muh/sensors/22/json", function(topic, msg) {
  let tempk222 = JSON.parse(msg).T2;
  let tempk224 = JSON.parse(msg).T4;
  tempk22 = (tempk222 + tempk224)/2;
  print("22: ",tempk22);
  MQTT.publish("muh/sensors/KOMMER/22", JSON.stringify(tempk22), 0, true);
  if (tempk87 !== "undefined"){
    tempkAll = (tempk87+tempk22)/2;
    MQTT.publish("muh/sensors/KOMMER/ALL", JSON.stringify(tempkAll), 0, true);
  } else {
    MQTT.publish("muh/sensors/KOMMER/ALL", JSON.stringify(tempk22), 0, true);
  }
  /*if (tempk22 >= temp_max && switch0){
    print("HZ_DG: OFF 22 ",tempk22);
    Shelly.call("Switch.set", {'id': 0, 'on': false});
    MQTT.publish("muh/telegram/msg", 'HZ_DG: OFF ' + JSON.stringify(tempk22) + '�� (S22)', 0, false);
  }*/
});

MQTT.subscribe("muh/sensors/87/json", function(topic, msg) {
  let tempk871 = JSON.parse(msg).T1;
  let tempk872 = JSON.parse(msg).T2;
  tempk87 = (tempk871 + tempk872)/2;
  print("87: ",tempk87);
  MQTT.publish("muh/sensors/KOMMER/87", JSON.stringify(tempk87), 0, true);
  if (tempk22 !== "undefined"){
    tempkAll = (tempk87+tempk22)/2;
    MQTT.publish("muh/sensors/KOMMER/ALL", JSON.stringify(tempkAll), 0, true);
  } else {
    MQTT.publish("muh/sensors/KOMMER/ALL", JSON.stringify(tempk87), 0, true);
  }
  /*if (tempk87 >= temp_max && switch0){
    print("HZ_DG: OFF 87 ",tempk87);
    Shelly.call("Switch.set", {'id': 0, 'on': false});
    MQTT.publish("muh/telegram/msg", 'HZ_DG: OFF ' + JSON.stringify(tempk87) + '° (S87)', 0, false);
  }*/
});

MQTT.subscribe("muh/sensors/KOMMER/ALL", function(topic, msg) {
  tempkAll = JSON.parse(msg)
  print("K: ",tempkAll);
  if (tempkAll >= temp_max && switch0){
    print("HZ_DG: OFF ",tempkAll);
    Shelly.call("Switch.set", {'id': 0, 'on': false});
    MQTT.publish("muh/telegram/msg", 'HZ_DG: OFF ' + JSON.stringify(tempkAll) + '°', 0, false);
  }
});
```
