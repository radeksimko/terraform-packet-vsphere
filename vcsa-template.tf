locals {
  vcsa_template = {
    __version = "2.13.0"
    new_vcsa = {
      esxi = {
        hostname           = local.esxi_ip
        username           = local.esxi_username
        password           = packet_device.esxi.root_password
        deployment_network = local.vcenter_network
        datastore          = "datastore1"
        ssl_certificate_verification = {
          thumbprint = "_WILL_BE_REPLACED_BY_JQ_"
        }
      }
      appliance = {
        thin_disk_mode    = true
        deployment_option = local.vcenter_deployment_size
        name              = local.vcenter_ip
      }
      network = {
        ip_family   = "ipv4"
        mode        = "static"
        dns_servers = "0.0.0.0" # Default DNS from interface
        ip          = local.vcenter_ip
        prefix      = tostring(packet_device.esxi.public_ipv4_subnet_size)
        gateway     = packet_device.esxi.network[0].gateway
        system_name = local.vcenter_ip
      }
      os = {
        password        = random_string.password.result
        time_tools_sync = true
        ssh_enable      = true
      }
      sso = {
        password       = random_string.password.result
        domain_name    = local.vcsa_domain_name
        first_instance = true
      }
    }
    ceip = {
      settings = {
        ceip_enabled = false
      }
    }
  }
}

resource "local_file" "vcsa" {
  content  = jsonencode(local.vcsa_template)
  filename = "${path.module}/template.json"
}
