# EKS on AWS – modular Terraform

## Layout

```
.
├── versions.tf              # Terraform + provider constraints
├── providers.tf             # AWS provider (default tags)
├── main.tf                  # Wires the modules together
├── variables.tf
├── outputs.tf
├── terraform.tfvars.example
└── modules/
    ├── vpc/                 # VPC, public/private subnets, IGW, NAT, routes
    ├── iam/                 # Cluster role + node role
    ├── eks/                 # Cluster, KMS secrets encryption, logs, OIDC (IRSA)
    ├── node_group/          # Managed node groups (for_each over a map)
    ├── addons/              # vpc-cni, kube-proxy, coredns (created after nodes)
    └── ecr/                 # Image repositories for application microservices
```

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init
terraform plan
terraform apply

# Connect kubectl
aws eks update-kubeconfig --region ap-southeast-2 --name demo-eks
kubectl get nodes
```

## Notes

- Nodes run in private subnets behind NAT. `single_nat_gateway = true` is cheaper;
  set it to `false` for one NAT per AZ in production.
- Restrict `public_access_cidrs` (default is open to the world) or disable the
  public endpoint and use a VPN/bastion.
- Auth mode is `API_AND_CONFIG_MAP`; the identity that runs `terraform apply`
  gets cluster-admin automatically. Add others via EKS access entries.
- Add node groups by adding keys to the `node_groups` map; taints, labels and
  Spot capacity are supported.
- The example uses one `t3.micro` on-demand node as a low-cost option. Check
  your AWS account's Free Tier eligibility and regional availability before
  applying; EKS control-plane, NAT gateway, and other infrastructure charges
  are separate, so this configuration is not guaranteed to be free.
- ECR repositories for the sample microservices are created by Terraform and
  are listed in the `ecr_repository_urls` output. Images are encrypted at rest
  and scanned on push. Terraform will not delete repositories containing images
  unless `force_delete` is enabled in the ECR module.
- `desired_size` is ignored after creation so an autoscaler can manage it.
- Run `terraform destroy` to clean up (NAT gateways and the cluster cost money).
  ECR repositories containing images are retained by default; empty them or
  explicitly enable `force_delete` in the ECR module before deleting them.
