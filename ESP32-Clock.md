RTC
GPIO4 -> SDA
GPIO5 -> SCL

TM1637
GPIO0 -> CLK
GPIO2 -> DIO

GPIO16 -> BTN
GPIO13 -> DHT22
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
Rule1
  ON system#init DO Backlog DisplayClock 2; Event ShowTemp ENDON

  ON sht3x#Temperature DO var1 %value% ENDON
  ON Event#ShowTemp DO Backlog DisplayText %var1%^; RuleTimer1 5 ENDON
  ON Rules#Timer=1 DO Backlog DisplayClock 2; RuleTimer2 15 ENDON
  ON Rules#Timer=2 Do Event ShowTemp ENDON

  ON button1#state DO IF (%var10% > 1) var10 0 ELSEIF (%var10% > 0) var10 2 ELSE var10 0 ENDIF ENDON
  ON var10#state DO IF (%var10% > 1) var11 0 ELSEIF (%var10% > 0) var11 2 ELSE var11 100 ENDIF ENDON
  ON var11#state DO DisplayLevel %var11% ENDON
  
  ON Minute=1140 DO DisplayLevel 1 ENDON
  ON Minute=390 DO DisplayLevel 100 ENDON
  ON Minute=420 DO DisplayScrollText guten morgen, 2 ENDON
  ON Minute=1200 DO DisplayScrollText guten nacht, 2 ENDON
```
