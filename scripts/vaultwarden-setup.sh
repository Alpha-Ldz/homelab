#!/usr/bin/env bash

# Script de configuration et gestion de Vaultwarden + OpenClaw
# Usage: bash vaultwarden-setup.sh [command]

set -e

NAMESPACE_VW="vaultwarden"
NAMESPACE_OC="openclaw"
DEPLOYMENT_OC="openclaw"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

case "${1:-help}" in
    status)
        log_info "=== État de Vaultwarden ==="
        kubectl get pods -n $NAMESPACE_VW
        echo ""
        kubectl get ingress -n $NAMESPACE_VW
        echo ""
        log_info "URL d'accès: https://vaultwarden.freedom35.fr"
        ;;

    admin-token)
        log_info "=== Récupération du token admin Vaultwarden ==="
        ADMIN_TOKEN=$(kubectl get secret -n $NAMESPACE_VW vaultwarden -o jsonpath='{.data.admin-token}' 2>/dev/null | base64 -d)
        if [ -n "$ADMIN_TOKEN" ]; then
            log_success "Token admin: $ADMIN_TOKEN"
            echo ""
            log_info "URL admin: https://vaultwarden.freedom35.fr/admin"
        else
            log_warning "Pas de token admin configuré ou secret non trouvé"
        fi
        ;;

    create-api-key)
        log_info "=== Configuration de l'API Key pour OpenClaw ==="
        echo ""
        log_info "Pour créer une API key:"
        echo "  1. Allez sur https://vaultwarden.freedom35.fr"
        echo "  2. Connectez-vous avec votre compte"
        echo "  3. Allez dans Paramètres > Sécurité > Clés > Afficher les clés API"
        echo "  4. Copiez le client_id et client_secret"
        echo ""
        read -p "Entrez le BW_CLIENTID: " clientid
        read -p "Entrez le BW_CLIENTSECRET: " clientsecret

        if [ -z "$clientid" ] || [ -z "$clientsecret" ]; then
            log_error "client_id et client_secret requis!"
            exit 1
        fi

        log_info "Création du secret Kubernetes..."
        kubectl create secret generic bitwarden-api-key \
            -n $NAMESPACE_OC \
            --from-literal=clientid="$clientid" \
            --from-literal=clientsecret="$clientsecret" \
            --dry-run=client -o yaml | kubectl apply -f -

        log_success "Secret créé avec succès!"
        log_info "Maintenant, mettez à jour OpenClaw avec: bash $0 update-openclaw"
        ;;

    update-openclaw)
        log_info "=== Mise à jour d'OpenClaw avec Bitwarden ==="
        helm upgrade openclaw openclaw/openclaw \
            -n $NAMESPACE_OC \
            -f /home/peuleu/homelab/kubernetes/openclaw/values.yaml

        log_success "OpenClaw mis à jour!"
        log_info "Attente du rollout..."
        kubectl rollout status deployment/$DEPLOYMENT_OC -n $NAMESPACE_OC --timeout=120s
        log_success "OpenClaw redémarré avec succès!"
        ;;

    test-bitwarden)
        log_info "=== Test de Bitwarden CLI dans OpenClaw ==="
        kubectl exec -n $NAMESPACE_OC deployment/$DEPLOYMENT_OC -- bash -c "
            export BITWARDENCLI_APPDATA_DIR=/home/node/.openclaw/data/bitwarden
            /home/node/.openclaw/bin/bw --version
        "
        log_success "Bitwarden CLI fonctionne!"
        ;;

    bw-login)
        log_info "=== Connexion Bitwarden via OpenClaw ==="
        log_warning "Cette commande ouvre une session interactive"
        echo ""
        log_info "Pour utiliser Vaultwarden auto-hébergé, configurez d'abord le serveur:"
        echo "  bw config server https://vaultwarden.freedom35.fr"
        echo ""

        kubectl exec -it -n $NAMESPACE_OC deployment/$DEPLOYMENT_OC -- bash -c "
            export BITWARDENCLI_APPDATA_DIR=/home/node/.openclaw/data/bitwarden
            export PATH=/home/node/.openclaw/bin:\$PATH

            echo 'Configuration du serveur Vaultwarden...'
            bw config server https://vaultwarden.freedom35.fr

            echo ''
            echo 'Connexion à Bitwarden...'
            echo 'Utilisez: bw login <email>'
            echo 'Ou avec API key: bw login --apikey'
            bash
        "
        ;;

    logs-vaultwarden)
        log_info "=== Logs Vaultwarden ==="
        kubectl logs -n $NAMESPACE_VW -l app.kubernetes.io/name=vaultwarden --tail=100 -f
        ;;

    logs-openclaw)
        log_info "=== Logs OpenClaw ==="
        kubectl logs -n $NAMESPACE_OC deployment/$DEPLOYMENT_OC --tail=100 -f
        ;;

    disable-signups)
        log_info "=== Désactivation des inscriptions Vaultwarden ==="
        log_warning "Cette action empêchera les nouvelles inscriptions"
        read -p "Êtes-vous sûr ? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Modifier values.yaml
            sed -i 's/allowSignups: true/allowSignups: false/' /home/peuleu/homelab/kubernetes/vaultwarden/values.yaml
            helm upgrade vaultwarden vaultwarden/vaultwarden \
                -n $NAMESPACE_VW \
                -f /home/peuleu/homelab/kubernetes/vaultwarden/values.yaml
            log_success "Inscriptions désactivées!"
        fi
        ;;

    help|*)
        cat << EOF
${BLUE}═══════════════════════════════════════════════════════════════${NC}
${GREEN}   Vaultwarden + OpenClaw - Script de gestion${NC}
${BLUE}═══════════════════════════════════════════════════════════════${NC}

${YELLOW}USAGE:${NC}
    bash $0 [command]

${YELLOW}COMMANDES:${NC}

  ${GREEN}État et Informations:${NC}
    status              - Afficher l'état de Vaultwarden
    admin-token         - Récupérer le token admin Vaultwarden
    logs-vaultwarden    - Voir les logs Vaultwarden
    logs-openclaw       - Voir les logs OpenClaw

  ${GREEN}Configuration OpenClaw:${NC}
    create-api-key      - Créer une API key et configurer OpenClaw
    update-openclaw     - Mettre à jour le déploiement OpenClaw
    test-bitwarden      - Tester le CLI Bitwarden dans OpenClaw
    bw-login            - Session interactive pour se connecter

  ${GREEN}Gestion:${NC}
    disable-signups     - Désactiver les inscriptions publiques
    help                - Afficher cette aide

${YELLOW}WORKFLOW INITIAL:${NC}

  1. ${BLUE}Accéder à Vaultwarden${NC}
     → https://vaultwarden.freedom35.fr
     → Créer votre compte

  2. ${BLUE}Créer une API key${NC}
     → Paramètres > Sécurité > Clés > Afficher les clés API
     → Copier client_id et client_secret

  3. ${BLUE}Configurer OpenClaw${NC}
     bash $0 create-api-key
     bash $0 update-openclaw

  4. ${BLUE}Tester l'intégration${NC}
     bash $0 test-bitwarden

  5. ${BLUE}Désactiver les inscriptions${NC} (recommandé)
     bash $0 disable-signups

${YELLOW}URLS:${NC}
    Vaultwarden Web:    https://vaultwarden.freedom35.fr
    Vaultwarden Admin:  https://vaultwarden.freedom35.fr/admin
    OpenClaw:           https://openclaw.freedom35.fr

${YELLOW}DOCUMENTATION:${NC}
    /home/peuleu/homelab/kubernetes/vaultwarden/README.md

EOF
        ;;
esac
