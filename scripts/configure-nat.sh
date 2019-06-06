#!/bin/bash
set -e

sysctl net.ipv4.ip_forward=1

%{ for vlan in natted_vlans }
iptables -t nat -A POSTROUTING -s ${vlan.network_cidr} -o bond0 -j MASQUERADE
%{ endfor ~}
