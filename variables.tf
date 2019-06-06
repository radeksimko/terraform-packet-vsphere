variable "esxi_plan" {
  default = "c1.xlarge.x86"
}

variable "esxi_version" {
  default = "6.5"
}

variable "bastion_plan" {
  default = "m1.xlarge.x86"
}

variable "govc_version" {
  default     = "v0.20.0"
  description = "Version of govc (see https://github.com/vmware/govmomi/releases)"
}

variable "facility" {
  default = "ams1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8", "8.8.4.4"]
}

variable "datacenter_name" {
  default = "TfDatacenter"
}

variable "project_name" {
  default = "Experimental vSphere Lab"
}

variable "ovftool_url" {
  description = "URL from which to download ovftool"
}

variable "vcsa_iso_url" {
  description = "URL from which to download VCSA ISO"
}

locals {
  ssh_key_name        = "default-vsphere-key"
  bastion_username    = "root"
  bastion_subnet_size = 31

  esxi_ip          = packet_device.esxi.access_public_ipv4
  esxi_username    = "root"
  esxi_subnet_size = 29

  vcsa_domain_name        = "vsphere.local"
  vcenter_username        = "Administrator@${local.vcsa_domain_name}"
  vcenter_vswitch_name    = "vSwitch0"
  vcenter_network         = "vsphere-mgmt"
  vcenter_deployment_size = "xlarge"
  vcenter_ip = cidrhost(
    format(
      "%s/%s",
      packet_device.esxi.network[0].gateway,
      packet_device.esxi.public_ipv4_subnet_size,
    ),
    3,
  )

  dswitch_name = "DSwitch1"
  vlans = [
    {
      name         = "private"
      bastion_addr = "172.16.4.1"
      network_cidr = "172.16.4.0/24"
      dhcp_range = {
        from       = "172.16.4.2"
        to         = "172.16.4.250"
        lease_time = "12h"
      }
      dns = false
      nat = false
    },
    {
      name         = "public-via-nat"
      bastion_addr = "172.16.5.1"
      network_cidr = "172.16.5.0/24"
      dhcp_range = {
        from       = "172.16.5.2"
        to         = "172.16.5.250"
        lease_time = "12h"
      }
      dns = true
      nat = true
    },
  ]

  govc_url = "https://github.com/vmware/govmomi/releases/download/${var.govc_version}/govc_linux_amd64.gz"
}
