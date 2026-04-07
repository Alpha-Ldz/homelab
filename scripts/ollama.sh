#!/bin/bash
# Ollama - Commandes Utiles

# ============================================
# INFORMATIONS DE BASE
# ============================================

echo "Ollama Configuration Optimale:"
echo "  Model: qwen2.5:7b (4.7GB) - Utilisé par OpenClaw"
echo "  OLLAMA_NUM_GPU: 10"
echo "  Performance: ~15-25s pour prompts complexes, ~20-30s avec tool calling"
echo ""

# ============================================
# GESTION DU DEPLOYMENT
# ============================================

# Vérifier le status
check_status() {
    echo "=== Ollama Pod Status ==="
    kubectl get pods -n ollama -l app=ollama
    echo ""
}

# Voir les logs
view_logs() {
    echo "=== Ollama Logs (dernières 50 lignes) ==="
    kubectl logs -n ollama deployment/ollama --tail=50
}

# Suivre les logs en temps réel
follow_logs() {
    echo "=== Ollama Logs (temps réel) ==="
    kubectl logs -n ollama deployment/ollama -f
}

# Redémarrer Ollama
restart() {
    echo "=== Redémarrage Ollama ==="
    kubectl rollout restart deployment/ollama -n ollama
    kubectl rollout status deployment/ollama -n ollama
}

# Vérifier la config OLLAMA_NUM_GPU
check_num_gpu() {
    echo "=== Configuration OLLAMA_NUM_GPU ==="
    kubectl get deployment ollama -n ollama -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="OLLAMA_NUM_GPU")].value}'
    echo ""
}

# ============================================
# GESTION DES MODÈLES
# ============================================

# Lister les modèles
list_models() {
    echo "=== Modèles disponibles ==="
    kubectl exec -n ollama deployment/ollama -- ollama list
}

# Télécharger un modèle
pull_model() {
    if [ -z "$1" ]; then
        echo "Usage: pull_model <model_name>"
        echo "Exemples:"
        echo "  pull_model qwen3.5:27b"
        echo "  pull_model qwen2.5:7b"
        return 1
    fi
    echo "=== Téléchargement du modèle $1 ==="
    kubectl exec -n ollama deployment/ollama -- ollama pull "$1"
}

# Supprimer un modèle
remove_model() {
    if [ -z "$1" ]; then
        echo "Usage: remove_model <model_name>"
        return 1
    fi
    echo "=== Suppression du modèle $1 ==="
    kubectl exec -n ollama deployment/ollama -- ollama rm "$1"
}

# Voir les détails d'un modèle
show_model() {
    if [ -z "$1" ]; then
        echo "Usage: show_model <model_name>"
        return 1
    fi
    echo "=== Détails du modèle $1 ==="
    kubectl exec -n ollama deployment/ollama -- ollama show "$1"
}

# ============================================
# TESTS DE PERFORMANCE
# ============================================

# Test simple
test_simple() {
    echo "=== Test simple avec qwen3.5:27b ==="
    kubectl exec -n ollama deployment/ollama -- ollama run qwen3.5:27b "Explique en 2 phrases ce qu'est Kubernetes."
}

# Test complexe
test_complex() {
    echo "=== Test complexe avec qwen3.5:27b ==="
    kubectl exec -n ollama deployment/ollama -- ollama run qwen3.5:27b "Explique en 4 paragraphes structurés les avantages et inconvénients de l'architecture microservices vs monolithique, avec des exemples concrets."
}

# Test custom
test_custom() {
    if [ -z "$1" ]; then
        echo "Usage: test_custom \"votre prompt ici\""
        return 1
    fi
    echo "=== Test custom avec qwen3.5:27b ==="
    kubectl exec -n ollama deployment/ollama -- ollama run qwen3.5:27b "$1"
}

# ============================================
# UTILISATION GPU
# ============================================

# Vérifier l'utilisation GPU
check_gpu() {
    echo "=== Utilisation GPU sur sleeper ==="
    kubectl exec -n ollama deployment/ollama -- nvidia-smi 2>/dev/null || echo "nvidia-smi non disponible dans le container"
}

# Vérifier les variables d'environnement GPU
check_gpu_env() {
    echo "=== Variables GPU ==="
    kubectl exec -n ollama deployment/ollama -- env | grep -E 'CUDA|NVIDIA|OLLAMA_NUM_GPU'
}

# ============================================
# ACCÈS AU SERVICE
# ============================================

# Port-forward pour accès local
port_forward() {
    echo "=== Port-forward Ollama ==="
    echo "Accès API disponible sur http://localhost:11434"
    kubectl port-forward -n ollama svc/ollama 11434:11434
}

# Shell interactif
shell() {
    echo "=== Shell Ollama ==="
    kubectl exec -it -n ollama deployment/ollama -- /bin/bash
}

# ============================================
# ESPACE DISQUE
# ============================================

# Vérifier l'espace disque utilisé
check_disk() {
    echo "=== Espace disque utilisé par les modèles ==="
    kubectl exec -n ollama deployment/ollama -- du -sh /root/.ollama
    echo ""
    echo "=== Détail par modèle ==="
    kubectl exec -n ollama deployment/ollama -- du -h /root/.ollama/models/blobs | tail -20
}

# ============================================
# INFORMATIONS SYSTÈME
# ============================================

# Voir les ressources utilisées
show_resources() {
    echo "=== Utilisation ressources Ollama ==="
    kubectl top pod -n ollama
}

# Voir les events
show_events() {
    echo "=== Events récents Ollama ==="
    kubectl get events -n ollama --sort-by='.lastTimestamp' | tail -20
}

# ============================================
# MENU INTERACTIF
# ============================================

show_menu() {
    echo ""
    echo "==================================="
    echo "Ollama - Menu de commandes"
    echo "==================================="
    echo "1. Vérifier le status"
    echo "2. Voir les logs"
    echo "3. Lister les modèles"
    echo "4. Télécharger un modèle"
    echo "5. Test simple"
    echo "6. Test complexe"
    echo "7. Vérifier OLLAMA_NUM_GPU"
    echo "8. Vérifier l'espace disque"
    echo "9. Port-forward (accès local)"
    echo "10. Shell interactif"
    echo "0. Quitter"
    echo "==================================="
    read -p "Choix: " choice

    case $choice in
        1) check_status ;;
        2) view_logs ;;
        3) list_models ;;
        4)
            read -p "Nom du modèle (ex: qwen2.5:7b): " model
            pull_model "$model"
            ;;
        5) test_simple ;;
        6) test_complex ;;
        7) check_num_gpu ;;
        8) check_disk ;;
        9) port_forward ;;
        10) shell ;;
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
