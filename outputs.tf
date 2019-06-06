output "esxi_host" {
  value = local.esxi_ip
}

output "esxi_user" {
  value = local.esxi_username
}

output "esxi_password" {
  value = packet_device.esxi.root_password
}

output "vcenter_endpoint" {
  value = local.vcenter_ip
}

output "vcenter_user" {
  value = local.vcenter_username
}

output "vcenter_password" {
  value = random_string.password.result
}

output "datacenter_name" {
  value = var.datacenter_name
}

output "bastion_host" {
  value = packet_device.bastion.access_public_ipv4
}

output "bastion_user" {
  value = local.bastion_username
}
