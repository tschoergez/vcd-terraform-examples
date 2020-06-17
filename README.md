# vcd-terraform-examples
Examples for the VCD Terraform Provider

This repository contains some example files for the Terraform Provider for VMware Cloud Director.
The /provider example onboards a new tenant: Creating a new Org, OrgVDC, Organization Administrator user, Edge Gateway
The /tenant example deploys a multi-tier vApp. It uploads a photon.iso file to the catalog, creates some Org Networks, 
deploys the template multiple times (to mimic the different components of the App), and configures firewall and load balancer
on the Org Network Edge Gateway.

To use them, adjust the connection settings (in terraform.tfvars files) and the object names in the .tf files to match your environment.

For more details, read the documentation on
https://www.terraform.io/docs/providers/vcd/index.html
