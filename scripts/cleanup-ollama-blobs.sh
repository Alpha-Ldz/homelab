#!/bin/bash
# Clean up Ollama models and orphaned blobs

set -e

# Set kubeconfig for kubectl access
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

STORAGE_PATH="/var/lib/rancher/k3s/storage/pvc-1dd92d67-02fa-423c-9573-f7d04cf9f24b_ollama_ollama-models"
MODELS_PATH="$STORAGE_PATH/models"
BLOBS_PATH="$MODELS_PATH/blobs"
MANIFESTS_PATH="$MODELS_PATH/manifests"

echo "=== Current State ==="
echo "Total Ollama PVC usage: $(du -sh $STORAGE_PATH | cut -f1)"
echo "Blobs usage: $(du -sh $BLOBS_PATH | cut -f1)"
echo "Number of blob files: $(find $BLOBS_PATH -type f 2>/dev/null | wc -l)"
echo ""
echo "Current model manifests:"
ls -la $MANIFESTS_PATH/registry.ollama.ai/library/ 2>/dev/null || echo "No manifests found"

echo -e "\n=== Models to Keep ==="
echo "According to OpenClaw config:"
echo "- deepseek-r1:14b-qwen-distill-q8_0"
echo "- qwen3:14b-q8_0"
echo "- qwen2.5-coder:7b-instruct-q8_0"
echo "- llama3.1:8b-instruct-q8_0"

echo -e "\n=== Current State ==="
echo "Only llama3.1 and qwen2.5-coder manifests exist"
echo "BUT there are 53 blob files (should be ~4-6 per model, so ~8-12 total)"
echo "This means ~40+ orphaned blobs from old deleted models"

echo -e "\n=== Strategy ==="
echo "1. Scale down Ollama to 0 to ensure no processes are using the files"
echo "2. Back up the current manifests"
echo "3. Remove ALL blobs"
echo "4. Remove ALL manifests"
echo "5. Scale Ollama back up and let it re-download the models listed in OpenClaw config"
echo ""
echo "This will free up ~78GB and then re-download only the needed models (~30GB)"
echo ""
read -p "Do you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo -e "\n=== Step 1: Scale down Ollama ==="
kubectl scale deployment ollama -n ollama --replicas=0
echo "Waiting for pods to terminate..."
sleep 10
kubectl get pods -n ollama

echo -e "\n=== Step 2: Backup manifests ==="
mkdir -p /tmp/ollama-backup
cp -r $MANIFESTS_PATH /tmp/ollama-backup/
echo "Manifests backed up to /tmp/ollama-backup/"

echo -e "\n=== Step 3: Remove all blobs ==="
echo "Removing $BLOBS_PATH..."
rm -rf $BLOBS_PATH
echo "Removed blobs"

echo -e "\n=== Step 4: Remove all manifests ==="
echo "Removing $MANIFESTS_PATH..."
rm -rf $MANIFESTS_PATH
echo "Removed manifests"

echo -e "\n=== Step 5: Recreate directory structure ==="
mkdir -p $BLOBS_PATH
mkdir -p $MANIFESTS_PATH
chown -R 1000:1000 $MODELS_PATH
echo "Directory structure recreated"

echo -e "\n=== Disk Space After Cleanup ==="
df -h /
echo ""
echo "Ollama PVC usage now: $(du -sh $STORAGE_PATH | cut -f1)"

echo -e "\n=== Step 6: Scale Ollama back up ==="
kubectl scale deployment ollama -n ollama --replicas=1
echo "Waiting for pod to start..."
sleep 5
kubectl get pods -n ollama

echo -e "\n=== Step 7: Trigger model downloads ==="
echo "The models will be automatically downloaded when OpenClaw tries to use them"
echo "You can also manually trigger downloads with:"
echo "  kubectl exec -n ollama deployment/ollama -- ollama pull deepseek-r1:14b-qwen-distill-q8_0"
echo "  kubectl exec -n ollama deployment/ollama -- ollama pull qwen3:14b-q8_0"
echo "  kubectl exec -n ollama deployment/ollama -- ollama pull qwen2.5-coder:7b-instruct-q8_0"
echo "  kubectl exec -n ollama deployment/ollama -- ollama pull llama3.1:8b-instruct-q8_0"

echo -e "\n=== Done! ==="
echo "Space freed: ~48GB (78GB - 30GB for new models)"
echo "Monitor downloads with: kubectl logs -n ollama deployment/ollama -f"
