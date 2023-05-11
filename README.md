# Beyond Networking Automation with VCD, NSX-T and Terraform

Welcome! \o/

This repository contains the Terraform configurations used for the demos in **Beyond Networking Automation with VCD, NSX-T and Terraform** (session **TL3_CP_8114** @ Empower 2022).

The `/provider` folder covers both **demo #1** and **demo #2**:

* Demo 1: as a system administrator, I create and manage all networking cloud resources
  * This demo combines 4 Terraform providers to construct and configures all required vSphere, NSX-T, and NSX Advanced Load Balancer (Avi) resources to build the cloud infrastructure in VMware Cloud Director.
* Demo 2: as a system administrator, I onboard a new tenant (creating a new )
  * This demo focuses on the tasks required to onboard a new tenant. It can also be extrapolated to add new objects (organization virtual data centers, edge gateways, organization VDC networks, etc.) for said tenant.

The `/tenant` folder contains the Terraform configuration for **demo #3**: as a tenant administrator, I create and secure workloads (vApps, VMs, firewall rules, etc.)

```Adjust the connection settings (in `terraform.tfvars` files) and the object names in the .tf files to match your environment.```

For more details, read the Terraform provider documentation:

* [VMware Cloud Director Terraform Provider](https://registry.terraform.io/providers/vmware/vcd)
* [NSX-T Terraform Provider](https://registry.terraform.io/providers/vmware/nsxt)
* [NSX Advanced Load Balancer (Avi) Terraform Provider](https://registry.terraform.io/providers/vmware/avi)

## Considerations

* As of May 2022, the VMware Cloud Director Terraform provider do not support [data center groups](https://registry.terraform.io/providers/vmware/vcd/latest/docs/guides/vdc_groups) for all NSX-T edge gateway child resources. It should be fixed soon; [PR #841](https://github.com/vmware/terraform-provider-vcd/pull/841) tracks this effort.
* For the sake of time, I create empty VMs in the demo #3. However, it's easy to upload an OVA (or an ISO) and build vApps and VMs with it.
