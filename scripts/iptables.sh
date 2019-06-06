#!/bin/bash
set -e

%{ for vlan in block_dns_vlans ~}
iptables -A INPUT -s ${vlan.network_cidr} -p tcp --dport 53 -j REJECT
iptables -A INPUT -s ${vlan.network_cidr} -p udp --dport 53 -j REJECT
%{ endfor }
