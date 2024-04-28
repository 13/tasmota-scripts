
## Features
- TM1637
- RTC DS3231
- Temperature sensor
- Button display level
- Displaylevel full daylight and less at night (min & max) 19:00 & 06:00
- disable for 1 hour if button was pressed
- Easteregg at 07:00 DisplayScrollText guten morgen, 3

## Rule
- Show every 7 seconds temperature
- on button1#state
```
Rule1
  ON sht3x#Temperature DO var1 %value% ENDON
  ON Event#ShowTemp DO Backlog DisplayText %var1%^; RuleTimer1 7 ENDON
  ON Rules#Timer=1 DO DisplayText %var1%^ ENDONx

  ON button1#state DO IF (%var10% > 1) var10 0 ELSEIF (%var10% > 0) var10 2 ELSE var10 0 ENDIF ENDON
  ON var10#state DO IF (%var10% > 1) var11 0 ELSEIF (%var10% > 0) var11 2 ELSE var11 100 ENDIF ENDON
  ON var11#state DO DisplayLevel %var11% ENDON
  
  ON Minute=1140 DO DisplayLevel 1 ENDON
  ON Minute=360 DO DisplayLevel 100 ENDON
  ON Minute=420 DO DisplayScrollText guten morgen, 3 ENDON

```
