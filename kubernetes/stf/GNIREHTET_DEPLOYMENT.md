# Déploiement Gnirehtet ARM64 sur Kubernetes

Guide complet pour compiler et déployer Gnirehtet sur votre cluster K8s ARM64.

## Vue d'ensemble

Cette solution permet à l'Android d'avoir **Internet via USB/ADB uniquement**, sans WiFi ni données mobiles.

### Architecture

```
[PC de dev]
    ↓
kubectl port-forward (contrôle ADB)
    ↓
[Cluster K8s - rpi5]
    Pod ADB (2 containers)
    ├─ Container ADB (existant)
    └─ Container Gnirehtet (nouveau) → VPN → Internet
           ↓
    [Android USB]
```

### Pourquoi un sidecar ?

Gnirehtet tourne dans le **même pod** que ADB car :
- ✅ Accès au même device USB
- ✅ Communication via localhost (plus rapide)
- ✅ Cycle de vie lié (si ADB redémarre, Gnirehtet aussi)

## Étape 1 : Compilation de Gnirehtet pour ARM64

### Sur votre serveur rpi5 (ou sur votre PC si Docker supporte ARM64)

```bash
# Se connecter au serveur rpi5
ssh peuleu@rpi5

# Aller dans le dossier
cd ~/homelab/kubernetes/stf

# Lancer la compilation (10-15 minutes)
./build-gnirehtet.sh
```

**Ce que fait le script :**
1. Clone les sources Gnirehtet depuis GitHub
2. Compile le binaire Rust pour ARM64
3. Crée une image Docker légère avec le binaire
4. Tag l'image comme `gnirehtet:arm64`

**Sortie attendue :**
```
✅ Build réussi !
Image créée: gnirehtet:arm64
```

### Alternative : Build depuis votre PC de dev

Si votre PC supporte le build ARM64 (via buildx) :

```bash
cd ~/homelab/kubernetes/stf

# Build pour ARM64
docker buildx build \
    --platform linux/arm64 \
    -f Dockerfile.gnirehtet \
    -t gnirehtet:arm64 \
    --load \
    .

# Sauver l'image
docker save gnirehtet:arm64 -o gnirehtet-arm64.tar

# Copier sur le rpi5
scp gnirehtet-arm64.tar peuleu@rpi5:/tmp/

# Sur le rpi5
ssh peuleu@rpi5
docker load -i /tmp/gnirehtet-arm64.tar
```

## Étape 2 : Vérifier l'image

Sur le rpi5 :

```bash
# Vérifier que l'image existe
docker images | grep gnirehtet

# Devrait afficher :
# gnirehtet   arm64   xxxxxxxxx   X minutes ago   XXX MB

# Tester le binaire (optionnel)
docker run --rm gnirehtet:arm64 --version
```

## Étape 3 : Déploiement sur Kubernetes

### Sauvegarder le déploiement actuel (optionnel)

```bash
# Sauvegarder l'ancien adb.yaml
cp ~/homelab/kubernetes/stf/adb.yaml ~/homelab/kubernetes/stf/adb.yaml.backup
```

### Option A : Remplacer le déploiement existant

```bash
# Supprimer l'ancien déploiement ADB
kubectl delete -f ~/homelab/kubernetes/stf/adb.yaml

# Déployer la nouvelle version avec Gnirehtet
kubectl apply -f ~/homelab/kubernetes/stf/adb-with-gnirehtet.yaml
```

### Option B : Déploiement progressif

```bash
# Déployer la nouvelle version
kubectl apply -f ~/homelab/kubernetes/stf/adb-with-gnirehtet.yaml

# Cela va remplacer automatiquement l'ancien pod
```

## Étape 4 : Vérification

### Vérifier que les pods sont en cours d'exécution

```bash
# Voir les pods
kubectl get pods -n stf

# Devrait afficher :
# NAME                   READY   STATUS    RESTARTS   AGE
# adb-xxxxxxxxxx-xxxxx   2/2     Running   0          30s
#                        ^^^
#                        2 containers dans le pod
```

### Voir les logs Gnirehtet

```bash
# Logs en temps réel
kubectl logs -n stf -l app=adb -c gnirehtet -f

# Devrait afficher quelque chose comme :
# [INFO] Starting relay server
# [INFO] Waiting for device...
# [INFO] Device connected
# [INFO] VPN established
```

### Voir les logs ADB

```bash
# Logs ADB
kubectl logs -n stf -l app=adb -c adb -f
```

## Étape 5 : Test depuis Freedom35

Depuis votre PC de dev :

```bash
cd ~/Freedom35

# Tester la connectivité (le WiFi doit être désactivé sur l'Android)
poetry run freedom35 network test
```

**Sortie attendue :**
```
Test de connectivité vers http://www.google.com...
✓ Connexion OK (méthode: curl)
```

## Utilisation avec Freedom35

### Vérifier que Gnirehtet est actif

```python
from freedom35 import ADBClient
from freedom35.config_loader import get_config_loader

config_loader = get_config_loader()
adb_config = config_loader.get_adb_config()

with ADBClient(**adb_config.to_client_kwargs()) as client:
    # Vérifier si un VPN est actif (Gnirehtet)
    result = client.shell('dumpsys connectivity | grep -A 5 VPN')
    print(result)

    # Devrait afficher des infos sur le VPN Gnirehtet
```

### Désactiver le WiFi et tester

```python
from freedom35 import ADBClient, ADBActions, NetworkManager
from freedom35.config_loader import get_config_loader

config_loader = get_config_loader()
adb_config = config_loader.get_adb_config()

with ADBClient(**adb_config.to_client_kwargs()) as client:
    actions = ADBActions(client)
    network = NetworkManager(client)

    # Désactiver le WiFi
    actions.set_wifi(False)
    print("WiFi désactivé")

    # Tester la connectivité (devrait fonctionner via Gnirehtet)
    result = network.test_connectivity()
    if result['success']:
        print("✓ Internet fonctionne via USB/ADB (Gnirehtet)")
    else:
        print("✗ Pas de connexion")
```

## Troubleshooting

### Le pod ne démarre pas

```bash
# Voir les events
kubectl describe pod -n stf -l app=adb

# Erreurs possibles :
# - Image non trouvée : Vérifier que l'image existe (docker images | grep gnirehtet)
# - Permissions USB : Vérifier privileged: true
```

### Gnirehtet ne se connecte pas

```bash
# Voir les logs détaillés
kubectl logs -n stf -l app=adb -c gnirehtet -f

# Vérifier que ADB voit le device
kubectl exec -n stf -l app=adb -c adb -- adb devices
```

### L'Android n'a pas Internet

```bash
# Vérifier que le VPN Gnirehtet est actif sur l'Android
poetry run python << 'EOF'
from freedom35 import ADBClient
from freedom35.config_loader import get_config_loader

config_loader = get_config_loader()
adb_config = config_loader.get_adb_config()

with ADBClient(**adb_config.to_client_kwargs()) as client:
    # Voir les interfaces réseau
    print(client.shell('ip addr'))

    # Voir les routes
    print(client.shell('ip route'))
EOF

# Devrait voir une interface "tun0" ou similaire (Gnirehtet VPN)
```

### Redémarrer Gnirehtet

```bash
# Redémarrer uniquement le pod
kubectl rollout restart deployment/adb -n stf

# Ou supprimer le pod (il sera recréé automatiquement)
kubectl delete pod -n stf -l app=adb
```

## Rollback

Si vous voulez revenir à l'ancien déploiement sans Gnirehtet :

```bash
# Restaurer la sauvegarde
kubectl apply -f ~/homelab/kubernetes/stf/adb.yaml.backup

# Ou supprimer et redéployer
kubectl delete -f ~/homelab/kubernetes/stf/adb-with-gnirehtet.yaml
kubectl apply -f ~/homelab/kubernetes/stf/adb.yaml
```

## Architecture finale

```
[PC de dev - Freedom35]
    ↓ kubectl port-forward (port 5037)
    ↓
[Service ADB - ClusterIP]
    ↓
[Pod ADB sur rpi5]
  ├─ Container ADB (port 5037)
  │    ↓ localhost:5037
  └─ Container Gnirehtet
       ↓ Crée VPN sur Android
       ↓
[Android via USB]
  ↓ Interface tun0 (VPN)
  ↓
Internet (via le serveur rpi5)
```

## Avantages de cette solution

✅ **Pas de WiFi nécessaire** : Internet uniquement via USB
✅ **Même architecture dev/prod** : Fonctionne depuis votre PC de dev et en prod
✅ **Contrôle programmatique** : Via Freedom35
✅ **Persistant** : Redémarre automatiquement avec le pod
✅ **Natif ARM64** : Compilé spécifiquement pour votre architecture

## Notes importantes

- **Premier lancement** : Gnirehtet peut prendre 10-30 secondes pour établir le VPN
- **Autorisations Android** : Si c'est la première fois, vous devrez accepter le VPN sur l'Android
- **Performances** : Le trafic passe par le serveur rpi5, donc la bande passante dépend de votre réseau local
- **Redémarrage** : Si le pod redémarre, le VPN est automatiquement rétabli

## Commandes utiles

```bash
# Voir tous les containers du pod
kubectl get pods -n stf -l app=adb -o jsonpath='{.items[0].spec.containers[*].name}'

# Exécuter une commande dans le container ADB
kubectl exec -n stf -l app=adb -c adb -- adb devices

# Exécuter une commande dans le container Gnirehtet
kubectl exec -n stf -l app=adb -c gnirehtet -- ps aux

# Port-forward manuel (si besoin)
kubectl port-forward -n stf svc/adb 5037:5037

# Voir les ressources utilisées
kubectl top pod -n stf -l app=adb --containers
```

## Prochaines étapes

Une fois Gnirehtet déployé et fonctionnel :

1. **Supprimer le proxy Squid** (plus nécessaire) :
   ```bash
   kubectl delete -f ~/homelab/kubernetes/stf/proxy.yaml
   ```

2. **Nettoyer la config Freedom35** :
   Retirer la section `network.proxy_*` de `config.yaml`

3. **Tester votre workflow** :
   ```bash
   poetry run python examples/use_android_internet.py
   ```
