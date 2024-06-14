## SpeakerBox
```
## SpeakerBox
Rule1
ON System#Boot DO i2sgain 100 ENDON
ON mqtt#connected DO Subscribe HDB, muh/portal/HDB/json, state ENDON
ON Event#HDB DO i2splay +/HDB.mp3 ENDON

Rule2
ON mqtt#connected DO Subscribe HD, muh/portal/HD/json, state ENDON
ON Event#HD!=%mem10% DO Backlog mem10 %value%; i2splay +/HD%value%.mp3 ENDON
ON mqtt#connected DO Subscribe G, muh/portal/G/json, state ENDON
ON Event#G!=%mem11% DO Backlog mem11 %value%; i2splay +/G%value%.mp3 ENDON  
ON mqtt#connected DO Subscribe GD, muh/portal/GD/json, state ENDON
ON Event#GD!=%mem12% DO Backlog mem12 %value%; i2splay +/GD%value%.mp3 ENDIF ENDON
```