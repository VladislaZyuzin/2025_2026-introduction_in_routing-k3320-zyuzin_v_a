#!/bin/sh
udhcpc -i eth2
ip route del default via 192.168.10.1 dev eth0
