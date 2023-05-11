data "vcd_vdc_group" "dcgroup01" {
  org  = "Cyberdyne"
  name = "cyberdyne-dcgroup01"
}

data "vcd_nsxt_edgegateway" "edge01" {
  owner_id = data.vcd_vdc_group.dcgroup01.id
  name     = "cyberdyne-edge01"
}

data "vcd_network_routed_v2" "edge01_routed01" {
  edge_gateway_id = data.vcd_nsxt_edgegateway.edge01.id
  name            = "routed_192.168.10.0"
}