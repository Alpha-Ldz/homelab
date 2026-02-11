#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Image à utiliser
IMAGE_NAME="${1:-stf-arm64:latest}"

echo ""
log_info "======================================"
log_info "  Mise à jour des manifests"
log_info "======================================"
echo ""

log_info "Remplacement de 'openstf/stf:latest' par '${IMAGE_NAME}'..."

# Chercher tous les fichiers YAML
YAML_FILES=$(find ../services ../provider -name "*.yaml" -type f | grep -E "(deployment|daemonset)")

COUNT=0
for file in $YAML_FILES; do
    if grep -q "openstf/stf:latest" "$file"; then
        sed -i "s|openstf/stf:latest|${IMAGE_NAME}|g" "$file"
        log_info "  ✓ Modifié : $(basename $file)"
        COUNT=$((COUNT + 1))
    fi
done

echo ""
if [ $COUNT -gt 0 ]; then
    log_success "$COUNT fichiers mis à jour"
else
    log_info "Aucun fichier à modifier (déjà à jour)"
fi

echo ""
log_info "Image utilisée : ${IMAGE_NAME}"
echo ""
log_info "Pour appliquer les changements :"
echo "  cd .."
echo "  ./deploy.sh"
