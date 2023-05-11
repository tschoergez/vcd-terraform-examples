# Requirements
## Get required existing objects
data "vcd_nsxt_manager" "nsxt_mgr_vcf_lon5_nsx01" {
  name = var.nsxt_manager
}

data "vcd_nsxt_tier0_router" "t0_ec02" {
  name            = "t0-ec02"
  nsxt_manager_id = data.vcd_nsxt_manager.nsxt_mgr_vcf_lon5_nsx01.id
}

data "vcd_nsxt_tier0_router" "t0_ec03" {
  name            = "t0-ec03"
  nsxt_manager_id = data.vcd_nsxt_manager.nsxt_mgr_vcf_lon5_nsx01.id
}

data "vcd_vcenter" "lon5_m01_vc01" {
  name = "lon5-m01-vc01.rd-vcf.cloudhappens.local"
}

data "vcd_portgroup" "lon5_m01_vc01_svc01" {
  name = "lon5-m01-cl01-vds01-pg-svc01"
  type = "DV_PORTGROUP"
}

# Infrastructure management
resource "vcd_nsxt_alb_controller" "lon5_rd_avi01ctl01" {
  name         = var.avi_controller
  description  = "First Avi Controller - Terraform managed"
  url          = "https://${var.avi_controller}"
  username     = var.avi_username
  password     = var.avi_password
  license_type = "ENTERPRISE"
}

data "vcd_nsxt_alb_importable_cloud" "lon5_rd_avi01ctl01_importable_cloud_nsx01" {
  depends_on = [
    avi_cloud.cloud_lon5_m01_nsx01
  ]

  name          = "cloud_lon5-m01-nsx01"
  controller_id = vcd_nsxt_alb_controller.lon5_rd_avi01ctl01.id
}

resource "vcd_nsxt_alb_cloud" "lon5_rd_avi01ctl01_cloud_nsx01" {
  name        = "cloud_lon5-m01-nsx01"
  description = "NSX-T ALB Cloud"

  controller_id       = vcd_nsxt_alb_controller.lon5_rd_avi01ctl01.id
  importable_cloud_id = data.vcd_nsxt_alb_importable_cloud.lon5_rd_avi01ctl01_importable_cloud_nsx01.id
  network_pool_id     = data.vcd_nsxt_alb_importable_cloud.lon5_rd_avi01ctl01_importable_cloud_nsx01.network_pool_id
}

resource "vcd_nsxt_alb_service_engine_group" "lon5_rd_avi01ctl01_seg_ded_nm01" {
  depends_on = [vcd_nsxt_alb_cloud.lon5_rd_avi01ctl01_cloud_nsx01]

  name                                 = "seg-ded-nm01"
  description                          = "Dedicated Service Engine Group"
  alb_cloud_id                         = vcd_nsxt_alb_cloud.lon5_rd_avi01ctl01_cloud_nsx01.id
  importable_service_engine_group_name = "seg-ded-nm01"
  reservation_model                    = "DEDICATED"
  sync_on_refresh                      = true
}

resource "vcd_nsxt_alb_service_engine_group" "lon5_rd_avi01ctl01_seg_sha_nm01" {
  depends_on = [vcd_nsxt_alb_cloud.lon5_rd_avi01ctl01_cloud_nsx01]

  name                                 = "seg-sha-nm01"
  description                          = "Shared Service Engine Group"
  alb_cloud_id                         = vcd_nsxt_alb_cloud.lon5_rd_avi01ctl01_cloud_nsx01.id
  importable_service_engine_group_name = "seg-sha-nm01"
  reservation_model                    = "SHARED"
  sync_on_refresh                      = true
}


# Resources management
resource "vcd_external_network_v2" "ext_lon5vc01_dvpc_svc01" {
  name        = "ext-lon5vc01-dvpg-svc01"
  description = "DVPG Service Network - VLAN 1671 - Terraform managed"

  vsphere_network {
    vcenter_id   = data.vcd_vcenter.lon5_m01_vc01.id
    portgroup_id = data.vcd_portgroup.lon5_m01_vc01_svc01.id
  }

  ip_scope {
    enabled       = true
    gateway       = "172.16.71.1"
    prefix_length = "24"

    static_ip_pool {
      start_address = "172.16.71.11"
      end_address   = "172.16.71.99"
    }
  }
}

resource "vcd_external_network_v2" "ext_lon5nsx01_seg_vlan_svc02" {
  name        = "ext-lon5nsx01-segvlan-svc02"
  description = "NSX-T VLAN Segment Service Network - VLAN 1672 - Terraform managed"

  nsxt_network {
    nsxt_manager_id   = data.vcd_nsxt_manager.nsxt_mgr_vcf_lon5_nsx01.id
    nsxt_segment_name = data.nsxt_policy_segment_realization.realization_ext_nsxtvlan_seg01.network_name
  }

  ip_scope {
    enabled       = true
    gateway       = "172.16.72.1"
    prefix_length = "24"

    static_ip_pool {
      start_address = "172.16.72.11"
      end_address   = "172.16.72.99"
    }
  }
}

resource "vcd_external_network_v2" "ext_lon5nsx01_t0gw_sha" {
  name        = "ext-lon5nsx01-t0gw-sha"
  description = "Tier-0 Gateway Shared - Terraform managed"

  nsxt_network {
    nsxt_manager_id      = data.vcd_nsxt_manager.nsxt_mgr_vcf_lon5_nsx01.id
    nsxt_tier0_router_id = data.vcd_nsxt_tier0_router.t0_ec02.id
  }

  ip_scope {
    enabled       = true
    gateway       = "172.16.81.1"
    prefix_length = "24"

    static_ip_pool {
      start_address = "172.16.81.11"
      end_address   = "172.16.81.99"
    }
  }
}

resource "vcd_external_network_v2" "ext_lon5nsx01_t0gw_ded" {
  name        = "ext-lon5nsx01-t0gw-ded"
  description = "Tier-0 Gateway Dedicated - Terraform managed"

  nsxt_network {
    nsxt_manager_id      = data.vcd_nsxt_manager.nsxt_mgr_vcf_lon5_nsx01.id
    nsxt_tier0_router_id = data.vcd_nsxt_tier0_router.t0_ec03.id
  }

  ip_scope {
    enabled       = true
    gateway       = "172.16.82.1"
    prefix_length = "24"

    static_ip_pool {
      start_address = "172.16.82.11"
      end_address   = "172.16.82.99"
    }
  }
}
