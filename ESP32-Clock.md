```
RTC
GPIO4 -> SDA
GPIO5 -> SCL

TM1637
GPIO0 -> CLK
GPIO2 -> DIO

GPIO12 -> BTN
GPIO14 -> DHT22
```
## Features
- TM1637
- RTC DS3231 (i2c SDA/SCL(4))
- Temperature sensor (2 pins(4))
- Button display level (1 pin (2))
- Displaylevel full daylight and less at night (min & max) 19:00 & 06:00
- disable for 1 hour if button was pressed
- Easteregg at 07:00 DisplayScrollText guten morgen, 3

## Rule
- Show every 7 seconds temperature
- on button1#state
```
{"NAME":"AnnaUhr","GPIO":[0,0,0,0,1216,0,0,0,0,32,0,0,0,0,0,0,0,640,608,0,0,0,0,0,0,0,0,0,7104,7136,0,0,0,0,0,0],"FLAG":0,"BASE":1}

Rule1
  ON system#init DO Backlog DisplayDimmer 13; DisplayScrollText Hello, 2; DisplayClock 2; Event ShowTemp ENDON

  ON am2301#Temperature DO var1 %value% ENDON
  ON Event#ShowTemp DO Backlog DisplayText %var1%^; RuleTimer1 5 ENDON
  ON Rules#Timer=1 DO Backlog DisplayClock 2; RuleTimer2 15 ENDON
  ON Rules#Timer=2 Do Event ShowTemp ENDON

  ON button1#state DO IF (%var10% > 1) var10 0 ELSEIF (%var10% > 0) var10 2 ELSE var10 0 ENDIF ENDON
  ON var10#state DO IF (%var10% > 1) var11 0 ELSEIF (%var10% > 0) var11 13 ELSE var11 100 ENDIF ENDON
  ON var11#state DO DisplayDimmer %var11% ENDON
  
  ON Minute=1140 DO DisplayDimmer 13 ENDON
  ON Minute=419 DO DisplayDimmer 100 ENDON

  ON Minute=420 DO DisplayScrollText Guten Morgen, 2 ENDON
  ON Minute=450 DO DisplayScrollText Guten Morgen, 2 ENDON
  ON Minute=1320 DO DisplayScrollText Gute Nacht, 2 ENDON
  ON Minute=1350 DO DisplayScrollText Gute Nacht, 2 ENDON
```
