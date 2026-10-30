# GKE on Google Cloud with Terraform

This starter configuration creates a VPC-native, **zonal** GKE Standard cluster in Seoul (`asia-northeast3-a`) with one Google-managed control plane and a worker node pool of two `e2-micro` VMs.

GKE manages the Kubernetes control plane; it is not a VM that you size or administer. A zonal cluster gives you one control plane instance. Worker nodes are the two VMs in the managed node pool.

## Prerequisites

- A Google Cloud project with billing enabled.
- Terraform 1.5+ and `gcloud` installed.
- Credentials configured, for example with `gcloud auth application-default login`, and permissions to enable APIs and create GKE, Compute Engine, and network resources.

## Deploy

```sh
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set project_id.
terraform init
terraform plan
terraform apply
```

After apply, use the `get_credentials_command` output to configure `kubectl`.

To remove the resources, run `terraform destroy`. API services are intentionally left enabled when Terraform is destroyed.

## Notes

- The cluster uses a custom VPC, private Google access, VPC-native pod/service ranges, and the Regular release channel.
- The worker pool uses two `e2-micro` nodes by default, the smallest E2 shared-core VM size (0.25 sustained vCPU and 1 GiB memory). This is suitable for lightweight learning exercises, but the limited resources can make Kubernetes components and workloads slow or unstable. Change `machine_type` to `e2-small` if the cluster struggles.
- The control plane endpoint and worker nodes use GKE defaults; this starter does not configure a private control plane, restricted authorized networks, autoscaling, or a Cloud NAT gateway.
- This is a single-zone starter configuration. A zonal cluster has lower control-plane availability than a regional cluster. Regional clusters distribute the managed control plane across zones, so they do not map to “one master VM.”
