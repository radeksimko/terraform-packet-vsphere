#!/bin/bash
set -e

BINPATH=/usr/local/bin

echo "Installing govc..."
curl -f -L '${govc_url}' -o /tmp/govc_linux_amd64.gz
gunzip /tmp/govc_linux_amd64.gz
mv /tmp/govc_linux_amd64 $BINPATH/govc
chmod a+x $BINPATH/govc

govc version
