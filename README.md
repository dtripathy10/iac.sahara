# GitOps workflow

## One-time cluster setup

1. Apply Terraform infrastructure, then connect kubectl:

   ```bash
   terraform init
   terraform apply
   aws eks update-kubeconfig --region ap-southeast-2 --name demo-eks
   ```

2. Set the cluster name, region, and VPC ID in
   `apps/platform/components/aws-load-balancer-controller/overlays/dev/values.yaml`.
3. Install Argo CD with the `dev` Helm overlay. Instructions are in
   [apps/platform/README.md](./apps/platform/README.md).
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
   Controller, ingresses, namespace settings, and its own Helm release.

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
kubectl port-forward -n argocd svc/argocd-server 8443:443
```

Open Argo CD at `https://localhost:8443`. Change its generated initial admin
password after first login.
