#!/bin/bash
# Script to clean up unused Ollama models to resolve DiskPressure

set -e

STORAGE_PATH="/var/lib/rancher/k3s/storage/pvc-1dd92d67-02fa-423c-9573-f7d04cf9f24b_ollama_ollama-models"
MODELS_PATH="$STORAGE_PATH/models"

echo "=== Disk usage before cleanup ==="
df -h /var/lib/rancher/k3s/storage

echo -e "\n=== Current models ==="
if [ -d "$MODELS_PATH/manifests/registry.ollama.ai/library" ]; then
    du -sh "$MODELS_PATH/manifests/registry.ollama.ai/library"/* 2>/dev/null | sort -h
fi

echo -e "\n=== Models to keep (from OpenClaw config) ==="
echo "- deepseek-r1:14b-qwen-distill-q8_0"
echo "- qwen3:14b-q8_0"
echo "- qwen2.5-coder:7b-instruct-q8_0"
echo "- llama3.1:8b-instruct-q8_0"

echo -e "\n=== Models to remove ==="
echo "- qwen3.5 (large, not in config)"
echo "- mixtral (large, not in config)"

# Remove qwen3.5
if [ -d "$MODELS_PATH/manifests/registry.ollama.ai/library/qwen3.5" ]; then
    echo -e "\nRemoving qwen3.5..."
    rm -rf "$MODELS_PATH/manifests/registry.ollama.ai/library/qwen3.5"
    rm -rf "$MODELS_PATH/blobs/sha256"/*qwen3.5* 2>/dev/null || true
    echo "Removed qwen3.5"
else
    echo "qwen3.5 not found (already removed?)"
fi

# Remove mixtral
if [ -d "$MODELS_PATH/manifests/registry.ollama.ai/library/mixtral" ]; then
    echo -e "\nRemoving mixtral..."
    rm -rf "$MODELS_PATH/manifests/registry.ollama.ai/library/mixtral"
    rm -rf "$MODELS_PATH/blobs/sha256"/*mixtral* 2>/dev/null || true
    echo "Removed mixtral"
else
    echo "mixtral not found (already removed?)"
fi

echo -e "\n=== Cleaning up orphaned blobs ==="
# This will remove any blob files that are no longer referenced by manifests
# We need to be careful here, so we'll just report what would be removed
echo "Checking for orphaned blobs..."
if [ -d "$MODELS_PATH/blobs" ]; then
    echo "Total blob storage:"
    du -sh "$MODELS_PATH/blobs"
fi

echo -e "\n=== Disk usage after cleanup ==="
df -h /var/lib/rancher/k3s/storage

echo -e "\n=== Space freed ==="
echo "Check the 'Available' column above to see if we freed enough space"
echo "The node should have at least 40-50GB free for the Ollama PVC to work properly"

echo -e "\n=== Next steps ==="
echo "1. Check if DiskPressure condition clears: kubectl describe node sleeper"
echo "2. Clean up evicted pods: kubectl delete pods --field-selector=status.phase=Failed -n ollama"
echo "3. Verify Ollama pod starts: kubectl get pods -n ollama"
