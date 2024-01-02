# 
- Athom Support
```
{"NAME":"Athom Zigbee Bridge","GPIO":[32,0,0,0,0,0,0,0,3552,0,3584,544,0,0,5600,0,0,0,0,5568,0,0,0,0,0,0,0,1,5792,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}

- Blakadder
```
{"NAME":"Athom Zigbee Bridge","GPIO":[32,0,0,0,0,0,0,0,5472,0,5504,544,0,0,5600,0,0,0,0,5568,0,0,0,0,0,0,0,1,5792,0,0,0,0,0,0,0],"FLAG":0,"BASE":1}
```
```
ON system#boot DO TCPStart 8888 ENDON
``

```
backlog rule1 on system#boot do TCPStart 8888 endon ; rule1 1 ; TCPStart 8888
Backlog EthAddress 1; EthClockMode 3; EthType 0
Backlog EthIPAddress 192.168.22.36; EthGateway 192.168.22.6; EthSubnetmask 255.255.255.0; EthDNSServer1 192.168.22.6
```
