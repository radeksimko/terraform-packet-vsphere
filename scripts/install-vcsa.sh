#!/bin/bash
set -e

# Prefill SSL cert thumbprint
ESXI_HOST=$(jq -r .new_vcsa.esxi.hostname ${vcsa_tpl_path})
ESXI_USER=$(jq -r .new_vcsa.esxi.username ${vcsa_tpl_path})

TMP_FILE=$(mktemp)
echo "${private_key_pem}" > $TMP_FILE
echo "private key stored temporarily at "$TMP_FILE
echo "Sourcing SSL certificate thumbprint for ESXi ($${ESXI_USER}@$${ESXI_HOST}) ..."
CMD="openssl x509 -in /etc/vmware/ssl/rui.crt -fingerprint -sha1 -noout"

echo "Waiting until ESXi host is available ..."
set +e
until ping -c 1 $${ESXI_HOST}; do :; done
set -e
echo "ESXi host now ready at $${ESXI_HOST}"

SSL_CERT_THUMBPRINT=$(ssh -o StrictHostKeyChecking=no -i $TMP_FILE $${ESXI_USER}@$${ESXI_HOST} "$CMD" | awk -F= '{print $2}')
echo "Sourced SSL certificate thumbprint: "$SSL_CERT_THUMBPRINT
rm -f $TMP_FILE
echo "private key removed from "$TMP_FILE

VCSA_TPL_PATH=${replace(vcsa_tpl_path, ".json", "-final.json")}
jq ".new_vcsa.esxi.ssl_certificate_verification.thumbprint = \"$${SSL_CERT_THUMBPRINT}\"" ${vcsa_tpl_path} > $VCSA_TPL_PATH
echo "Prefilled SSL certificate thumbprint to VCSA template."

# Install ovftool
echo "Downloading ovftool ..."
curl -f -L '${ovftool_url}' -o ./vmware-ovftool.bundle
chmod a+x ./vmware-ovftool.bundle
echo "Installing ovftool ..."
TERM=dumb ./vmware-ovftool.bundle --eulas-agreed

# Install vCenter Server Appliance
MOUNT_LOCATION=/mnt/vcenter
echo "Downloading vCenter Server Appliance ..."
curl -f -L '${vcsa_iso_url}' -o ./vmware-vcenter.iso
if [ -d $MOUNT_LOCATION ]; then
	echo "Existing folder found at $${MOUNT_LOCATION} - unmounting ..."
	umount $MOUNT_LOCATION
	rmdir $MOUNT_LOCATION
	echo "$${MOUNT_LOCATION} unmounted."
fi
mkdir -p $MOUNT_LOCATION
echo "Mounting downloaded VCSA ISO to $MOUNT_LOCATION ..."
mount -o loop ./vmware-vcenter.iso $MOUNT_LOCATION
echo "Installing VCSA ..."
$${MOUNT_LOCATION}/vcsa-cli-installer/lin64/vcsa-deploy install --accept-eula $VCSA_TPL_PATH
echo "VCSA installed."
umount $MOUNT_LOCATION
echo "$MOUNT_LOCATION unmounted."
