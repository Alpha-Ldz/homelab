#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setup STF complet ==="

# 1. Namespace
echo "[1/7] Création du namespace..."
kubectl apply -f namespace.yaml

# 2. Build image gnirehtet
echo "[2/7] Build de l'image gnirehtet:arm64..."
sudo docker build --no-cache \
    -f Dockerfile.gnirehtet \
    -t gnirehtet:arm64 \
    --build-arg GNIREHTET_VERSION=v2.5.1 \
    .

echo "  Vérification: adb dans l'image..."
sudo docker run --rm --entrypoint sh gnirehtet:arm64 -c "adb version" || {
    echo "ERREUR: adb absent de l'image gnirehtet"
    exit 1
}

# 3. Import dans K3s containerd (PAS le containerd système !)
echo "[3/7] Import dans K3s containerd..."
sudo k3s ctr -n k8s.io images rm docker.io/library/gnirehtet:arm64 2>/dev/null || true
sudo docker save gnirehtet:arm64 -o /tmp/gnirehtet.tar
sudo k3s ctr -n k8s.io images import /tmp/gnirehtet.tar --all-platforms
sudo rm -f /tmp/gnirehtet.tar

echo "  Vérification dans K3s..."
sudo k3s crictl images | grep gnirehtet || {
    echo "ERREUR: image non trouvée dans K3s containerd"
    exit 1
}

# 4. Import image ADB si pas présente
echo "[4/7] Vérification image adb:arm64..."
if ! sudo k3s crictl images 2>/dev/null | grep -q "adb.*arm64"; then
    if sudo docker images | grep -q "adb.*arm64"; then
        echo "  Import de adb:arm64 dans K3s containerd..."
        sudo docker save adb:arm64 -o /tmp/adb.tar
        sudo k3s ctr -n k8s.io images import /tmp/adb.tar --all-platforms
        sudo rm -f /tmp/adb.tar
    else
        echo "ERREUR: image adb:arm64 introuvable dans Docker"
        exit 1
    fi
fi

# 5. Deploiement RethinkDB
echo "[5/7] Déploiement RethinkDB..."
kubectl apply -f rethinkdb-pvc.yaml
kubectl apply -f rethinkdb.yaml

# 6. Deploiement ADB + Gnirehtet
echo "[6/7] Déploiement ADB + Gnirehtet..."
kubectl apply -f adb-with-gnirehtet.yaml

# 7. Deploiement STF
echo "[7/7] Déploiement STF..."
kubectl apply -f stf-service.yaml
kubectl apply -f stf-deployment.yaml
kubectl apply -f stf-ingress.yaml

# Attente
echo ""
echo "Attente des pods..."
kubectl wait --for=condition=ready pod -l app=rethinkdb -n stf --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=adb -n stf --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=stf -n stf --timeout=120s 2>/dev/null || true

echo ""
echo "=== Setup terminé ==="
kubectl get pods -n stf
echo ""
echo "STF accessible sur : https://stf.freedom35.fr"
echo ""
echo "Note: il faut autoriser le débogage USB sur le téléphone"
echo "      et accepter la popup VPN gnirehtet."
