# GitOps workflow

## One-time cluster setup

To use Argo CD managed by EKS, configure these Terraform variables before
applying. AWS Identity Center must already be set up, and the admin user must
exist in its Identity Store. The `identity_center` module discovers the
instance and resolves the user's ID from the supplied username:

```hcl
enable_managed_argocd     = true
argocd_admin_user_name    = "your-identity-center-username"
# Set this only if Identity Center is in a different Region than EKS.
# argocd_identity_center_region = "your-identity-center-region"
```

Set `argocd_identity_center_region` if the Identity Center instance is in a
different Region from the cluster. The capability role has no AWS permissions
by default; add narrowly scoped permissions only if Argo CD needs access to
AWS services such as Secrets Manager or CodeConnections. The Terraform
execution identity needs permission to list Identity Center instances and read
the selected user. Exactly one Identity Center instance must be available in
the configured Region. If none is found, set
`argocd_identity_center_region` to the Region where Identity Center is
configured; if you have not set up Identity Center, enable it in the AWS
Identity Center console and provision or sync the admin user there.

1. Apply Terraform infrastructure, then connect kubectl:

   ```bash
   terraform init
   terraform apply
   aws eks update-kubeconfig --region ap-southeast-2 --name demo-eks
   ```

   Terraform also provisions Cluster Autoscaler permissions through EKS Pod
   Identity for the `kube-system/cluster-autoscaler` service account. Deploy the
   autoscaler with that service account to use the role. Its standalone
   Kustomize/Helm deployment is in [cluster-autoscaler/](./cluster-autoscaler/);
   see that folder's README for the install command and settings.

   Karpenter is an optional alternative for provisioning workload nodes. See
   [karpenter/](./karpenter/) for infrastructure and installation instructions.

2. Set the cluster name, region, and VPC ID in
   `apps/platform/components/aws-load-balancer-controller/overlays/dev/values.yaml`.
3. If `enable_managed_argocd` is `false`, install Argo CD with the `dev` Helm
   overlay as described in [apps/platform/README.md](./apps/platform/README.md).
   If it is `true`, do not install the Helm-based Argo CD release; EKS creates
   and operates the Argo CD capability instead.
4. Set the Git repository URL and branch in:
   - `apps/gitops/bootstrap/demo-eks.yaml`
   - `apps/gitops/clusters/demo-eks/repo-config.yaml`
5. Create the `demo-apps-dev`, `demo-apps-qa`, and `demo-apps-prod` namespaces
   and a `products-db` secret in each. Never commit DB credentials.
6. Update GitOps image and AWS security-group settings, then commit and push:

   ```bash
   cd apps
   scripts/build-push.sh <image-tag>
   scripts/deploy.sh dev <image-tag> <ecr-registry>
   git add services platform gitops
   git commit -m "Configure GitOps"
   git push
   ```

7. Apply the cluster root Application once:

   ```bash
kubectl apply -f ./gitops/bootstrap/demo-eks.yaml
   ```

   Argo CD now reconciles all three environments, the AWS Load Balancer
   Controller, ingresses, and namespace settings. With self-managed Argo CD,
   it also reconciles its own Helm release.

When the managed capability is enabled, get its server URL with:

```bash
terraform output -raw argocd_server_url
```

Use the Amazon EKS console or AWS Identity Center to access the UI. The
capability creates Argo CD, but you still need to configure repositories and
create Argo CD `Application` resources to deploy workloads.

## Application release

Build and push service images, set the desired image tag for an environment,
and push the changed manifests. Argo CD deploys the Git commit automatically:

```bash
cd apps
scripts/build-push.sh <image-tag>
scripts/deploy.sh dev <image-tag> <ecr-registry>
git add services platform gitops
git commit -m "Deploy dev image <image-tag>"
git push
```

Use `qa` or `prod` to release to another environment. Roll back by reverting
the image-tag commit. `scripts/deploy.sh` updates tracked manifests only; it
does not apply workloads directly.

## Local access

```bash
kubectl port-forward -n demo-apps-dev svc/products-api 8080:80
```

For self-managed Argo CD, port-forward its service separately:

```bash
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

Open it at `https://localhost:8443` and change its generated initial admin
password after first login. For managed Argo CD, use the `argocd_server_url`
Terraform output instead.
