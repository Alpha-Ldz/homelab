#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Teardown STF complet ==="

# Supprimer les deployments et services
echo "[1/4] Suppression des ressources Kubernetes..."
kubectl delete deployment adb -n stf --ignore-not-found
kubectl delete deployment stf -n stf --ignore-not-found
kubectl delete deployment rethinkdb -n stf --ignore-not-found
kubectl delete deployment squid-proxy -n stf --ignore-not-found
kubectl delete service adb -n stf --ignore-not-found
kubectl delete service stf -n stf --ignore-not-found
kubectl delete service rethinkdb -n stf --ignore-not-found
kubectl delete service squid-proxy -n stf --ignore-not-found
kubectl delete ingress stf-ingress -n stf --ignore-not-found
kubectl delete pvc rethinkdb-data -n stf --ignore-not-found

echo "[2/4] Suppression des images dans K3s containerd..."
for img in $(sudo k3s ctr -n k8s.io images ls -q 2>/dev/null | grep -E "gnirehtet|adb"); do
    sudo k3s ctr -n k8s.io images rm "$img" 2>/dev/null || true
done

echo "[3/4] Suppression des images Docker..."
for img in $(sudo docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -E "gnirehtet|adb"); do
    sudo docker rmi -f "$img" 2>/dev/null || true
done

echo "[4/4] Nettoyage..."
sudo rm -f /tmp/gnirehtet.tar /tmp/adb.tar
# On garde le namespace et les clés ADB

echo ""
echo "=== Teardown terminé ==="
echo "Note: le namespace 'stf' et les clés ADB (~/.android) sont conservés."
echo "Pour tout supprimer: kubectl delete namespace stf"
