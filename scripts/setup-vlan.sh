#!/bin/bash
set -e

echo "Installing VLAN support ..."
apt-get update
apt-get -y install vlan
modprobe 8021q
echo "8021q" >> /etc/modules

echo "Finding interface with MAC address ${nic_mac_addr} ..."
apt-get -y install ethtool
ALL_INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | xargs -I{} sh -c "echo -n {},; ethtool -P {} | awk -F': ' '{print \$2}'")
IFACE_COUNT=$(echo "$ALL_INTERFACES" | wc -l)
echo "Found $IFACE_COUNT interfaces in total."
NIC_NAME=$(echo "$ALL_INTERFACES" | awk -F, '{if($2 == "${nic_mac_addr}"){print $1}}')
echo "Found interface with matching MAC address: $${NIC_NAME}"

echo "Removing $${NIC_NAME} from bond ..."
apt-get -y install augeas-tools

echo "Bringing $${NIC_NAME} down ..."
ifdown $${NIC_NAME}

echo "Modifying configuration of $${NIC_NAME} ..."
IFACE_PATH=$(augtool match /files/etc/network/interfaces/iface $${NIC_NAME})
augtool rm $${IFACE_PATH}/bond-master
augtool rm $${IFACE_PATH}/pre-up

echo "Setting up ${length(vlans)} VLANs on $${NIC_NAME} ..."
cat <<EOT >> /etc/network/interfaces
%{ for idx, vlan in vlans }
auto $${NIC_NAME}.${vlan_ids[idx]}
iface $${NIC_NAME}.${vlan_ids[idx]} inet static
    address ${vlan.bastion_addr}
    netmask ${cidrnetmask(vlan.network_cidr)}
    vlan-raw-device $${NIC_NAME}
%{ endfor }
EOT

echo "Bringing $${NIC_NAME} back up ..."
ifup $${NIC_NAME}

echo "VLAN setup done."
