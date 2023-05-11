## Main config
terraform {
  required_version = ">= 0.13"

  required_providers {
    vcd = {
      source = "vmware/vcd"
    }
  }
}

## Providers definition
provider "vcd" {
  user                 = var.vcd_user
  password             = var.vcd_pass
  org                  = "Cyberdyne"
  vdc                  = "cyberdyne-vdc01"
  url                  = var.vcd_url
  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl
  #logging              = true
  #logging_file         = "tenant-debug.log"
}
