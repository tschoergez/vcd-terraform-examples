# Create a new org
resource "vcd_org" "org01" {
  name             = "Cyberdyne"
  full_name        = "Cyberdyne Systems"
  description      = "Cyberdyne Systems Corporation"
  is_enabled       = "true"
  delete_recursive = "true"
  delete_force     = "true"
}

data "vcd_global_role" "organization_admin" {
  name = "Organization Administrator"
}

resource "vcd_global_role" "adv_org_admin" {
  name        = "Organization Administrator - Advanced"
  description = "Organization Administrator with additional specific permissions (e.g., for VDC Groups)"

  publish_to_all_tenants = true

  rights = setunion(
    data.vcd_global_role.organization_admin.rights,
    ["vDC Group: View"],
  )
}

resource "vcd_org_user" "org01_admin" {
  depends_on = [vcd_org.org01]

  org           = vcd_org.org01.name
  name          = "cyberdyne-admin"
  password      = "VMware1!"
  description   = "John Smith"
  enabled       = true
  email_address = "admin@corp.local"
  role          = "Organization Administrator - Advanced"
}

# Create organization VDC for above org
resource "vcd_org_vdc" "org01_ovdc01" {
  depends_on = [vcd_org.org01]

  name              = "cyberdyne-vdc01"
  description       = "NSX-T Organization VDC - Provisioned with Terraform"
  org               = vcd_org.org01.name
  allocation_model  = "AllocationVApp"
  network_pool_name = "np-lon5-m01-geneve01"
  provider_vdc_name = "pvdc-nsxt"

  compute_capacity {
    cpu {
      limit = 0
    }
    memory {
      limit = 0
    }
  }

  storage_profile {
    name    = "vSAN Default Storage Policy"
    limit   = 204800
    default = true
  }

  vm_quota                 = 100
  network_quota            = 100
  enabled                  = true
  enable_thin_provisioning = true
  enable_fast_provisioning = true
  delete_force             = true
  delete_recursive         = true
}

# Create organization VDC for above org
resource "vcd_org_vdc" "org01_ovdc02" {
  depends_on = [vcd_org.org01]

  name              = "cyberdyne-vdc02"
  description       = "NSX-T Organization VDC - Provisioned with Terraform"
  org               = vcd_org.org01.name
  allocation_model  = "AllocationVApp"
  network_pool_name = "np-lon5-m01-geneve01"
  provider_vdc_name = "pvdc-nsxt"

  compute_capacity {
    cpu {
      limit = 0
    }
    memory {
      limit = 0
    }
  }

  storage_profile {
    name    = "vSAN Default Storage Policy"
    limit   = 204800
    default = true
  }

  vm_quota                 = 100
  network_quota            = 100
  enabled                  = true
  enable_thin_provisioning = true
  enable_fast_provisioning = true
  delete_force             = true
  delete_recursive         = true
}

# Networking 
resource "vcd_vdc_group" "org01_ovdc01_dcgroup01" {
  org                   = vcd_org.org01.name
  name                  = "cyberdyne-dcgroup01"
  description           = "Data Center Group - Provisioned with Terraform"
  starting_vdc_id       = vcd_org_vdc.org01_ovdc01.id
  participating_vdc_ids = [vcd_org_vdc.org01_ovdc01.id, vcd_org_vdc.org01_ovdc02.id]
  dfw_enabled           = true
  default_policy_status = true
}

resource "vcd_nsxt_edgegateway" "org01_ovdc01_edge01" {
  depends_on = [
    vcd_org_vdc.org01_ovdc01,
    vcd_nsxt_alb_cloud.lon5_rd_avi01ctl01_cloud_nsx01
  ]

  org         = vcd_org.org01.name
  owner_id    = vcd_vdc_group.org01_ovdc01_dcgroup01.id
  name        = "cyberdyne-edge01"
  description = "Edge 01 - Cyberdyne Systems"

  external_network_id       = vcd_external_network_v2.ext_lon5nsx01_t0gw_ded.id
  dedicate_external_network = true

  subnet {
    gateway       = "172.16.82.1"
    prefix_length = "24"
    primary_ip    = "172.16.82.11"

    allocated_ips {
      start_address = "172.16.82.11"
      end_address   = "172.16.82.19"
    }
  }
}

## Currently those `vcd_nsxt_alb_settings` and `vcd_nsxt_alb_edgegateway_service_engine_group`settings fail with a '[ENF] entity not found: no NSX-T Edge Gateway with ID' error message
## Some resources don't understand that the edge belong to a data center group: https://github.com/vmware/terraform-provider-vcd/issues/842
## It will be fixed shortly
#resource "vcd_nsxt_alb_settings" "org01_ovdc01_edge01_lb" {
#  org = vcd_org.org01.name
#  vdc = vcd_org_vdc.org01_ovdc01.name
#
#  edge_gateway_id = vcd_nsxt_edgegateway.org01_ovdc01_edge01.id
#  is_active       = true
#}

#resource "vcd_nsxt_alb_edgegateway_service_engine_group" "org01_ovdc01_edge01_seg01" {
#  org = vcd_org.org01.name
#  vdc = vcd_org_vdc.org01_ovdc01.name
#
#  edge_gateway_id         = vcd_nsxt_edgegateway.org01_ovdc01_edge01.id
#  service_engine_group_id = vcd_nsxt_alb_service_engine_group.lon5_rd_avi01ctl01_seg_ded_nm01.id
#}

resource "vcd_network_routed_v2" "org01_ovdc01_edge01_routed01" {
  name = "routed_192.168.10.0"

  edge_gateway_id = vcd_nsxt_edgegateway.org01_ovdc01_edge01.id

  gateway       = "192.168.10.1"
  prefix_length = 24

  static_ip_pool {
    start_address = "192.168.10.11"
    end_address   = "192.168.10.49"
  }
}
