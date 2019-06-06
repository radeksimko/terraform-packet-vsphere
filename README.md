# VMware vSphere Terraform Configuration

## ⚠️ Warning ⚠️

These configs may NOT represent best-practices for deployment of ESXi, e.g.

 - VMware does NOT recommend exposing ESXi & VCSA and the mgmt network to the internet
 - single ESXi host with single VCSA may not provide sufficient resiliency/availability
 - Unix-based user/access control may not scale beyond a few users

As such this configuration is ❗️ NOT recommended ❗️ for use in production environment.

It is meant to serve either as a POC, a starting point for building such environment,
or to spin up a short-lived environment for non-sensitive experiments.

The main goals when architecting this were simplicity
and ease/speed of deployment & management.

## Architecture

 - 1 device with ESXi & vCenter (2 NICs)
   - 1st NIC in L3 mode (internet connectivity)
     - mapped to (default) `vSwitch0`
     - available for VMs launched via ESXi only _(*)_
   - 2nd NIC in L2 mode
     - mapped to `DSwitch1` & `private`/`public` Distributed Port Groups
     - available for any VMs launched via ESXi or vSphere
 - 1 device with Ubuntu (2 NICs)
   - dnsmasq
   - 1st NIC in L3 mode (internet connectivity)
     - for SSH
   - 2nd NIC in L2 mode
     - DHCP & local DNS (proxy/cache) provided by dnsmasq
 - VLANs connecting both devices via their 2nd (L2) ports
   - `private` (DHCP; no internet access)
   - `public` (DHCP; access to internet via 1st device acting as NAT)

_(*)_ - Launching VMs with public IP requires VCSA having 2 networks (both L2 & L3 NICs)
	active & configured at the same time (so that the 2nd/L3 one can be used for moving
	physical NIC between `vSwitch0` and a DSwitch), which is not trivial to automate/script.

## How To Use

### Prerequisites

- Obtain API token for Packet.net and put it in the [relevant ENV variable](https://www.terraform.io/docs/providers/packet/#auth_token)
- Register and/or login to the [VMware portal](https://my.vmware.com/web/vmware/login)
- Download [VMware OVF Tool for Linux 64-bit](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=353)
- Download [VMware vCenter Server Appliance](https://my.vmware.com/group/vmware/details?downloadGroup=VC67U1B&productId=742&rPId=31320)
- Upload both to an automation-friendly location (such as [S3](https://aws.amazon.com/s3/) or [Wasabi](https://wasabi.com/))
  - Make sure the location of the data is close to the chosen Packet.net facility
  	(the VCSA ISO has around *4GB*, so downloading would take a long time with a slow connection), e.g.
    - Wasabi's `eu-central-1`/Amsterdam & Packet's `ams1`/Amsterdam
    - AWS S3 `eu-central-1`/Frankfurt & Packet's `fra2`/Frankfurt
- Create curl-able URLs - see examples below

### Terraform Apply

```sh
export TF_VAR_ovftool_url=$(aws --profile=vmware s3 presign --expires-in=7200 s3://S3_BUCKET_NAME/vmware-ovftool/VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle)
export TF_VAR_vcsa_iso_url=$(aws --profile=vmware s3 presign --expires-in=7200 s3://S3_BUCKET_NAME/vmware-vsphere/VMware-VCSA-all-6.7.0-11726888.iso)
terraform apply -var=facility=ams1 -var=esxi_plan=c1.xlarge.x86
```

## How To

### Copy SSH key

```sh
echo 'tls_private_key.test.private_key_pem' | terraform console > ~/.ssh/packet-test
```

### SSH to bastion

```sh
ssh -i ~/.ssh/packet-test $(terraform output bastion_user)@$(terraform output bastion_host)
```

### Access VMs deployed without routable IP

You may use SSH tunnel, e.g. assuming the service you wish to access has internal IP `172.16.1.1`

```sh
ssh -i ~/.ssh/packet-test -nNT -L 8443:172.16.1.1:443 root@$(terraform output bastion_host)
```

Then they become available under `localhost:9443` and `localhost:8443` respectively.

#### SSH into VMs in vSphere without routable IP

Assuming your VM has internal IP `172.16.5.173`:

```sh
ssh ubuntu@172.16.5.184 -o "ProxyCommand ssh -W %h:%p -i ~/.ssh/packet-test $(terraform output bastion_user)@$(terraform output bastion_host)"
```

### Upload ISO to a datastore

From bastion host, or anywhere else:

```sh
wget http://www.mirrorservice.org/sites/releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso
# ESXi password may neet to be URL-encoded
govc datastore.upload -u='ESXI_USER:ESXI_PASSWORD@ESXI_HOST' -ds datastore1 -k=true ./ubuntu-18.04.2-live-server-amd64.iso ./ubuntu-18.04.2-live-server-amd64.iso
```

(faster) straight on ESXi host:

```sh
ssh -i ~/.ssh/packet-test $(terraform output esxi_user)@$(terraform output esxi_host)
cd /vmfs/volumes/datastore1
wget http://www.mirrorservice.org/sites/releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso
```

You may then use govc to create & power on the VM with the ISO attached.

### Deploying OVA

From bastion host, or anywhere else:

```sh
wget "... ova"
ovftool --acceptAllEulas -ds=datastore1 --network=public -n=acisim ./acisim-4.0-3d.ova vi://<VCENTER_IP>/TfDatacenter/host/<ESXI_IP>
```

## Why (not) ...

### VPN

While initial setup of VPN may not seem as difficult, ongoing management of access
is not easily automatable without connecting to an AD/LDAP server, which
will generally require wider discussion about security concerns and attack vectors.

Configuring VPN server in such a way that onboarding of new users with different OS
and different clients is not trivial task either.

It was therefore decided to avoid VPN for now.

### VMs with publicly routable IPs

While having ESXi completely isolated would be beneficial from security perspective,
it would also require more complex setup if we wanted to retain the ability
to launch VMs with a publicly routable IP.

Such setup might involve some kind of reverse proxy (e.g. nginx) and very likely
require both external and internal DNS. Whilst dnsmasq's DNS is already in play,
it is only used for proxying requests through to upstream DNS servers
(such as OpenDNS, Google, CloudFlare) and act as local cache,
it does not manage any custom DNS records.

### vCenter behind bastion

We could hide ESXi behind a bastion host and use SSH tunnel to access it,
but it seems nearly impossible to use that approach for the vCenter.

vCenter/VCSA login UI (the one available on `tcp/443`) insists on using
canonical hostname/IP under which it was first deployed, which means
that if vCenter is deployed to a private network with private IP
(e.g. `172.16.16.3`), it will insist on using that address for the login screen.

Due to the nature of SSH tunneling we'd access the login screen on
`localhost:<FWDED-PORT-NUM>`, which doesn't match the private IP
vCenter was deployed under. It would therefore redirect users from `localhost`
to that private IP, which isn't routable from the outside network/internet,
rendering the UI practically unusable.

One of the possible solutions to this problem would likely be VPN
with internal DNS, which would increase complexity.

Another one involves deploying vCenter under hostname & adding an entry such as
`127.0.0.1 vcenter-01.vsphere.local` to `/etc/hosts` of any client, which complicates
the "out of the box" user experience.

Another one assumes users don't need the browser UI and only ever use
the API/CLI, which doesn't suffer from this "canonical hostname" problem.

### DHCP for routable public IP range

It would be great if there was an easy way to launch a VM into
a publicly routable network without having to configure IPs statically.

This however requires running DHCP server on L3 port, which is isolated
to the ESXi host/device and leasing IPs from a range the device (bastion host)
doesn't even own and doing so over the internet doesn't seem to be a good idea.

Routable public IPs therefore need to be configured statically.

## TODO

- ability to launch **VMs with publicly routable IPs in vSphere** (not just in ESXi)
  - `DSwitch0` backed by 1st (L3) NIC, so vcenter can launch VMs with publicly routable IPs
  - will probably require 2nd NIC configured for ESXi (via new VMkernel NIC)
    & vCenter connected to ESXi via that NIC, so that the 1st physical NIC can be removed
    from `vSwitch0` & added to `DSwitch0` without outage
- VLAN with **PXE boot**
- SAN/storage + **vSAN** + dedicated network/VLAN
