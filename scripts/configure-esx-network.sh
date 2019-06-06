#!/bin/sh
set -e

echo "Creating port group ${port_group_name} ..."
esxcfg-vswitch --add-pg=${port_group_name} ${vswitch_name}

echo "ESX network configuration done."
