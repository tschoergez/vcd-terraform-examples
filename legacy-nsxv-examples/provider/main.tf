variable "vcd_user" {
    description = "vCloud user"
}
variable "vcd_pass" {
    description = "vCloud pass"
}
variable "vcd_allow_unverified_ssl" {
    default = true
}
variable "vcd_url" {}
variable "org_name" {}
variable "pvdc_name" {}
variable "org_admin" {}
variable "network_pool_name" {}
variable "vdc_name" {}
variable "edge_name" {}
variable "vcd_max_retry_timeout" {
    default = 60
}

# Connect VMware vCloud Director Provider
provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_pass
  org                  = "System"
  url                  = var.vcd_url
  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl
}

#Create a new org names "T3"
resource "vcd_org" "org-name" {
  name             =  var.org_name
  full_name        = "Cloud Customer 03"
  description      = "CC03"
  is_enabled       = "true"
  delete_recursive = "true"
  delete_force     = "true"
}

#Create a new Organization Admin
resource "vcd_org_user" "org-admin" {
org = var.org_name #variable referred in variable file 
name = var.org_admin #variable referred in variable file
description = "org admin"
role = "Organization Administrator"
password = "VMware1!"
enabled = true
email_address = "admin@corp.local"
depends_on = [vcd_org.org-name]
}

# Create Org VDC for above org
resource "vcd_org_vdc" "vdc-name" {
  name        = var.vdc_name
  description = "OVDC"
  org         = var.org_name #variable referred in variable file
  allocation_model = "AllocationVApp"
  network_pool_name = var.network_pool_name
  provider_vdc_name = var.pvdc_name
  compute_capacity {
    cpu {
      limit = 0
    }
    memory {
      limit = 0
    }
  }
  storage_profile {
    name     = "vSAN Default Storage Policy"
    limit    = 10240
    default  = true    
  }
  vm_quota                 = 109 #Max no. of VMs 
  network_quota            =  100
  enabled                  = true
  enable_thin_provisioning = true
  enable_fast_provisioning = true
  delete_force             = true
  delete_recursive         = true
depends_on = [vcd_org.org-name]
}

resource "vcd_edgegateway" "egw" {
  org = var.org_name #variable referred in variable file
  vdc = var.vdc_name #variable referred in variable file
  name                    = var.edge_name
  description             = "CC03 Edge"
  configuration           = "compact"
  distributed_routing     = true
  external_network {
    name = "jl42-50-ext"
    #subnet {
    #  ip_address            = "172.26.42.249"
    #  gateway               = "172.26.42.1"
    #  netmask               = "255.255.255.0"
    #  use_for_default_route = true
    #}
  }
depends_on = [vcd_org_vdc.vdc-name]
}

resource "vcd_network_routed" "net" {
org = var.org_name #variable referred in variable file
vdc = var.vdc_name #variable referred in variable file
name = "CC03-routed"
edge_gateway = var.edge_name 
gateway = "10.10.0.1"
dhcp_pool {
start_address = "10.10.0.2"
end_address = "10.10.0.100"
}
static_ip_pool {
start_address = "10.10.0.152"
end_address = "10.10.0.254"
}
depends_on = [vcd_edgegateway.egw]
}
