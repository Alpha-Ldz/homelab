#!/bin/bash

# Script pour tester quelle image STF fonctionne sur ARM64

set +e  # Ne pas arrêter sur erreur

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo ""
log_info "=========================================="
log_info "  Test des images STF sur ARM64"
log_info "=========================================="
echo ""

# Liste des images à tester
IMAGES=(
    "openstf/stf:latest"
    "devicefarmer/stf:latest"
    "devicefarmer/stf:1.5.0"
)

WORKING_IMAGE=""

for IMAGE in "${IMAGES[@]}"; do
    log_info "Test de $IMAGE..."

    # Pull l'image
    if docker pull "$IMAGE" >/dev/null 2>&1; then
        # Tester l'exécution
        OUTPUT=$(docker run --rm --platform linux/arm64 "$IMAGE" --version 2>&1)

        if echo "$OUTPUT" | grep -q "exec format error"; then
            log_error "$IMAGE : Incompatible ARM64 (exec format error)"
        elif echo "$OUTPUT" | grep -q "stf\|version\|STF"; then
            log_success "$IMAGE : Compatible ARM64 !"
            WORKING_IMAGE="$IMAGE"
            break
        else
            log_error "$IMAGE : Erreur inconnue"
            echo "       $OUTPUT" | head -n 3
        fi
    else
        log_error "$IMAGE : Impossible de télécharger"
    fi

    echo ""
done

echo ""
log_info "=========================================="
log_info "  Résultat"
log_info "=========================================="
echo ""

if [ -n "$WORKING_IMAGE" ]; then
    log_success "Image compatible trouvée : $WORKING_IMAGE"
    echo ""
    log_info "Pour l'utiliser :"
    echo "  cd ~/homelab/stf/docker"
    echo "  ./update-manifests.sh $WORKING_IMAGE"
    echo "  cd .."
    echo "  kubectl delete namespace stf"
    echo "  ./deploy.sh"
else
    log_error "Aucune image compatible ARM64 trouvée"
    echo ""
    log_info "Vous devrez builder STF pour ARM64 :"
    echo "  cd ~/homelab/stf"
    echo "  ./fix-arm64.sh"
    echo "  Choisir l'option 2 (build local)"
fi

echo ""
