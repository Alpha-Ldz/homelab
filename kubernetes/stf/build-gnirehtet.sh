#!/bin/bash
set -e

echo "=========================================="
echo "Build Gnirehtet pour ARM64"
echo "=========================================="
echo ""

# Variables
IMAGE_NAME="gnirehtet:arm64"
DOCKERFILE="Dockerfile.gnirehtet"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

echo "📁 Répertoire de travail: $SCRIPT_DIR"
echo "🐳 Image à builder: $IMAGE_NAME"
echo ""

# Vérifier que le Dockerfile existe
if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ Erreur: $DOCKERFILE n'existe pas"
    exit 1
fi

echo "⏳ Compilation de Gnirehtet depuis les sources..."
echo "   (Cela peut prendre 10-15 minutes)"
echo ""

# Builder l'image Docker
docker build \
    -f "$DOCKERFILE" \
    -t "$IMAGE_NAME" \
    --build-arg GNIREHTET_VERSION=v2.5.1 \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Build réussi !"
    echo "=========================================="
    echo ""
    echo "Image créée: $IMAGE_NAME"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Déployer: kubectl apply -f adb-with-gnirehtet.yaml"
    echo "  2. Vérifier: kubectl get pods -n stf"
    echo "  3. Voir logs: kubectl logs -n stf -l app=adb -c gnirehtet -f"
    echo ""
else
    echo ""
    echo "❌ Erreur lors du build"
    exit 1
fi
