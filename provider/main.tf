## Main config
terraform {
  required_version = ">= 0.13"

  required_providers {
    vsphere = {
      source = "hashicorp/vsphere"
    }
    avi = {
      source  = "vmware/avi"
      version = "21.1.3"
    }
    nsxt = {
      source = "vmware/nsxt"
    }
    vcd = {
      source = "vmware/vcd"
    }
  }
}

## Providers definition
provider "vsphere" {
  user                 = var.vsphere_username
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

provider "avi" {
  avi_username   = var.avi_username
  avi_password   = var.avi_password
  avi_controller = var.avi_controller
  avi_tenant     = var.avi_tenant
  avi_version    = "21.1.3"
}

provider "nsxt" {
  username              = var.nsxt_username
  password              = var.nsxt_password
  host                  = var.nsxt_manager
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_pass
  org                  = "System"
  url                  = var.vcd_url
  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl
  #  logging              = true
  #  logging_file         = "provider-debug.log"
}