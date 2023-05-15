# Sehlly Plus 1 PM

## G_INT
- Turn off after 30m
- Turn on if G=1
- Extend light Timer
```
Rule1
ON Button1#state=1 DO Backlog Power1 1; RuleTimer1 1800 ENDON
ON Button1#state=0 DO Backlog Power1 0; RuleTimer1 0 ENDON
ON Rules#Timer=1 DO Power1 0 ENDON

ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G=1 DO Backlog event checksunrise=%time%; event checksunset=%time% ENDON
ON event#checksunrise<%sunrise% DO Backlog Power1 1; RuleTimer1 300 ENDON
ON event#checksunset>%sunset% DO Backlog Power1 1; RuleTimer1 300 ENDON

ON mqtt#connected DO Subscribe GDP, muh/portal/GDP/json, state ENDON
ON Event#GDP=1 DO Backlog Power1 1; RuleTimer1 300 ENDON
```
