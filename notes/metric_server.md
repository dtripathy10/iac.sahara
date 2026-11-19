Metrics Server is a lightweight Kubernetes add-on that collects **resource usage data (CPU and memory)** from every node and pod in your cluster and exposes it through the Kubernetes API.

## How it works

1. Each node runs a kubelet, which tracks the CPU and memory usage of the pods on that node.
2. Metrics Server periodically scrapes those numbers from every kubelet (roughly every 15 seconds).
3. It keeps the latest values **in memory** and serves them through the `metrics.k8s.io` API, which is the API your HPA was failing to reach.

## What uses it

- **Horizontal Pod Autoscaler (HPA):** reads current CPU/memory usage to decide whether to add or remove pod replicas.
- **Vertical Pod Autoscaler (VPA):** uses it (along with other data) to recommend resource requests.
- **`kubectl top nodes` / `kubectl top pods`:** the quick way to see live usage.

## What it is *not*

- **Not a monitoring system.** It holds only the most recent snapshot, with no history, no graphs, and no alerting. For that you'd use Prometheus, CloudWatch Container Insights, Datadog, etc.
- **Not for custom metrics.** It only provides CPU and memory. Scaling on things like queue length or requests per second needs something like Prometheus Adapter or KEDA.

## Why it matters for your error

Kubernetes doesn't ship with Metrics Server enabled, and EKS doesn't install it by default. Without it, the `metrics.k8s.io` API doesn't exist, so the HPA can't read CPU utilization and reports "the server could not find the requested resource". Installing it (as in my previous message) is the fix.