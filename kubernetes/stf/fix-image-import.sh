#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=========================================="
echo "DIAGNOSTIC ET FIX IMAGE GNIREHTET"
echo "=========================================="
echo ""

# 1. IDENTIFIER LE TAG UTILISÉ PAR LE POD
echo "1️⃣ Identification du tag utilisé par le pod..."
TAG=$(kubectl get deployment adb -n stf -o jsonpath='{.spec.template.spec.containers[?(@.name=="gnirehtet")].image}')
echo "Tag recherché par Kubernetes: $TAG"
echo ""

# 2. VÉRIFIER SI L'IMAGE EXISTE DANS CONTAINERD
echo "2️⃣ Vérification dans containerd..."
echo "Images gnirehtet dans containerd:"
sudo ctr -n k8s.io images ls | grep gnirehtet || echo "Aucune image gnirehtet trouvée"
echo ""

# 3. VÉRIFIER SI L'IMAGE EXISTE DANS DOCKER
echo "3️⃣ Vérification dans Docker..."
echo "Images gnirehtet dans Docker:"
sudo docker images | grep gnirehtet || echo "Aucune image gnirehtet trouvée"
echo ""

# 4. SI L'IMAGE EXISTE DANS DOCKER MAIS PAS DANS CONTAINERD, L'IMPORTER
if sudo docker images | grep -q "$TAG"; then
    echo "4️⃣ Image trouvée dans Docker, import dans containerd..."

    # Sauvegarder l'image
    sudo docker save "$TAG" -o "/tmp/${TAG}.tar"

    # Importer dans containerd avec le nom EXACT (sans docker.io/library/)
    sudo ctr -n k8s.io images import --base-name "$TAG" "/tmp/${TAG}.tar"

    # Nettoyer
    sudo rm "/tmp/${TAG}.tar"

    echo "✅ Image importée"
    echo ""

    # Vérifier
    echo "Vérification:"
    sudo ctr -n k8s.io images ls | grep "$TAG"
    echo ""

    # Redémarrer le pod
    echo "5️⃣ Redémarrage du pod..."
    kubectl delete pod -n stf -l app=adb

    echo "⏳ Attente du pod..."
    kubectl wait --for=condition=ready pod -l app=adb -n stf --timeout=120s

    POD=$(kubectl get pod -n stf -l app=adb -o jsonpath='{.items[0].metadata.name}')
    echo "✅ Pod prêt: $POD"
    echo ""

    # Tester
    echo "6️⃣ Test adb..."
    kubectl exec -n stf $POD -c gnirehtet -- adb version

    echo ""
    echo "=========================================="
    echo "✅ SUCCÈS !"
    echo "=========================================="
else
    echo "❌ Image $TAG non trouvée dans Docker"
    echo ""
    echo "Il faut d'abord builder l'image:"
    echo "  sudo docker build --no-cache -f Dockerfile.gnirehtet -t $TAG --build-arg GNIREHTET_VERSION=v2.5.1 ."
    exit 1
fi
