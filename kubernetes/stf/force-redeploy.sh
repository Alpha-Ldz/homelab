#!/bin/bash
set -e

cd "$(dirname "$0")"

# Générer un tag unique avec timestamp
TAG="gnirehtet-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "FORCE REDEPLOY AVEC TAG UNIQUE"
echo "Tag: $TAG"
echo "=========================================="
echo ""

# 1. SUPPRIMER LE DEPLOYMENT
echo "1️⃣ Suppression du deployment..."
kubectl delete deployment adb -n stf --ignore-not-found=true
sleep 5

# 2. REBUILD AVEC LE NOUVEAU TAG
echo "2️⃣ Build de l'image avec tag unique..."
sudo docker build --no-cache \
    -f Dockerfile.gnirehtet \
    -t "$TAG" \
    --build-arg GNIREHTET_VERSION=v2.5.1 \
    .

# 3. VÉRIFIER ADB
echo "3️⃣ Vérification adb..."
sudo docker run --rm --entrypoint sh "$TAG" -c "adb version" || {
    echo "❌ adb manquant !"
    exit 1
}

# 4. IMPORTER DANS CONTAINERD
echo "4️⃣ Import dans containerd..."
sudo docker save "$TAG" -o "/tmp/${TAG}.tar"
sudo ctr -n k8s.io images import "/tmp/${TAG}.tar"
sudo rm "/tmp/${TAG}.tar"

# 5. MODIFIER LE YAML TEMPORAIREMENT
echo "5️⃣ Modification du deployment..."
cp adb-with-gnirehtet.yaml adb-with-gnirehtet.yaml.backup
sed -i "s|image: gnirehtet:arm64|image: $TAG|g" adb-with-gnirehtet.yaml

# 6. DEPLOYER
echo "6️⃣ Déploiement..."
kubectl apply -f adb-with-gnirehtet.yaml

echo "⏳ Attente du pod..."
kubectl wait --for=condition=ready pod -l app=adb -n stf --timeout=120s

# 7. VERIFICATIONS
POD=$(kubectl get pod -n stf -l app=adb -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "Pod: $POD"
echo ""

echo "Test adb:"
kubectl exec -n stf $POD -c gnirehtet -- adb version

echo ""
echo "Logs gnirehtet:"
kubectl logs -n stf $POD -c gnirehtet --tail=20

echo ""
echo "=========================================="
echo "✅ SUCCÈS !"
echo "=========================================="
echo ""
echo "⚠️  Le deployment utilise maintenant le tag: $TAG"
echo "⚠️  Pour revenir à gnirehtet:arm64, restaurez le backup:"
echo "    mv adb-with-gnirehtet.yaml.backup adb-with-gnirehtet.yaml"
echo "    kubectl apply -f adb-with-gnirehtet.yaml"
