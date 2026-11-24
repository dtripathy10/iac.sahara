# Cluster Autoscaler

This folder renders the upstream Cluster Autoscaler Helm chart with Kustomize.
Terraform must be applied first so the node-group discovery tags and the
`kube-system/cluster-autoscaler` EKS Pod Identity association are present.

Before installing, update `values.yaml` so `awsRegion` and
`autoDiscovery.clusterName` match the EKS cluster, and set `image.tag` to the
same Kubernetes minor version as the cluster.

From the repository root, render and apply the chart with:

```powershell
kubectl kustomize --enable-helm .\cluster-autoscaler | kubectl apply -f -
```

This uses kubectl's bundled Kustomize renderer; Helm must also be installed
because Kustomize uses it to render the chart. `--enable-helm` is a flag for
`kubectl kustomize`, not `kubectl apply`.
