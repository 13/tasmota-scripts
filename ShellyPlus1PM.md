# Sehlly Plus 1 PM

## G_INT
- Turn off after 30m
- Turn on if G=1
- Extend light Timer
```
Rule1
ON button1#state DO Backlog Power1 %value%; RuleTimer1 1800 ENDON
ON Rules#Timer=1 DO Power1 off ENDON

ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G=1 DO RuleTimer1 300 ENDON

ON mqtt#connected DO Subscribe GDP, muh/portal/GDP/json, state ENDON
ON Event#GDP=1 DO RuleTimer1 300 ENDON
```
