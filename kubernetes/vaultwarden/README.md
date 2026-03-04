# Vaultwarden + OpenClaw - Documentation complète

## 🎉 Installation réussie !

Vaultwarden est maintenant déployé sur votre cluster K3s et configuré pour fonctionner avec OpenClaw.

## 📋 Informations de déploiement

- **URL Web** : https://vaultwarden.freedom35.fr
- **URL Admin** : https://vaultwarden.freedom35.fr/admin
- **Namespace** : `vaultwarden`
- **Storage** : Longhorn PVC 5Gi
- **Inscriptions** : Actuellement activées (à désactiver après création de votre compte)

## 🚀 Premiers pas

### 1. Créer votre compte Vaultwarden

1. Ouvrez https://vaultwarden.freedom35.fr dans votre navigateur
2. Cliquez sur "Créer un compte"
3. Entrez votre email et créez un mot de passe principal fort
4. Validez votre compte

### 2. Créer une API Key pour OpenClaw

Une fois connecté à Vaultwarden :

1. Allez dans **Paramètres** (Settings)
2. Section **Sécurité** (Security)
3. **Clés** (Keys) > **Afficher les clés API** (View API Key)
4. Copiez :
   - `client_id` (commence par `user.`)
   - `client_secret` (longue chaîne)

### 3. Configurer l'intégration avec OpenClaw

Utilisez le script de gestion :

```bash
bash /home/peuleu/homelab/scripts/vaultwarden-setup.sh create-api-key
```

Le script vous demandera d'entrer le `client_id` et `client_secret`, puis créera automatiquement le secret Kubernetes.

### 4. Mettre à jour OpenClaw

```bash
bash /home/peuleu/homelab/scripts/vaultwarden-setup.sh update-openclaw
```

Cette commande va :
- Mettre à jour la configuration OpenClaw avec le skill Bitwarden
- Redémarrer le pod OpenClaw
- Attendre que le déploiement soit prêt

### 5. Tester l'intégration

```bash
bash /home/peuleu/homelab/scripts/vaultwarden-setup.sh test-bitwarden
```

Vous devriez voir la version du CLI Bitwarden s'afficher.

### 6. Désactiver les inscriptions publiques (Recommandé)

Une fois votre compte créé, désactivez les inscriptions pour sécuriser votre instance :

```bash
bash /home/peuleu/homelab/scripts/vaultwarden-setup.sh disable-signups
```

## 🔧 Utilisation avec OpenClaw

### Via l'agent OpenClaw

Une fois configuré, vous pouvez demander à l'agent OpenClaw d'accéder à vos mots de passe :

**Exemples de conversations :**

```
Vous : "Récupère mon mot de passe GitHub depuis Bitwarden"
Agent : [Utilise le skill bitwarden-vault pour accéder à votre vault]

Vous : "Crée une variable d'environnement avec mon token API de Notion"
Agent : [Récupère le secret et le configure]

Vous : "Liste tous mes identifiants stockés"
Agent : [Liste les items de votre vault]
```

### Via le CLI dans le pod

Vous pouvez aussi utiliser le CLI Bitwarden directement :

```bash
# Session interactive
bash /home/peuleu/homelab/scripts/vaultwarden-setup.sh bw-login

# Ensuite dans le pod :
bw config server https://vaultwarden.freedom35.fr
bw login <votre-email>
# Ou avec API key :
bw login --apikey
# Ensuite unlock :
export BW_SESSION=$(bw unlock --raw)

# Lister les items
bw list items

# Récupérer un mot de passe
bw get password "GitHub"
```

## 📱 Utilisation sur d'autres appareils

### Applications officielles Bitwarden

Vaultwarden est compatible avec tous les clients Bitwarden officiels :

- **Desktop** : https://bitwarden.com/download/
- **Mobile** : iOS App Store / Google Play Store
- **Extensions navigateur** : Chrome, Firefox, Safari, Edge

#### Configuration des clients

Lors de la connexion, **avant** d'entrer vos identifiants :

1. Cliquez sur l'icône ⚙️ (Settings/Paramètres)
2. Dans "Server URL", entrez : `https://vaultwarden.freedom35.fr`
3. Sauvegardez
4. Connectez-vous avec vos identifiants

## 🔐 Sécurité

### Bonnes pratiques

- ✅ **Utilisez un mot de passe principal fort** et unique
- ✅ **Activez 2FA** dans Paramètres > Sécurité > Authentification à deux facteurs
- ✅ **Désactivez les inscriptions** après avoir créé votre compte
- ✅ **Sauvegardez vos codes de récupération** 2FA
- ✅ **Configurez SMTP** pour les notifications par email (optionnel)

### Backup des données

Les données sont stockées dans un PVC Longhorn :

```bash
# Exporter le vault (depuis le pod OpenClaw ou après login)
bw export --format json --output /tmp/backup.json

# Copier le backup localement
kubectl cp openclaw/<pod-name>:/tmp/backup.json ./vaultwarden-backup.json -n openclaw
```

## 🛠️ Scripts de gestion

Le script `/home/peuleu/homelab/scripts/vaultwarden-setup.sh` fournit plusieurs commandes utiles :

```bash
# Afficher l'état
bash vaultwarden-setup.sh status

# Récupérer le token admin
bash vaultwarden-setup.sh admin-token

# Voir les logs
bash vaultwarden-setup.sh logs-vaultwarden
bash vaultwarden-setup.sh logs-openclaw

# Tester Bitwarden
bash vaultwarden-setup.sh test-bitwarden

# Aide complète
bash vaultwarden-setup.sh help
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│  Vous (Navigateur/Apps)                 │
│  - Interface Web Vaultwarden            │
│  - Apps Bitwarden (Desktop/Mobile)      │
│  - Extensions navigateur                │
└──────────────────┬──────────────────────┘
                   │ HTTPS (Traefik + SSL)
                   │
┌──────────────────▼──────────────────────┐
│  Ingress: vaultwarden.freedom35.fr     │
│  (Traefik + cert-manager)               │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│  Vaultwarden Pod (namespace: vaultwarden)│
│  - SQLite Database                      │
│  - Web Vault                            │
│  - API Server                           │
└──────────────────┬──────────────────────┘
                   │
                   │ API Key Authentication
                   │
┌──────────────────▼──────────────────────┐
│  OpenClaw Pod (namespace: openclaw)     │
│  - Bitwarden CLI (bw)                   │
│  - Bitwarden-vault skill                │
│  - Agent IA                             │
└─────────────────────────────────────────┘
```

## 📊 Fichiers de configuration

### Vaultwarden

- **Helm Chart** : `gissilabs/vaultwarden`
- **Values** : `/home/peuleu/homelab/kubernetes/vaultwarden/values.yaml`
- **Namespace** : `vaultwarden`

### OpenClaw

- **Configuration** : `/home/peuleu/homelab/kubernetes/openclaw/values.yaml`
- **Skill** : `bitwarden-vault` (dans `/home/node/.openclaw/skills/`)
- **CLI** : `/home/node/.openclaw/bin/bw`
- **Data** : `/home/node/.openclaw/data/bitwarden/`

## 🔄 Configuration SMTP (Optionnel)

Pour activer les notifications par email, modifiez `vaultwarden/values.yaml` :

```yaml
vaultwarden:
  smtp:
    enabled: true
    host: "stalwart.stalwart.svc.cluster.local"
    from: "vaultwarden@freedom35.fr"
    port: 25
    security: "off"
```

Puis mettez à jour :

```bash
helm upgrade vaultwarden vaultwarden/vaultwarden \
  -n vaultwarden \
  -f /home/peuleu/homelab/kubernetes/vaultwarden/values.yaml
```

## 🆘 Dépannage

### Le site n'est pas accessible

```bash
# Vérifier le pod
kubectl get pods -n vaultwarden

# Vérifier l'ingress
kubectl get ingress -n vaultwarden

# Voir les logs
bash vaultwarden-setup.sh logs-vaultwarden
```

### OpenClaw ne peut pas se connecter

```bash
# Vérifier que le secret existe
kubectl get secret bitwarden-api-key -n openclaw

# Vérifier les variables d'environnement
kubectl get deployment openclaw -n openclaw -o jsonpath='{.spec.template.spec.containers[0].env}'

# Tester le CLI
bash vaultwarden-setup.sh test-bitwarden
```

### Réinitialiser l'API key

```bash
# Supprimer l'ancien secret
kubectl delete secret bitwarden-api-key -n openclaw

# Créer une nouvelle API key dans Vaultwarden
# Puis reconfigurer
bash vaultwarden-setup.sh create-api-key
bash vaultwarden-setup.sh update-openclaw
```

## 📚 Ressources

- **Vaultwarden GitHub** : https://github.com/dani-garcia/vaultwarden
- **Vaultwarden Wiki** : https://github.com/dani-garcia/vaultwarden/wiki
- **Bitwarden Help** : https://bitwarden.com/help/
- **Bitwarden CLI** : https://bitwarden.com/help/cli/
- **OpenClaw Bitwarden Skill** : GitHub openclaw/skills

## 🎯 Prochaines étapes

1. ✅ Créer votre compte Vaultwarden
2. ✅ Configurer l'API key pour OpenClaw
3. ✅ Désactiver les inscriptions publiques
4. ⬜ Activer 2FA pour votre compte
5. ⬜ Installer les extensions navigateur
6. ⬜ Installer l'app mobile
7. ⬜ Configurer SMTP (optionnel)
8. ⬜ Importer vos mots de passe existants

## 💾 Migration depuis 1Password

Pour nettoyer l'ancienne configuration 1Password :

```bash
# Supprimer le skill 1Password
kubectl exec -n openclaw deployment/openclaw -- rm -rf /home/node/.openclaw/skills/1password

# Supprimer le binaire op
kubectl exec -n openclaw deployment/openclaw -- rm -f /home/node/.openclaw/bin/op /home/node/.openclaw/bin/op.sig

# Les fichiers seront nettoyés lors de la prochaine mise à jour
```

---

**🎉 Félicitations !** Vous disposez maintenant d'un gestionnaire de mots de passe auto-hébergé, gratuit et intégré avec OpenClaw !
