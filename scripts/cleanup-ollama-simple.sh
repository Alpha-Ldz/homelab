#!/bin/bash
# Simple cleanup script - just removes the blobs and manifests
# Run kubectl commands separately as your user

set -e

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

echo -e "\n=== Action ==="
echo "This will DELETE all Ollama model blobs and manifests"
echo "Freeing: ~78GB"
echo "You will need to re-download models after (~30GB)"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo -e "\n=== Backup manifests ==="
mkdir -p /tmp/ollama-backup
cp -r $MANIFESTS_PATH /tmp/ollama-backup/ 2>/dev/null || echo "No manifests to backup"
echo "Backed up to /tmp/ollama-backup/"

echo -e "\n=== Remove all blobs ==="
rm -rf $BLOBS_PATH
echo "Removed blobs directory"

echo -e "\n=== Remove all manifests ==="
rm -rf $MANIFESTS_PATH
echo "Removed manifests directory"

echo -e "\n=== Recreate directory structure ==="
mkdir -p $BLOBS_PATH/sha256
mkdir -p $MANIFESTS_PATH/registry.ollama.ai/library
chown -R 1000:1000 $MODELS_PATH 2>/dev/null || echo "Could not chown, will be fixed when pod starts"
echo "Directory structure recreated"

echo -e "\n=== Disk Space After Cleanup ==="
df -h /
echo ""
echo "Ollama PVC usage now: $(du -sh $STORAGE_PATH | cut -f1)"

echo -e "\n=== Next Steps (run as your user) ==="
echo "1. Clean up evicted pods:"
echo "   kubectl delete pods --field-selector=status.phase=Failed -n ollama"
echo ""
echo "2. Check if DiskPressure cleared (wait 1-2 minutes):"
echo "   kubectl describe node sleeper | grep DiskPressure"
echo ""
echo "3. Scale Ollama back up:"
echo "   kubectl scale deployment ollama -n ollama --replicas=1"
echo ""
echo "4. Watch pod start:"
echo "   kubectl get pods -n ollama -w"
echo ""
echo "5. Download the models:"
echo "   kubectl exec -n ollama deployment/ollama -- ollama pull deepseek-r1:14b-qwen-distill-q8_0"
echo "   kubectl exec -n ollama deployment/ollama -- ollama pull qwen3:14b-q8_0"
echo "   kubectl exec -n ollama deployment/ollama -- ollama pull qwen2.5-coder:7b-instruct-q8_0"
echo "   kubectl exec -n ollama deployment/ollama -- ollama pull llama3.1:8b-instruct-q8_0"

echo -e "\n=== Cleanup Complete! ==="
