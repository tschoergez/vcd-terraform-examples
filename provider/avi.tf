# Requirements
## vSphere content library
resource "vsphere_content_library" "cl_avi_lon05_m01" {
  name            = "cl-avi01"
  description     = "Avi Content Library for NSX-T Cloud."
  storage_backing = [data.vsphere_datastore.ds_lon05_m01_vsan.id]
}

## Avi required users for cloud connectors
resource "avi_cloudconnectoruser" "cred_vc_lon5_m01_vc01" {
  name = "cred_vc_lon5-m01-vc01"

  vcenter_credentials {
    username = var.vsphere_username
    password = var.vsphere_password
  }

  # Force Terraform to consider this resource only for creation but to ignore it when planning an update
  lifecycle {
    ignore_changes = [vcenter_credentials]
  }
}

resource "avi_cloudconnectoruser" "cred_nsx_lon5_m01_nsx01" {
  name = "cred_nsx_lon5-m01-nsx01"

  nsxt_credentials {
    username = var.nsxt_username
    password = var.nsxt_password
  }

  # Force Terraform to consider this resource only for creation but to ignore it when planning an update
  lifecycle {
    ignore_changes = [nsxt_credentials]
  }
}

## DHCP for the Avi Management segment
resource "nsxt_policy_dhcp_server" "dhcp_profile_avi_lon5_m01" {
  display_name     = "dhcp-profile-mgtavi-lon5-m01 "
  server_addresses = ["100.96.0.1/30"]
}

resource "nsxt_policy_tier1_gateway" "t1_lon05_m01_avi_mgmt" {
  display_name              = "avi-t1"
  description               = "Tier-1 provisioned by Terraform"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.lon5_m01_edgecluster01.path
  dhcp_config_path          = nsxt_policy_dhcp_server.dhcp_profile_avi_lon5_m01.path
  failover_mode             = "PREEMPTIVE"
  enable_firewall           = "false"
  tier0_path                = data.nsxt_policy_tier0_gateway.lon5_m01_t0_main.path
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]
  pool_allocation           = "ROUTING"
}

resource "nsxt_policy_segment" "ls_lon05_m01_avi_mgmt" {
  display_name        = "ls-avi-mgmt"
  description         = "Avi service engines management network segment"
  connectivity_path   = nsxt_policy_tier1_gateway.t1_lon05_m01_avi_mgmt.path
  transport_zone_path = data.nsxt_policy_transport_zone.lon5_m01_tz_overlay01.path

  subnet {
    cidr        = "172.16.20.1/24"
    dhcp_ranges = ["172.16.20.10-172.16.20.99"]
  }
}

resource "nsxt_policy_segment" "ls_lon05_m01_avi_dummy_vip" {
  display_name        = "ls-avi-dummy-vip"
  description         = "Dummy Avi VIP segment (required to create an NSX-T Cloud)"
  connectivity_path   = nsxt_policy_tier1_gateway.t1_lon05_m01_avi_mgmt.path
  transport_zone_path = data.nsxt_policy_transport_zone.lon5_m01_tz_overlay01.path

  subnet {
    cidr = "172.16.19.1/24"
  }
}


# NSX-T Cloud creation

resource "avi_cloud" "cloud_lon5_m01_nsx01" {
  depends_on = [
    avi_cloudconnectoruser.cred_nsx_lon5_m01_nsx01
  ]

  name            = "cloud_lon5-m01-nsx01"
  vtype           = "CLOUD_NSXT"
  obj_name_prefix = "avi01"
  dhcp_enabled    = "true"

  nsxt_configuration {
    nsxt_url             = var.nsxt_manager
    nsxt_credentials_ref = avi_cloudconnectoruser.cred_nsx_lon5_m01_nsx01.id

    management_network_config {
      transport_zone = data.nsxt_policy_transport_zone.lon5_m01_tz_overlay01.path
      tz_type        = "OVERLAY"

      overlay_segment {
        tier1_lr_id = nsxt_policy_tier1_gateway.t1_lon05_m01_avi_mgmt.path
        segment_id  = nsxt_policy_segment.ls_lon05_m01_avi_mgmt.path
      }
    }

    data_network_config {
      transport_zone = data.nsxt_policy_transport_zone.lon5_m01_tz_overlay01.path
      tz_type        = "OVERLAY"

      tier1_segment_config {
        segment_config_mode = "TIER1_SEGMENT_MANUAL"

        manual {
          tier1_lrs {
            tier1_lr_id = nsxt_policy_tier1_gateway.t1_lon05_m01_avi_mgmt.path
            segment_id  = nsxt_policy_segment.ls_lon05_m01_avi_dummy_vip.path
          }
        }
      }
    }
  }
}

## Creates vCenterserver resource on Avi controller and attaches it to the NSXT_CLOUD
resource "avi_vcenterserver" "vc_cloud_lon5_m01_nsx01" {
  depends_on = [
    avi_cloudconnectoruser.cred_vc_lon5_m01_vc01,
    avi_cloud.cloud_lon5_m01_nsx01
  ]

  name        = var.vsphere_server
  vcenter_url = var.vsphere_server
  cloud_ref   = avi_cloud.cloud_lon5_m01_nsx01.id

  vcenter_credentials_ref = avi_cloudconnectoruser.cred_vc_lon5_m01_vc01.id

  content_lib {
    id = vsphere_content_library.cl_avi_lon05_m01.id
  }
}

# Service Engine Groups creation
resource "avi_serviceenginegroup" "seg_cloud_lon5_m01_nsx01_sha_nm01" {
  name           = "seg-sha-nm01"
  se_name_prefix = "shanm01"
  ha_mode        = "HA_MODE_SHARED"
  max_se         = 10
  max_vs_per_se  = 10


  cloud_ref = avi_cloud.cloud_lon5_m01_nsx01.id

  vcenters {
    vcenter_ref = avi_vcenterserver.vc_cloud_lon5_m01_nsx01.id

    nsxt_datastores {
      include = true
      ds_ids  = [data.vsphere_datastore.ds_lon05_m01_vsan.id]
    }

    nsxt_clusters {
      include     = true
      cluster_ids = [data.vsphere_compute_cluster.dc_lon05_m01_cl01.id]
    }
  }
}

resource "avi_serviceenginegroup" "seg_cloud_lon5_m01_nsx01_ded_nm01" {
  name           = "seg-ded-nm01"
  se_name_prefix = "dednm01"
  ha_mode        = "HA_MODE_SHARED"
  max_se         = 10
  max_vs_per_se  = 10

  cloud_ref = avi_cloud.cloud_lon5_m01_nsx01.id

  vcenters {
    vcenter_ref = avi_vcenterserver.vc_cloud_lon5_m01_nsx01.id

    nsxt_datastores {
      include = true
      ds_ids  = [data.vsphere_datastore.ds_lon05_m01_vsan.id]
    }

    nsxt_clusters {
      include     = true
      cluster_ids = [data.vsphere_compute_cluster.dc_lon05_m01_cl01.id]
    }
  }
}
