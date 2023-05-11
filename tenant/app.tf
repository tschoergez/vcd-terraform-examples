## App Deployment
# vApp - three-network-tier vApp with DB, app and load balanced web app
resource "vcd_vapp" "demo_vapp" {
  name = "Empower-App"
}

resource "vcd_vapp_org_network" "demo_vapp_org_net_edge01_routed01" {
  vapp_name        = vcd_vapp.demo_vapp.name
  org_network_name = data.vcd_network_routed_v2.edge01_routed01.name
}

# Virtual machines creation
resource "vcd_vapp_vm" "vapp_xyz_web" {
  count            = 2
  vapp_name        = vcd_vapp.demo_vapp.name
  name             = "web-0${count.index + 1}"
  computer_name    = "web-0${count.index + 1}"
  description      = "Web server ${count.index + 1}"
  memory           = 1024
  cpus             = 1
  cpu_cores        = 1
  os_type          = "ubuntu64Guest"
  hardware_version = "vmx-14"

  network {
    type               = "org"
    name               = data.vcd_network_routed_v2.edge01_routed01.name
    ip_allocation_mode = "POOL"
  }
}

resource "vcd_vapp_vm" "vapp_xyz_db" {
  vapp_name        = vcd_vapp.demo_vapp.name
  name             = "db-01"
  computer_name    = "db-01"
  description      = "DB server"
  memory           = 1024
  cpus             = 1
  cpu_cores        = 1
  os_type          = "ubuntu64Guest"
  hardware_version = "vmx-14"

  network {
    type               = "org"
    name               = data.vcd_network_routed_v2.edge01_routed01.name
    ip_allocation_mode = "POOL"
  }
}

# Security Group(s) / IP Set(s)
resource "vcd_nsxt_security_group" "my_org_network" {
  edge_gateway_id = data.vcd_nsxt_edgegateway.edge01.id

  name        = "app-network"
  description = "Security Group for my application network"

  member_org_network_ids = [data.vcd_network_routed_v2.edge01_routed01.id]
}

resource "vcd_nsxt_ip_set" "db_server" {
  edge_gateway_id = data.vcd_nsxt_edgegateway.edge01.id

  name        = "db-server"
  description = "IP Set containing DB server(s) IP"

  ip_addresses = [vcd_vapp_vm.vapp_xyz_db.network.0.ip]
}

# Firewall Rules
data "vcd_nsxt_network_context_profile" "mysql" {
  context_id = data.vcd_vdc_group.dcgroup01.id
  name       = "MYSQL"
}

data "vcd_nsxt_app_port_profile" "http_default" {
  scope = "SYSTEM"
  name  = "HTTP"
}

resource "vcd_nsxt_distributed_firewall" "dcgroup01_dfw" {
  vdc_group_id = data.vcd_vdc_group.dcgroup01.id

  rule {
    name    = "Allow HTTP In"
    action  = "ALLOW"
    destination_ids = [vcd_nsxt_security_group.my_org_network.id]
    app_port_profile_ids   = [data.vcd_nsxt_app_port_profile.http_default.id]
  }

  rule {
    name        = "Allow MySQL traffic"
    action      = "ALLOW"
    source_ids = [vcd_nsxt_security_group.my_org_network.id]
    destination_ids = [vcd_nsxt_ip_set.db_server.id]
    network_context_profile_ids = [data.vcd_nsxt_network_context_profile.mysql.id]
  }

  rule {
    name        = "Drop All"
    action      = "DROP"
    ip_protocol = "IPV4"
    logging = true
  }
}

# Load Balancing
data "vcd_nsxt_alb_edgegateway_service_engine_group" "edge01_seg" {
  edge_gateway_id           = data.vcd_nsxt_edgegateway.edge01.id
  service_engine_group_name = "seg-ded-nm01"
}

resource "vcd_nsxt_alb_pool" "web_servers" {
  name            = "pool-web"
  edge_gateway_id = data.vcd_nsxt_edgegateway.edge01.id

  algorithm                  = "LEAST_LOAD"
  default_port               = 80
  graceful_timeout_period    = "0"
  passive_monitoring_enabled = false

  health_monitor {
    type = "PING"
  }

  persistence_profile {
    type = "CLIENT_IP"
  }

  member {
    ip_address = vcd_vapp_vm.vapp_xyz_web[0].network.0.ip
    port       = 80
  }

  member {
    ip_address = vcd_vapp_vm.vapp_xyz_web[1].network.0.ip
    port       = 80
  }
}

resource "vcd_nsxt_alb_virtual_service" "vip_demo" {
  name            = "vs_demo"
  edge_gateway_id = data.vcd_nsxt_edgegateway.edge01.id

  pool_id                  = vcd_nsxt_alb_pool.web_servers.id
  service_engine_group_id  = data.vcd_nsxt_alb_edgegateway_service_engine_group.edge01_seg.service_engine_group_id
  virtual_ip_address       = tolist(data.vcd_nsxt_edgegateway.edge01.subnet)[0].primary_ip

  application_profile_type = "HTTP"
  
  service_port {
    start_port = 80
    type       = "TCP_PROXY"
  }
}