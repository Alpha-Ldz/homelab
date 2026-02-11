#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

IMAGE_NAME="stf-arm64"
IMAGE_TAG="latest"
REGISTRY="localhost:5000"  # Registre local, adaptez si besoin

echo ""
log_info "======================================"
log_info "  Build de STF pour ARM64"
log_info "======================================"
echo ""

# Vérifier que Docker est disponible
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé"
    exit 1
fi

log_success "Docker est installé"

# Builder l'image
log_info "Construction de l'image STF pour ARM64..."
log_info "Cela peut prendre 15-30 minutes..."
echo ""

cd "$(dirname "$0")"

docker build \
    --platform linux/arm64 \
    -t ${IMAGE_NAME}:${IMAGE_TAG} \
    -f Dockerfile \
    .

if [ $? -eq 0 ]; then
    log_success "Image buildée avec succès : ${IMAGE_NAME}:${IMAGE_TAG}"
else
    log_error "Échec du build"
    exit 1
fi

echo ""
log_info "Taille de l'image :"
docker images ${IMAGE_NAME}:${IMAGE_TAG}

echo ""
log_info "Pour pousser l'image vers un registre local :"
echo "  docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
log_info "Pour utiliser cette image dans les manifests Kubernetes :"
echo "  Remplacez 'openstf/stf:latest' par '${IMAGE_NAME}:${IMAGE_TAG}'"
echo "  Ou utilisez le script update-manifests.sh"

echo ""
log_success "Build terminé !"
