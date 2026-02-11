
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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo ""
log_info "=========================================="
log_info "  Fix ARM64 pour STF"
log_info "=========================================="
echo ""

log_error "Problème détecté : openstf/stf:latest n'est pas compatible ARM64"
echo ""

# Proposer les solutions
log_info "Solutions disponibles :"
echo ""
echo "  1. Essayer devicefarmer/stf:latest (rapide, 1-2 min)"
echo "  2. Builder STF pour ARM64 localement (long, 30-60 min)"
echo "  3. Afficher le guide complet des solutions"
echo "  4. Quitter"
echo ""

read -p "Choisissez une option [1-4] : " choice

case $choice in
    1)
        log_info "Test de devicefarmer/stf:latest..."
        echo ""

        # Vérifier si Docker est disponible
        if ! command -v docker &> /dev/null; then
            log_error "Docker n'est pas installé sur ce système"
            log_info "Utilisez kubectl pour vérifier sur un node du cluster"
            exit 1
        fi

        # Tester de pull l'image
        log_info "Pull de l'image devicefarmer/stf:latest..."
        if docker pull devicefarmer/stf:latest 2>&1 | grep -q "no matching manifest"; then
            log_error "devicefarmer/stf:latest n'a pas de build ARM64 disponible"
            echo ""
            log_info "Vous devrez builder l'image vous-même (option 2)"
            exit 1
        fi

        log_success "Image téléchargée"
        echo ""

        # Tester l'exécution
        log_info "Test de l'image..."
        if docker run --rm --platform linux/arm64 devicefarmer/stf:latest --version 2>&1 | grep -q "exec format error"; then
            log_error "L'image n'est pas compatible ARM64"
            echo ""
            log_info "Vous devrez builder l'image vous-même (option 2)"
            exit 1
        fi

        log_success "Image compatible ARM64 !"
        echo ""

        # Mettre à jour les manifests
        log_info "Mise à jour des manifests Kubernetes..."
        cd docker
        ./update-manifests.sh devicefarmer/stf:latest
        cd ..

        log_success "Manifests mis à jour"
        echo ""

        # Nettoyer le namespace stf
        log_warning "Suppression du namespace stf existant..."
        kubectl delete namespace stf --wait=true 2>/dev/null || true
        sleep 5

        # Redéployer
        log_info "Redéploiement de STF avec l'image compatible ARM64..."
        ./deploy.sh

        log_success "Terminé !"
        ;;

    2)
        log_warning "Cette opération va prendre 30-60 minutes sur un Raspberry Pi 5"
        echo ""
        read -p "Voulez-vous continuer ? [y/N] : " confirm

        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            log_info "Opération annulée"
            exit 0
        fi

        # Builder l'image
        cd docker
        ./build-arm64.sh

        if [ $? -ne 0 ]; then
            log_error "Le build a échoué"
            exit 1
        fi

        # Mettre à jour les manifests
        log_info "Mise à jour des manifests..."
        ./update-manifests.sh stf-arm64:latest
        cd ..

        # Nettoyer le namespace stf
        log_warning "Suppression du namespace stf existant..."
        kubectl delete namespace stf --wait=true 2>/dev/null || true
        sleep 5

        # Redéployer
        log_info "Redéploiement de STF..."
        ./deploy.sh

        log_success "Terminé !"
        ;;

    3)
        cat docker/SOLUTION_ARM64.md
        ;;

    4)
        log_info "Au revoir !"
        exit 0
        ;;

    *)
        log_error "Option invalide"
        exit 1
        ;;
esac

echo ""
log_info "=========================================="
log_info "  Prochaines étapes"
log_info "=========================================="
echo ""
log_info "Vérifiez que les pods démarrent correctement :"
echo "  kubectl get pods -n stf"
echo ""
log_info "Vérifiez qu'il n'y a plus d'erreur 'exec format error' :"
echo "  kubectl logs -n stf -l app=stf-app"
echo ""
log_info "Accédez à l'interface :"
echo "  http://stf.local"
echo ""
