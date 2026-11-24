# Kubernetes Cluster Autoscaler: A Practical Tutorial

## Overview

Cluster Autoscaler (CA) adds worker nodes when pods cannot be scheduled and removes nodes that sit underused. It does this by resizing **pre-defined node groups**, such as AWS Auto Scaling Groups (ASGs), GCE managed instance groups or Azure VM Scale Sets.

The key properties to remember:

- It reacts to **unschedulable (Pending) pods**, not to CPU or memory graphs.
- It scales a node group by raising or lowering its desired count. The cloud provider launches or terminates the machines.
- Every node in a group is identical, so you typically maintain several groups (sizes, architectures, spot vs on-demand, GPU).
- It is mature, cloud-agnostic and supported on nearly every provider.
- Scale-up is slower than Karpenter because it goes through the ASG layer and a periodic scan loop.

This tutorial covers node groups, how CA decides when and where to scale, what you write on the pod side, scale-down, and how CA compares with Karpenter.

## What is a node group?

A node group is a set of identical worker nodes managed as one unit. On AWS it is a **launch template** plus an **Auto Scaling Group**, and that pairing is the correct mental model.

- **Launch template:** instance type, AMI, disk, security groups, IAM role, user data/bootstrap script, plus the labels and taints the nodes register with.
- **Auto Scaling Group:** keeps a min, max and desired number of instances running, spread across the subnets or AZs you choose.

Because every node in the group is identical, CA cannot choose an instance type. It can only choose *a group* and change its desired count.

### EKS flavors

| Flavor | Who manages the ASG | Notes |
| --- | --- | --- |
| Managed node group | EKS | Creates the ASG and launch template, handles rolling AMI updates and draining on termination |
| Self-managed node group | You | You build the ASG and launch template and join nodes to the cluster |
| Fargate | AWS | No node group at all; AWS runs each pod on its own infrastructure |

A real cluster usually needs several groups (general purpose, memory-heavy, GPU, ARM, spot). Maintaining them is the configuration overhead that Karpenter was built to remove.

## How scale-up works

CA scales up only when a pod is Pending because no existing node can hold it. The sequence is:

1. You create a pod with **resource requests**.
2. The Kubernetes scheduler tries to place it on an existing node with free capacity.
3. If nothing fits, the pod goes `Pending` and is marked unschedulable.
4. CA notices it on its next scan loop (every 10 seconds by default).
5. For each node group, CA builds a template node from the group's launch template and checks which pending pods would fit on it.
6. It estimates how many nodes of that type are needed, then asks the **expander** to choose among the viable groups.
7. CA raises the chosen group's desired count. The cloud provider launches the instance.
8. The node joins, and the scheduler places the pod on it.

The core of step 5 to 7 looks like this. The code is simplified from the upstream `kubernetes/autoscaler` repository, so exact names and signatures vary by version.

```go
for _, nodeGroup := range nodeGroups {
    // Skip groups at max size or in backoff
    if size >= nodeGroup.MaxSize() { continue }

    // Template node built from the group's launch template
    nodeInfo := nodeInfos[nodeGroup.Id()]

    // Run scheduler predicates: which pending pods would fit on this node?
    podsThatFit := []*apiv1.Pod{}
    for _, pod := range unschedulablePods {
        if predicateChecker.CheckPredicates(pod, nodeInfo) == nil {
            podsThatFit = append(podsThatFit, pod)
        }
    }
    if len(podsThatFit) == 0 { continue }

    // How many nodes of this type are needed to hold them?
    nodeCount := estimator.Estimate(podsThatFit, nodeInfo)

    options = append(options, expander.Option{
        NodeGroup: nodeGroup,
        NodeCount: nodeCount,
        Pods:      podsThatFit,
    })
}

// Let the configured expander choose
best := expanderStrategy.BestOption(options, nodeInfos)

// Raise the ASG desired count
best.NodeGroup.IncreaseSize(best.NodeCount)
```

Because CA works from pod **requests** and node group templates, wrong or missing requests lead directly to wrong scaling decisions.

## How CA picks a node group: expanders

When several node groups could fit the pending pods, a pluggable **expander** chooses one. The default is `random`, which often gives mediocre results unless you configure something better.

```go
type Strategy interface {
    BestOption(options []Option, nodeInfo map[string]*NodeInfo) *Option
}
```

An example strategy, `least-waste`, scores each option by the CPU and memory left idle after placing the pods:

```go
func (l *leastWaste) BestOption(options []Option, nodeInfo map[string]*NodeInfo) *Option {
    var best *Option
    bestScore := math.MaxFloat64

    for i, opt := range options {
        node := nodeInfo[opt.NodeGroup.Id()].Node()
        podCPU, podMem := sumRequests(opt.Pods)

        nodeCPU := node.Status.Allocatable.Cpu().MilliValue() * int64(opt.NodeCount)
        nodeMem := node.Status.Allocatable.Memory().Value() * int64(opt.NodeCount)

        // Fraction of CPU and memory left unused after placing the pods
        cpuWaste := float64(nodeCPU-podCPU) / float64(nodeCPU)
        memWaste := float64(nodeMem-podMem) / float64(nodeMem)
        score := cpuWaste + memWaste

        if score < bestScore {
            bestScore = score
            best = &options[i]
        }
    }
    return best
}
```

### Built-in expanders

Set one with `--expander=<name>`.

| Expander | Picks the group that... |
| --- | --- |
| `random` (default) | is chosen at random from the viable ones |
| `most-pods` | would schedule the most pending pods |
| `least-waste` | leaves the least idle CPU and memory |
| `price` | is cheapest (GCE and some other providers) |
| `priority` | ranks highest in a ConfigMap you define |
| `grpc` | is chosen by an external service |

You can chain expanders so later ones break ties, for example `--expander=priority,least-waste`.

## What you write on the pod side

You never name a node group or an ASG in a pod spec. You describe what the pod needs, and CA works out the rest.

### Default: just set resource requests

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: my-app:latest
      resources:
        requests:
          cpu: "2"
          memory: 4Gi
```

The requests drive scaling. If they are missing or inaccurate, CA makes bad decisions.

### Steering to a kind of node (indirectly)

If you need GPU, spot, ARM or a dedicated team's nodes, steer with **labels and taints**, not group names. Each node group's template carries labels and taints, and CA reads them when deciding which group could satisfy the pod.

```yaml
spec:
  nodeSelector:
    workload-type: gpu          # label set on the GPU node group
  tolerations:
    - key: "nvidia.com/gpu"     # taint set on the GPU node group
      operator: "Exists"
      effect: "NoSchedule"
  containers:
    - name: trainer
      image: trainer:latest
      resources:
        limits:
          nvidia.com/gpu: 1
```

### nodeSelector, tolerations and nodeAffinity in short

| Field | What it does | Key point |
| --- | --- | --- |
| `nodeSelector` | Pod runs only on nodes whose labels match exactly | Simplest hard constraint; exact match only |
| `tolerations` | Lets a pod run on nodes with a matching taint | Taints repel pods; a toleration only *permits*, it does not attract |
| `nodeAffinity` | Like `nodeSelector` but with operators (`In`, `NotIn`, `Exists`, `Gt`, `Lt`) | Can be required or merely preferred |

To pin a pod to a dedicated, tainted node group, combine a `nodeSelector` (attracts the pod) with a toleration (allows it past the taint). Alone, a toleration does not steer a pod anywhere.

`nodeAffinity` expresses the same idea with more flexibility:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:   # hard rule
        nodeSelectorTerms:
          - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values: ["arm64"]
      preferredDuringSchedulingIgnoredDuringExecution:  # soft rule
        - weight: 50
          preference:
            matchExpressions:
              - key: node.kubernetes.io/instance-type
                operator: In
                values: ["m6g.xlarge"]
```

CA runs the scheduler's checks against each group's template node, so it honors the required rules when choosing a group. Preferred rules are best effort.

### Other useful controls

- `topologySpreadConstraints` spreads replicas across zones or nodes. With CA this works best with one node group per zone, so CA can add capacity in the zone that needs it.
- **Well-known labels** are set by Kubernetes and cloud providers on every node, so you can target them without defining your own:
  - `topology.kubernetes.io/zone`: the availability zone.
  - `kubernetes.io/arch`: CPU architecture (`amd64`, `arm64`).
  - `node.kubernetes.io/instance-type`: the instance type, such as `m6g.xlarge`.

### Who does what

| Responsibility | Who |
| --- | --- |
| Create node groups with the right labels, taints and instance types | Platform / cluster admin |
| Set requests, selectors and tolerations on pods | App developer |
| Pick the exact group when several qualify | Cluster Autoscaler (via the expander) |

## Scale-down

CA removes a node when its requested CPU and memory stay below a utilization threshold (0.5 by default) for a set time (10 minutes by default) and its pods can be rescheduled elsewhere. It then drains the node and lowers the group's desired count.

Things that block a node from being removed:

- Pods not managed by a controller (bare pods).
- Pods using local storage, unless annotated as safe to evict.
- Pods with the annotation `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`.
- Pods whose PodDisruptionBudget would be violated.
- Pods with scheduling constraints that no other node can satisfy.

Common flags: `--scale-down-utilization-threshold`, `--scale-down-unneeded-time`, and `--scale-down-delay-after-add`. Defaults vary by version, so check the docs for the release you run.
