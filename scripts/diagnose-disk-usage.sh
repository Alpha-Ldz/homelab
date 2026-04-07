#!/bin/bash
# Comprehensive disk usage diagnostic script

echo "=== Overall Disk Usage ==="
df -h /

echo -e "\n=== Top-level directory usage (requires sudo for accurate results) ==="
sudo du -sh /* 2>/dev/null | sort -h | tail -20

echo -e "\n=== K3s Storage Usage ==="
if [ -d "/var/lib/rancher/k3s/storage" ]; then
    sudo du -sh /var/lib/rancher/k3s/storage 2>/dev/null
    echo -e "\nPer-PVC breakdown:"
    sudo du -sh /var/lib/rancher/k3s/storage/pvc-* 2>/dev/null | sort -h
else
    echo "K3s storage directory not found"
fi

echo -e "\n=== Ollama Models PVC Detail ==="
OLLAMA_PVC="/var/lib/rancher/k3s/storage/pvc-1dd92d67-02fa-423c-9573-f7d04cf9f24b_ollama_ollama-models"
if [ -d "$OLLAMA_PVC" ]; then
    echo "Total size:"
    sudo du -sh "$OLLAMA_PVC" 2>/dev/null

    echo -e "\nDirectory structure:"
    sudo ls -lah "$OLLAMA_PVC/" 2>/dev/null

    if [ -d "$OLLAMA_PVC/models" ]; then
        echo -e "\nModels directory:"
        sudo du -sh "$OLLAMA_PVC/models" 2>/dev/null

        echo -e "\nModel manifests:"
        if [ -d "$OLLAMA_PVC/models/manifests/registry.ollama.ai/library" ]; then
            sudo ls -la "$OLLAMA_PVC/models/manifests/registry.ollama.ai/library/" 2>/dev/null
            echo -e "\nSize per model:"
            sudo du -sh "$OLLAMA_PVC/models/manifests/registry.ollama.ai/library"/* 2>/dev/null | sort -h
        fi

        echo -e "\nModel blobs:"
        if [ -d "$OLLAMA_PVC/models/blobs" ]; then
            sudo du -sh "$OLLAMA_PVC/models/blobs" 2>/dev/null
            echo "Number of blob files:"
            sudo find "$OLLAMA_PVC/models/blobs" -type f 2>/dev/null | wc -l
        fi
    fi
else
    echo "Ollama PVC not found at expected location"
fi

echo -e "\n=== Docker/Containerd Images ==="
sudo du -sh /var/lib/docker 2>/dev/null || echo "Docker directory not found"
sudo du -sh /var/lib/containerd 2>/dev/null || echo "Containerd directory not found"
sudo du -sh /var/lib/rancher/k3s/agent/containerd 2>/dev/null || echo "K3s containerd not found"

echo -e "\n=== System Journal Logs ==="
sudo du -sh /var/log/journal 2>/dev/null || echo "Journal directory not found"

echo -e "\n=== Nix Store ==="
du -sh /nix/store 2>/dev/null
echo "Nix garbage (can be collected):"
nix-store --gc --print-dead 2>/dev/null | wc -l
