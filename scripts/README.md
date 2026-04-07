# Scripts et Commandes Utiles

Ce dossier contient les commandes fréquemment utilisées pour gérer l'infrastructure homelab.

## Structure

- `openclaw.sh` - Commandes pour gérer OpenClaw
- `ollama.sh` - Commandes pour gérer Ollama
- `credentials.md` - Tokens et accès importants

## Usage

Les scripts sont organisés par service. Chaque fichier contient les commandes courantes avec des exemples.

Pour exécuter un script :
```bash
bash scripts/openclaw.sh
```

Ou copier-coller les commandes individuellement selon les besoins.

## 🤖 Gestion des modèles OpenClaw

### Commandes rapides

```bash
# Lancer le menu interactif
./scripts/openclaw.sh

# Ou utiliser directement les fonctions:

# Voir le modèle actuel
./scripts/openclaw.sh show_current_model

# Lister tous les modèles disponibles
./scripts/openclaw.sh list_models

# Changer de modèle (interactif)
./scripts/openclaw.sh change_model
```

### Workflow de changement de modèle

1. **Lister les modèles disponibles**
   ```bash
   ./scripts/openclaw.sh list_models
   ```

2. **Changer le modèle**
   ```bash
   ./scripts/openclaw.sh change_model
   ```
   - Le script liste les modèles disponibles
   - Vous entrez le nom complet (ex: `llama3.1:8b-instruct-q8_0`)
   - Confirmation du changement
   - Déploiement automatique si vous acceptez

3. **Vérifier le changement**
   ```bash
   ./scripts/openclaw.sh show_current_model
   ```

### Modèles actuellement installés

- **qwen2.5-coder:7b-instruct-q8_0** (8.1 GB) - Par défaut, meilleur pour JSON/tool calling
- **llama3.1:8b-instruct-q8_0** (8.5 GB) - Alternative, problème booléens Python
- **mixtral:8x7b-instruct-v0.1-q4_K_M** (28 GB) - Backup, utilise beaucoup de RAM

### Backup automatique

Le script crée automatiquement un backup du fichier `values.yaml` avant chaque modification:
```
kubernetes/openclaw/values.yaml.bak
```

Pour restaurer:
```bash
cp kubernetes/openclaw/values.yaml.bak kubernetes/openclaw/values.yaml
./scripts/openclaw.sh update_config
```
