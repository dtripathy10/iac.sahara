## Node Group

A node group is a set of Kubernetes worker nodes that share the same configuration and are managed as one unit. On AWS, that is typically:

A launch template (or older launch configuration) that defines the instance type, AMI, disk, security groups, IAM role, user data/bootstrap script, and labels or taints.
An Auto Scaling Group that uses that template and keeps a min/max/desired number of instances running, spread across the subnets or AZs you choose.

Every node in the group is identical, which is why Cluster Autoscaler has to pick a group rather than a specific instance type. To scale up, it just raises the ASG's desired count.

In EKS specifically, there are a few flavors:

- **Managed node groups:** EKS creates and manages the ASG and launch template for you, and handles things like rolling AMI updates and draining on termination.
- **Self-managed node groups:** you create the ASG and launch template yourself and join the nodes to the cluster.
- **Fargate:** no node group at all, since AWS runs the pods on its own infrastructure.

A cluster usually needs several groups (e.g. general-purpose, memory-heavy, GPU, ARM, spot), which is the config overhead Karpenter avoids. It skips the ASG layer and launches EC2 instances directly, picking the type per workload.