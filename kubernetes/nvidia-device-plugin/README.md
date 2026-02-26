# NVIDIA Device Plugin for Kubernetes

Exposes NVIDIA GPUs to Kubernetes, allowing pods to request GPU resources.

## What it does

- Runs as a DaemonSet on nodes with `gpu: nvidia` label
- Detects NVIDIA GPUs on the node
- Exposes them as `nvidia.com/gpu` resources
- Allows pods to request GPU allocation

## Prerequisites

- Node must have NVIDIA drivers installed
- Node must have `nvidia-container-toolkit` installed
- Node must be labeled with `gpu: nvidia`

## Installation

```bash
# Apply the device plugin
kubectl apply -f device-plugin.yaml

# Verify it's running
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds

# Check GPU capacity on node
kubectl describe node sleeper | grep nvidia.com/gpu
```

## Verify GPU is available

```bash
# Check node capacity
kubectl get node sleeper -o yaml | grep nvidia.com/gpu

# Should show:
#   nvidia.com/gpu: "1"
```

## Using GPU in pods

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
  - name: cuda
    image: nvidia/cuda:12.0.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  nodeSelector:
    gpu: nvidia
```

## Version

- Device Plugin: v0.14.0
- Source: https://github.com/NVIDIA/k8s-device-plugin

## Troubleshooting

### Device plugin pod not starting

Check logs:
```bash
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds
```

### GPU not detected

1. Verify NVIDIA drivers on node:
   ```bash
   nvidia-smi
   ```

2. Check node labels:
   ```bash
   kubectl get node sleeper --show-labels | grep gpu
   ```

3. Verify nvidia-container-toolkit:
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
   ```
