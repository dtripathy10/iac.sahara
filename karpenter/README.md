# Karpenter on EKS

This is an opt-in setup for the existing EKS cluster. Terraform provisions the
AWS resources; Kustomize renders the controller and CRD Helm charts and the
NodePool and EC2NodeClass for kubectl to apply. The existing managed node group
remains the controller's bootstrap capacity. Keep at least one managed node
running; the chart's default affinity prevents the controller from running on
Karpenter nodes.

Terraform provisions the node role, scoped controller policies, interruption
queue, and EventBridge rules based on the upstream Karpenter v1.15.3 template.
It also creates the Pod Identity association and node access entry, and adds
discovery tags to private subnets and the EKS cluster security group. The
Terraform execution role needs IAM, EKS, EC2, SQS and EventBridge permissions
to create these resources. The controller policy templates are in
`modules/karpenter/policies/`.

If the earlier CloudFormation stack was already deployed, do not apply this
configuration directly: Terraform would try to create resources with names
already owned by the stack and destroy the stack. Migrate ownership and import
the existing resources first, or remove the old setup during a maintenance
window after safely terminating Karpenter nodes.

## Install

1. Enable Karpenter in your Terraform variables, review the plan, and apply:

   ```powershell
   terraform plan -var 'enable_karpenter=true'
   terraform apply -var 'enable_karpenter=true'
   ```

   Keep `enable_karpenter = true` in your own tfvars for later applies.
   The EKS Pod Identity agent must be running on the managed nodes.

2. The defaults in `values.yaml` and `nodeclass.yaml` target `demo-eks` in the
   Terraform provider's region. If using another cluster, change the cluster
   name in both files, including `KarpenterNodeRole-<cluster-name>`, discovery
   tags and the interruption queue name. Use the same kubeconfig and AWS region
   as the Terraform deployment.

   `al2023@v20261119` is an x86_64 AMI release for the default Kubernetes 1.37
   cluster. For another Kubernetes version or region, select a compatible,
   tested AL2023 alias. Pin an AMI release rather than using `latest` to avoid
   unexpected node replacement on AMI updates.

3. Render the charts and node resources together with Helm 3 and kubectl.
   The pinned Karpenter v1.15.3 charts are included in `charts/`, so the
   Kustomize v5.0.4 bundled with kubectl can render them without pulling OCI
   charts. From the repository root, apply the rendered CRDs first and wait
   for them before applying the complete manifest, including the node resources.
   Do not pipe the initial render directly to `kubectl apply`: the custom
   resources require their CRDs to be established first.

   ```powershell
   $manifest = kubectl kustomize --enable-helm .\karpenter
   if ($LASTEXITCODE -ne 0) { throw 'Karpenter rendering failed.' }
   $documents = ($manifest -join "`n") -split '(?m)^---[ \t]*\r?$'
   $crds = @($documents | Where-Object { $_ -match '(?m)^kind: CustomResourceDefinition\r?$' })
   if ($crds.Count -eq 0) { throw 'No Karpenter CRDs were rendered.' }
   ($crds -join "`n---`n") | kubectl apply --server-side --field-manager=karpenter-kustomize -f -
   if ($LASTEXITCODE -ne 0) { throw 'Karpenter CRD apply failed.' }
   kubectl wait --for=condition=Established --timeout=90s crd/nodepools.karpenter.sh crd/ec2nodeclasses.karpenter.k8s.aws
   if ($LASTEXITCODE -ne 0) { throw 'Karpenter CRDs did not become ready.' }
   $manifest | kubectl apply --server-side --field-manager=karpenter-kustomize -f -
   if ($LASTEXITCODE -ne 0) { throw 'Karpenter manifest apply failed.' }
   kubectl rollout status deployment/karpenter -n kube-system --timeout=180s
   if ($LASTEXITCODE -ne 0) { throw 'Karpenter controller did not become ready.' }
   kubectl get nodepools,ec2nodeclasses
   ```

   Kustomize renders the Helm charts but does not create Helm releases. The
   CRDs are managed via server-side apply, not Helm's CRD lifecycle. If Helm
   releases already exist, plan their migration before switching ownership;
   do not uninstall a release that still owns live resources.
   Upgrade the CRD chart, controller chart and AWS permissions together, and
   check the [compatibility matrix](https://karpenter.sh/docs/upgrading/compatibility/)
   and upgrade guide before replacing both charts in `charts/` with matching
   versions from `oci://public.ecr.aws/karpenter`.
   The vendored v1.15.3 OCI digests are
   `sha256:8b4d5fa822641607b67f3e559d488b8ee83cd7788b08d49dbe92b54e54f436ea`
   for `karpenter-crd` and
   `sha256:7fadb5574dc4cdbdbac29658357289be48e98ac37685114a9b87223328fe56ed`
   for `karpenter`.

The example NodePool launches on-demand x86_64 Linux instances with a total
limit of 32 CPUs, and consolidates empty or underutilized nodes after five
minutes. Review limits, disruption settings, instance requirements and
controller resources for your workload and budget before installation.
Cluster Autoscaler and Karpenter can both respond to the same pending pods;
disable Cluster Autoscaler or use workload constraints and separate capacity
to avoid competing scale-ups. Karpenter does not manage existing managed node
group instances.

Check provisioning and consolidation with:

```powershell
kubectl get nodeclaims
kubectl get nodes -L karpenter.sh/nodepool
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -c controller -f
```

Before disabling or destroying the Terraform infrastructure, remove Karpenter
workloads and the NodePool while the controller is running, and wait for its
NodeClaims and instances to be terminated. Then remove the NodeClass and Helm
chart resources rendered by Kustomize. Otherwise, nodes or finalizers can be
left behind.
