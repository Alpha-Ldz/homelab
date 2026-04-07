# OpenClaw - Commandes Utiles

# ============================================
# INFORMATIONS DE BASE
# ============================================

# Gateway URL
GATEWAY_URL="https://openclaw.freedom35.fr"

# Gateway Token
GATEWAY_TOKEN="REDACTED_OPENCLAW_TOKEN"

echo "OpenClaw Gateway Token: $GATEWAY_TOKEN"
echo "Gateway URL: $GATEWAY_URL"
echo ""

# ============================================
# GESTION DU DEPLOYMENT
# ============================================

# Vérifier le status du pod
check_status() {
    echo "=== OpenClaw Pod Status ==="
    kubectl get pods -n openclaw -l app.kubernetes.io/name=openclaw
    echo ""
}

# Voir les logs
view_logs() {
    echo "=== OpenClaw Logs (dernières 50 lignes) ==="
    kubectl logs -n openclaw deployment/openclaw -c main --tail=50
}

# Suivre les logs en temps réel
follow_logs() {
    echo "=== OpenClaw Logs (temps réel) ==="
    kubectl logs -n openclaw deployment/openclaw -c main -f
}

# Redémarrer OpenClaw
restart() {
    echo "=== Redémarrage OpenClaw ==="
    kubectl rollout restart deployment/openclaw -n openclaw
    kubectl rollout status deployment/openclaw -n openclaw
}

# Mettre à jour la configuration
update_config() {
    echo "=== Mise à jour configuration OpenClaw ==="
    helm upgrade openclaw openclaw/openclaw -n openclaw -f /home/peuleu/homelab/kubernetes/openclaw/values.yaml
    echo ""
    echo "Attente du nouveau pod..."
    kubectl rollout status deployment/openclaw -n openclaw
}

# Voir la configuration actuelle
show_config() {
    echo "=== Configuration OpenClaw actuelle ==="
    kubectl get configmap openclaw -n openclaw -o yaml | grep -A 30 '"models":'
}

# ============================================
# GESTION DES DEVICES
# ============================================

# Lister les devices
list_devices() {
    echo "=== Liste des devices ==="
    kubectl exec -n openclaw deployment/openclaw -c main -- node dist/index.js devices list
}

# Approuver un device (usage: approve_device <REQUEST_ID>)
approve_device() {
    if [ -z "$1" ]; then
        echo "Usage: approve_device <REQUEST_ID>"
        return 1
    fi
    echo "=== Approbation du device $1 ==="
    kubectl exec -n openclaw deployment/openclaw -c main -- node dist/index.js devices approve "$1"
}

# ============================================
# ACCÈS AU CONTAINER
# ============================================

# Shell interactif dans le pod
shell() {
    echo "=== Shell OpenClaw ==="
    kubectl exec -it -n openclaw deployment/openclaw -c main -- /bin/bash
}

# Port-forward pour accès local
port_forward() {
    echo "=== Port-forward OpenClaw ==="
    echo "Accès disponible sur http://localhost:18789"
    kubectl port-forward -n openclaw svc/openclaw 18789:18789
}

# ============================================
# GESTION DES MODÈLES
# ============================================

# Lister les modèles Ollama disponibles
list_models() {
    echo "=== Modèles Ollama disponibles ==="
    kubectl exec -n ollama deployment/ollama -- ollama list
    echo ""
}

# Voir le modèle actuellement configuré
show_current_model() {
    echo "=== Modèle actuellement configuré ==="
    kubectl logs -n openclaw deployment/openclaw -c main --tail=100 | grep "agent model:" | tail -1
    echo ""
}

# Changer le modèle OpenClaw
change_model() {
    echo "=== Changement de modèle OpenClaw ==="
    echo ""

    # Lister les modèles disponibles
    echo "Modèles disponibles dans Ollama:"
    echo ""
    kubectl exec -n ollama deployment/ollama -- ollama list
    echo ""

    # Demander le nouveau modèle
    read -p "Entrez le nom complet du modèle (ex: qwen2.5-coder:7b-instruct-q8_0): " new_model

    if [ -z "$new_model" ]; then
        echo "Erreur: Nom de modèle vide"
        return 1
    fi

    # Vérifier que le modèle existe
    if ! kubectl exec -n ollama deployment/ollama -- ollama list | grep -q "$new_model"; then
        echo "Erreur: Le modèle '$new_model' n'existe pas dans Ollama"
        return 1
    fi

    echo ""
    echo "Modèle actuel:"
    show_current_model

    read -p "Changer pour 'ollama/$new_model' ? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Annulé"
        return 0
    fi

    # Backup du fichier values.yaml
    cp /home/peuleu/homelab/kubernetes/openclaw/values.yaml /home/peuleu/homelab/kubernetes/openclaw/values.yaml.bak

    # Mettre à jour le modèle par défaut dans values.yaml
    sed -i "s|\"model\": \"ollama/[^\"]*\"|\"model\": \"ollama/$new_model\"|g" /home/peuleu/homelab/kubernetes/openclaw/values.yaml

    # Vérifier le changement
    echo ""
    echo "Nouveau modèle configuré:"
    grep '"model":' /home/peuleu/homelab/kubernetes/openclaw/values.yaml | grep -v "models"
    echo ""

    # Demander si on déploie
    read -p "Déployer maintenant ? (y/n): " deploy
    if [ "$deploy" == "y" ]; then
        echo ""
        echo "=== Déploiement en cours ==="
        helm upgrade openclaw openclaw/openclaw -n openclaw -f /home/peuleu/homelab/kubernetes/openclaw/values.yaml
        echo ""
        echo "Attente du nouveau pod..."
        kubectl wait --for=condition=ready pod -n openclaw -l app.kubernetes.io/name=openclaw --timeout=60s
        echo ""
        echo "Vérification du nouveau modèle:"
        sleep 2
        show_current_model
    else
        echo "Configuration sauvegardée. Lancez 'update_config' pour déployer."
    fi
}

# Ajouter un modèle à la liste des modèles disponibles
add_model_to_list() {
    echo "=== Ajout d'un modèle à la liste OpenClaw ==="
    echo ""

    # Lister les modèles Ollama
    echo "Modèles disponibles dans Ollama:"
    kubectl exec -n ollama deployment/ollama -- ollama list
    echo ""

    read -p "Entrez le nom du modèle à ajouter: " model_name

    if [ -z "$model_name" ]; then
        echo "Erreur: Nom de modèle vide"
        return 1
    fi

    # Vérifier que le modèle existe dans Ollama
    if ! kubectl exec -n ollama deployment/ollama -- ollama list | grep -q "$model_name"; then
        echo "Attention: Le modèle '$model_name' n'existe pas dans Ollama"
        read -p "Continuer quand même ? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            return 0
        fi
    fi

    echo ""
    echo "Ce modèle sera ajouté à la liste mais ne sera pas le modèle par défaut."
    read -p "Continuer ? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        return 0
    fi

    # Backup
    cp /home/peuleu/homelab/kubernetes/openclaw/values.yaml /home/peuleu/homelab/kubernetes/openclaw/values.yaml.bak

    # Note: Cette opération nécessite une édition manuelle ou un script plus complexe
    echo ""
    echo "⚠️  Ajout manuel requis:"
    echo "Éditez /home/peuleu/homelab/kubernetes/openclaw/values.yaml"
    echo "et ajoutez cette ligne dans la section 'models':"
    echo ""
    echo "    {\"id\": \"$model_name\", \"name\": \"$model_name\"},"
    echo ""
}

# ============================================
# INFORMATIONS SYSTÈME
# ============================================

# Voir les ressources utilisées
show_resources() {
    echo "=== Utilisation ressources OpenClaw ==="
    kubectl top pod -n openclaw
}

# Voir les events
show_events() {
    echo "=== Events récents OpenClaw ==="
    kubectl get events -n openclaw --sort-by='.lastTimestamp' | tail -20
}

# Voir la config Helm
show_helm_values() {
    echo "=== Valeurs Helm actuelles ==="
    helm get values openclaw -n openclaw -o yaml
}

# ============================================
# MENU INTERACTIF
# ============================================

show_menu() {
    echo ""
    echo "==========================================="
    echo "OpenClaw - Menu de commandes"
    echo "==========================================="
    echo "📊 STATUS & LOGS"
    echo "  1. Vérifier le status"
    echo "  2. Voir les logs"
    echo "  3. Suivre les logs (temps réel)"
    echo ""
    echo "🔧 CONFIGURATION"
    echo "  4. Redémarrer"
    echo "  5. Mettre à jour la configuration"
    echo "  6. Voir la configuration actuelle"
    echo ""
    echo "🤖 MODÈLES IA"
    echo "  12. Lister les modèles disponibles"
    echo "  13. Voir le modèle actuel"
    echo "  14. Changer de modèle"
    echo "  15. Ajouter un modèle à la liste"
    echo ""
    echo "📱 DEVICES"
    echo "  7. Lister les devices"
    echo "  11. Approuver un device"
    echo ""
    echo "🔌 ACCÈS"
    echo "  8. Port-forward (accès local)"
    echo "  9. Shell interactif"
    echo "  10. Afficher le token"
    echo ""
    echo "0. Quitter"
    echo "==========================================="
    read -p "Choix: " choice

    case $choice in
        1) check_status ;;
        2) view_logs ;;
        3) follow_logs ;;
        4) restart ;;
        5) update_config ;;
        6) show_config ;;
        7) list_devices ;;
        8) port_forward ;;
        9) shell ;;
        10) echo "Gateway Token: $GATEWAY_TOKEN" ;;
        11) read -p "Request ID: " req_id && approve_device "$req_id" ;;
        12) list_models ;;
        13) show_current_model ;;
        14) change_model ;;
        15) add_model_to_list ;;
        0) exit 0 ;;
        *) echo "Choix invalide" ;;
    esac
}

# Si le script est exécuté directement (pas sourcé)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -eq 0 ]; then
        # Mode interactif
        while true; do
            show_menu
        done
    else
        # Mode commande directe
        "$@"
    fi
fi
