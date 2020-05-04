# Create a catalog, opload photon ovs, create a new vApp
# Photon OVA URL: http://dl.bintray.com/vmware/photon/3.0/GA/ova/photon-hw11-3.0-26156e2.ova ,download to local system

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
variable "org_vdc" {}
variable "vcd_max_retry_timeout" {
    default = 60
}

# Connection for the VMware vCloud Director Provider
provider "vcd" {
  url      = var.vcd_url
  user     = var.vcd_user
  password = var.vcd_pass
  org      = var.org_name
  vdc      = var.org_vdc

  max_retry_timeout    = "120"
  allow_unverified_ssl = "true"

  logging = "true"
}

# Common variables
variable "edge_gateway" {
  default = "T1-ESG"
}

variable "edge_gateway_ip" {
  default = "192.168.100.3" # IP address of edge gateway uplink interface
}

# Result is a three-network-tier application:
# 1. Web page on http://192.168.100.3
# 2. Above page calling a "REST" application
# 3. Above "REST" application calling a "database" server

# Catalog
resource "vcd_catalog" "demo_catalog" {
  name        = "OperatingSystems"
  description = "OS templates"

  delete_force     = "true"
  delete_recursive = "true"
}

# Linux OVA
resource "vcd_catalog_item" "demo_linux" {
  catalog     = vcd_catalog.demo_catalog.name
  name        = "Linux"
  description = "Linux VM"

  ova_path = "c:/photon-hw11-3.0-26156e2.ova"

  show_upload_progress = true
}

# Org Routed Network - DB
resource "vcd_network_routed" "demo_routed_net_db" {
  name         = "demo-net-db"
  edge_gateway = "${var.edge_gateway}"

  gateway = "192.168.2.1"

  static_ip_pool {
    start_address = "192.168.2.2"
    end_address   = "192.168.2.100"
  }
}

# Org Routed Network - App
resource "vcd_network_routed" "demo_routed_net_app" {
  name         = "demo-net-app"
  edge_gateway = "${var.edge_gateway}"

  gateway = "192.168.1.1"

  static_ip_pool {
    start_address = "192.168.1.2"
    end_address   = "192.168.1.100"
  }
}

# Org Routed Network - Web
resource "vcd_network_routed" "demo_routed_net_web" {
  name         = "demo-net-web"
  edge_gateway = "${var.edge_gateway}"

  gateway = "192.168.0.1"

  static_ip_pool {
    start_address = "192.168.0.2"
    end_address   = "192.168.0.100"
  }
}

# vApp - three-network-tier vApp with DB, app and load balanced web app
resource "vcd_vapp" "demo_vapp" {
  name        = "demo-web"
  description = "Three-network-tier vApp with DB, app and load balanced web app"

  depends_on = ["vcd_network_routed.demo_routed_net_web"]
}


# VM - database server
resource "vcd_vapp_vm" "demo_vm_db" {
  vapp_name     = "${vcd_vapp.demo_vapp.name}"
  name          = "demo-vm-db"
  catalog_name  = "${vcd_catalog.demo_catalog.name}"
  template_name = "${vcd_catalog_item.demo_linux.name}"
  memory        = 384
  cpus          = 1

  network {
    type               = "org"
    name               = "${vcd_network_routed.demo_routed_net_db.name}"
    ip_allocation_mode = "POOL"
  }

  # Imitate DBMS server on 3306 port
  initscript = "mkdir /tmp/node && cd /tmp/node && echo 'My DBMS server' > dbms && /bin/systemctl stop iptables && /usr/bin/python3 -m http.server 3306 &"

  accept_all_eulas = "true"
}

# VM - internal application
resource "vcd_vapp_vm" "demo_vm_app" {
  vapp_name     = "${vcd_vapp.demo_vapp.name}"
  name          = "demo-vm-app"
  catalog_name  = "${vcd_catalog.demo_catalog.name}"
  template_name = "${vcd_catalog_item.demo_linux.name}"
  memory        = 384
  cpus          = 1

  network {
    type               = "org"
    name               = "${vcd_network_routed.demo_routed_net_app.name}"
    ip_allocation_mode = "POOL"
  }

  # Imitate REST application server on default 8888 port
  initscript = "mkdir /tmp/node && cd /tmp/node && echo 'My REST API application' > index.html && /bin/systemctl stop iptables && /usr/bin/python3 -m http.server 8888 &"

  accept_all_eulas = "true"
}

# SNAT rule to let the VMs' traffic out
resource "vcd_snat" "demo_snat_app" {
  edge_gateway = "${var.edge_gateway}"

  external_ip = "${var.edge_gateway_ip}/32"
  internal_ip = "192.168.1.2/32"
}

# DNAT rule to host REST API to the web client
resource "vcd_dnat" "demo_dnat_app_rest" {
  edge_gateway = "${var.edge_gateway}"

  external_ip     = "${var.edge_gateway_ip}/32"
  port            = 8888
  internal_ip     = "${vcd_vapp_vm.demo_vm_app.network.0.ip}/32"
  translated_port = 8888
}

# DNAT rule to SSH the VM from the outside
resource "vcd_dnat" "demo_dnat_app_ssh" {
  edge_gateway = "${var.edge_gateway}"

  external_ip     = "${var.edge_gateway_ip}/32"
  port            = 2227
  internal_ip     = "${vcd_vapp_vm.demo_vm_app.network.0.ip}/32"
  translated_port = 22
}

# VM - two web server instances
resource "vcd_vapp_vm" "demo_vm_web" {
  vapp_name     = "${vcd_vapp.demo_vapp.name}"
  name          = "demo-vm-web-${count.index}"
  catalog_name  = "${vcd_catalog.demo_catalog.name}"
  template_name = "${vcd_catalog_item.demo_linux.name}"
  memory        = 384
  cpus          = 1

  count = 2

  network {
    type               = "org"
    name               = "${vcd_network_routed.demo_routed_net_web.name}"
    ip_allocation_mode = "POOL"
  }

  initscript = "mkdir /tmp/node && cd /tmp/node && echo 'server-${count.index} <iframe src=\"http://${var.edge_gateway_ip}:8888\">\\</iframe>' > index.html && /bin/systemctl stop iptables && /usr/bin/python3 -m http.server 80 &"

  accept_all_eulas = "true"
}

# Load Balancer configuration
resource "vcd_lb_app_profile" "lb_profile" {
  edge_gateway = "${var.edge_gateway}"
  name         = "http-app-profile"
  type         = "http"
}

resource "vcd_lb_service_monitor" "lb_monitor" {
  edge_gateway = "${var.edge_gateway}"
  name         = "demo-http-monitor"
  interval     = "5"
  timeout      = "20"
  max_retries  = "3"
  type         = "http"
  method       = "GET"
}

resource "vcd_lb_server_pool" "lb_pool" {
  edge_gateway        = "${var.edge_gateway}"
  name                = "web-servers"
  description         = "description"
  algorithm           = "round-robin"
  enable_transparency = "true"
  monitor_id          = "${vcd_lb_service_monitor.lb_monitor.id}"

  member {
    condition    = "enabled"
    name         = "member1"
    ip_address   = "${vcd_vapp_vm.demo_vm_web[0].network.0.ip}"
    port         = 80
    monitor_port = 80
    weight       = 1
  }

  member {
    condition    = "enabled"
    name         = "member2"
    ip_address   = "${vcd_vapp_vm.demo_vm_web[1].network.0.ip}"
    port         = 80
    monitor_port = 80
    weight       = 2
  }
}

resource "vcd_lb_virtual_server" "lb_virtual_server" {
  edge_gateway   = "${var.edge_gateway}"
  ip_address     = "${var.edge_gateway_ip}"
  name           = "demo-virtual-server"
  protocol       = "http"
  port           = 80
  app_profile_id = "${vcd_lb_app_profile.lb_profile.id}"
  server_pool_id = "${vcd_lb_server_pool.lb_pool.id}"

  provisioner "local-exec" {
    command = "echo ${var.edge_gateway_ip} > edge_ip.txt"
  }
}

resource "vcd_firewall_rules" "demo-fw" {
  edge_gateway   = "${var.edge_gateway}"
  default_action = "drop"

  rule {
    description      = "allow-web"
    policy           = "allow"
    protocol         = "tcp"
    destination_port = "${vcd_lb_virtual_server.lb_virtual_server.port}"
    destination_ip   = "${vcd_lb_virtual_server.lb_virtual_server.ip_address}"
    source_port      = "any"
    source_ip        = "any"
  }

  rule {
    description      = "allow-app"
    policy           = "allow"
    protocol         = "tcp"
    destination_port = "${vcd_dnat.demo_dnat_app_rest.port}"
    destination_ip   = "${var.edge_gateway_ip}"
    source_port      = "any"
    source_ip        = "any"
  }

  rule {
    description      = "allow-app"
    policy           = "allow"
    protocol         = "tcp"
    destination_port = "${vcd_dnat.demo_dnat_app_ssh.port}"
    destination_ip   = "${var.edge_gateway_ip}"
    source_port      = "any"
    source_ip        = "any"
  }

  rule {
    description      = "allow-app-outbound"
    policy           = "allow"
    protocol         = "any"
    destination_port = "any"
    destination_ip   = "any"
    source_port      = "any"
    source_ip        = "${vcd_vapp_vm.demo_vm_app.network.0.ip}"
  }
}