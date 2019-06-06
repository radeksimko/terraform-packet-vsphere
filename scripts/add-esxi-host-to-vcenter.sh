#!/bin/bash
set -e

echo "Attempting to login via govc..."
export GOVC_USERNAME="${vcenter_username}"
export GOVC_PASSWORD="${vcenter_password}"
export GOVC_URL=${vcenter_url}
export GOVC_INSECURE=1
govc about

echo "Creating datacenter ..."
govc datacenter.create ${datacenter_name}

TMP_FILE=$(mktemp)
echo "${private_key_pem}" > $TMP_FILE
echo "private key stored temporarily at "$TMP_FILE

echo "Sourcing SSL certificate thumbprint for ESXi (${esxi_hostname}) ..."
CMD="openssl x509 -in /etc/vmware/ssl/rui.crt -fingerprint -sha1 -noout"
SSL_CERT_THUMBPRINT=$(ssh -o StrictHostKeyChecking=no -i $TMP_FILE ${esxi_username}@${esxi_hostname} "$CMD" | awk -F= '{print $2}')
echo "Sourced SSL certificate thumbprint: "$SSL_CERT_THUMBPRINT

rm -f $TMP_FILE
echo "private key removed from "$TMP_FILE

echo "Adding ESXi host to the datacenter ..."
govc host.add -hostname ${esxi_hostname} -username ${esxi_username} -password '${esxi_password}' -thumbprint $SSL_CERT_THUMBPRINT
echo "Added ESXi host to the datacenter."

# Networking

echo "Creating DSwitch ..."
govc dvs.create -product-version ${esxi_version} -dc ${datacenter_name} ${dswitch_name}
echo "DSwitch created."

echo "Finding physical NIC with MAC ${nic_mac_addr} ..."
ALL_INTERFACES=$(govc host.esxcli network nic list)
PNIC_NAME=$(echo "$ALL_INTERFACES" | awk '{if($8 == "${nic_mac_addr}"){print $1}}')
echo "Found physical NIC $PNIC_NAME"

echo "Adding host to DSwitch (${dswitch_name}) via physical NIC ($PNIC_NAME) ..."
govc dvs.add -dvs=${dswitch_name} -dc=${datacenter_name} -pnic $PNIC_NAME ${esxi_hostname}
echo "Added host to DSwitch."

echo "Adding ${length(vlans)} distributed port groups to ${dswitch_name} ..."
%{ for idx, vlan in vlans ~}
govc dvs.portgroup.add -dvs ${dswitch_name} -dc ${datacenter_name} -type ephemeral -vlan=${vlan_ids[idx]} ${vlan.name}
%{ endfor }
echo "Added distributed port groups to ${dswitch_name}."
