#!/bin/bash
set -e

echo "=========================================="
echo "DÉPLOIEMENT COMPLET GNIREHTET"
echo "=========================================="
echo ""

cd "$(dirname "$0")"

# 1. NETTOYER LES PODS
echo "📦 Étape 1/6 : Suppression du déploiement ADB existant..."
kubectl delete deployment adb -n stf --ignore-not-found=true
echo "✅ Pods nettoyés"
echo ""
sleep 3

# 2. NETTOYER TOUTES LES IMAGES GNIREHTET
echo "🧹 Étape 2/6 : Suppression de toutes les images gnirehtet en cache..."

# Supprimer de crictl (ignore les erreurs)
sudo crictl rmi docker.io/library/gnirehtet:arm64 2>/dev/null || true
sudo crictl rmi docker.io/library/gnirehtet:v2 2>/dev/null || true

# Supprimer de containerd (ignore les erreurs)
sudo ctr -n k8s.io images rm docker.io/library/gnirehtet:arm64 2>/dev/null || true
sudo ctr -n k8s.io images rm docker.io/library/gnirehtet:v2 2>/dev/null || true

# Supprimer de Docker (ignore les erreurs)
sudo docker rmi -f gnirehtet:arm64 2>/dev/null || true
sudo docker rmi -f gnirehtet:v2 2>/dev/null || true

echo "✅ Toutes les images supprimées"
echo ""

# 3. REBUILD DEPUIS ZÉRO
echo "🔨 Étape 3/6 : Compilation de gnirehtet:arm64 depuis zéro..."
echo "   (Cela peut prendre 10-15 minutes)"
echo ""

sudo docker build --no-cache \
    -f Dockerfile.gnirehtet \
    -t gnirehtet:arm64 \
    --build-arg GNIREHTET_VERSION=v2.5.1 \
    .

echo ""
echo "✅ Image compilée avec succès"
echo ""

# 4. VÉRIFIER QUE ADB EST DANS L'IMAGE
echo "🔍 Étape 4/6 : Vérification de la présence d'adb dans l'image..."
sudo docker run --rm --entrypoint sh gnirehtet:arm64 -c "adb version" || {
    echo "❌ ERREUR : adb n'est pas installé dans l'image !"
    exit 1
}
echo "✅ adb est bien présent dans l'image"
echo ""

# 5. IMPORTER DANS CONTAINERD
echo "📥 Étape 5/6 : Import de l'image dans containerd..."
sudo docker save gnirehtet:arm64 -o /tmp/gnirehtet-arm64.tar
sudo ctr -n k8s.io images import /tmp/gnirehtet-arm64.tar
sudo rm /tmp/gnirehtet-arm64.tar

# Vérifier que l'image est bien importée
sudo ctr -n k8s.io images ls | grep gnirehtet || {
    echo "❌ ERREUR : L'image n'a pas été importée dans containerd !"
    exit 1
}
echo "✅ Image importée dans containerd"
echo ""

# 6. DÉPLOYER
echo "🚀 Étape 6/6 : Déploiement du pod ADB avec Gnirehtet..."
kubectl apply -f adb-with-gnirehtet.yaml

echo "⏳ Attente du démarrage du pod (timeout 120s)..."
kubectl wait --for=condition=ready pod -l app=adb -n stf --timeout=120s || {
    echo "⚠️  Le pod met du temps à démarrer, vérification manuelle nécessaire"
    kubectl get pods -n stf
    exit 1
}

echo ""
echo "=========================================="
echo "✅ DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
echo "=========================================="
echo ""

# VÉRIFICATIONS FINALES
echo "📋 Vérifications finales..."
echo ""

POD=$(kubectl get pod -n stf -l app=adb -o jsonpath='{.items[0].metadata.name}')
echo "Pod déployé : $POD"
echo ""

echo "Image ID utilisée pour gnirehtet :"
kubectl describe pod -n stf $POD | grep "Image ID:" | grep gnirehtet
echo ""

echo "Test de la commande adb dans le container :"
if kubectl exec -n stf $POD -c gnirehtet -- adb version 2>/dev/null; then
    echo "✅ adb fonctionne dans le container"
else
    echo "❌ adb ne fonctionne pas dans le container"
    exit 1
fi
echo ""

echo "Logs gnirehtet (20 dernières lignes) :"
kubectl logs -n stf $POD -c gnirehtet --tail=20
echo ""

echo "=========================================="
echo "🎉 TOUT EST OPÉRATIONNEL !"
echo "=========================================="
echo ""
echo "Commandes utiles :"
echo "  - Voir les logs en temps réel :"
echo "    kubectl logs -n stf -l app=adb -c gnirehtet -f"
echo ""
echo "  - Redémarrer le pod :"
echo "    kubectl delete pod -n stf -l app=adb"
echo ""
