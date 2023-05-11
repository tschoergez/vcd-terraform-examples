# Requirements
## Get existing NSX-T objects


######### NOT MUCH HERE AS THE T0 IS CURRENTLY CREATED BY VCF IN MY ENVIRONMENT ############

# NSX-T Segments
resource "nsxt_policy_vlan_segment" "ext_nsxtvlan_seg01" {
  display_name        = "ext-nsxt-vlan-seg01"
  transport_zone_path = data.nsxt_policy_transport_zone.lon5_m01_tz_vlan01.path
  vlan_ids            = ["1672"]

  lifecycle {
    ignore_changes = [tag]
  }
}

data "nsxt_policy_segment_realization" "realization_ext_nsxtvlan_seg01" {
  path = nsxt_policy_vlan_segment.ext_nsxtvlan_seg01.path
}