# VSPHERE
data "vsphere_datacenter" "dc_lon05_m01" {
  name = "lon5-m01-dc01"
}

data "vsphere_compute_cluster" "dc_lon05_m01_cl01" {
  name          = "lon5-m01-cl01"
  datacenter_id = data.vsphere_datacenter.dc_lon05_m01.id
}

data "vsphere_datastore" "ds_lon05_m01_vsan" {
  name          = "lon5-m01-cl01-ds-vsan01"
  datacenter_id = data.vsphere_datacenter.dc_lon05_m01.id
}

# NSX-T
data "nsxt_policy_transport_zone" "lon5_m01_tz_overlay01" {
  display_name = "lon5-m01-tz-overlay01"
}

data "nsxt_policy_transport_zone" "lon5_m01_tz_vlan01" {
  display_name = "lon5-m01-tz-vlan01"
}

data "nsxt_policy_tier0_gateway" "lon5_m01_t0_main" {
  display_name = "t0-ec01"
}

data "nsxt_policy_edge_cluster" "lon5_m01_edgecluster01" {
  display_name = "lon5-edgecluster01"
}