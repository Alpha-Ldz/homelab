# STF (Smartphone Test Farm) sur Kubernetes ARM64

Déploiement de STF sur cluster Kubernetes ARM64 (Raspberry Pi 5) pour gérer et automatiser des appareils Android via USB.

## Architecture

STF est composé de plusieurs microservices :
- **RethinkDB** : Base de données pour l'état des devices
- **Triproxy** : Hub de communication ZeroMQ entre services
- **App** : Interface web
- **Auth** : Service d'authentification (mock pour dev)
- **API** : API REST
- **Websocket** : Streaming temps réel
- **Storage** : Stockage APK et images
- **Processor** : Traitement images/screenshots
- **Reaper** : Nettoyage des devices inactifs
- **Provider** : Connexion et gestion des devices Android via ADB

## Prérequis

### 1. Cluster Kubernetes
- Kubernetes 1.20+ fonctionnel sur ARM64
- Nginx Ingress Controller installé
- StorageClass configuré (local-path par défaut)

### 2. Appareil Android
- **Mode développeur activé** sur l'appareil
- **Débogage USB activé**
- Appareil connecté en USB au Raspberry Pi 5

### 3. Vérification ADB sur le host
```bash
# Installer ADB si nécessaire
sudo apt install android-tools-adb

# Vérifier la détection USB
lsusb

# Tester ADB
adb devices
# Devrait afficher votre appareil après autorisation
```

### 4. Configuration DNS/Hosts
Ajouter à `/etc/hosts` (ou configurer votre DNS) :
```
<IP_DU_CLUSTER>  stf.local
```

## Structure des fichiers

```
stf/
├── base/
│   ├── namespace.yaml          # Namespace stf
│   └── configmap.yaml          # Configuration globale
├── rethinkdb/
│   ├── pvc.yaml               # Stockage persistant
│   ├── deployment.yaml        # Base de données
│   └── service.yaml           # Service ClusterIP
├── services/
│   ├── triproxy-*.yaml        # Hub ZeroMQ
│   ├── app-*.yaml             # Interface web
│   ├── auth-*.yaml            # Authentification
│   ├── api-*.yaml             # API REST
│   ├── websocket-*.yaml       # Streaming WS
│   ├── storage-*.yaml         # Stockage fichiers
│   ├── processor-*.yaml       # Traitement images
│   └── reaper-*.yaml          # Nettoyage devices
├── provider/
│   ├── daemonset.yaml         # Provider avec accès USB
│   └── service.yaml           # Exposition NodePort
├── ingress/
│   └── ingress.yaml           # Exposition HTTP/WS
├── deploy.sh                  # Script de déploiement
└── README.md                  # Ce fichier
```

## Configuration

### Variables importantes dans `base/configmap.yaml`

```yaml
# URL publiques (à modifier selon votre configuration)
STF_URL: "http://stf.local"
WEBSOCKET_URL: "ws://stf.local"

# Ports pour streaming vidéo des devices
PROVIDER_MIN_PORT: "15000"
PROVIDER_MAX_PORT: "25000"

# Secret (CHANGER EN PRODUCTION !)
SECRET: "change-me-in-production"
```

### StorageClass dans `rethinkdb/pvc.yaml` et `services/storage-pvc.yaml`
```yaml
storageClassName: local-path  # Adapter à votre cluster
```

### Domaine dans `ingress/ingress.yaml`
```yaml
spec:
  rules:
  - host: stf.local  # Remplacer par votre domaine
```

## Déploiement

### Méthode 1 : Script automatisé (recommandé)
```bash
chmod +x deploy.sh
./deploy.sh
```

### Méthode 2 : Déploiement manuel

#### 1. Créer le namespace et la configuration
```bash
kubectl apply -f base/namespace.yaml
kubectl apply -f base/configmap.yaml
```

#### 2. Déployer RethinkDB
```bash
kubectl apply -f rethinkdb/pvc.yaml
kubectl apply -f rethinkdb/deployment.yaml
kubectl apply -f rethinkdb/service.yaml

# Attendre que RethinkDB soit prêt
kubectl wait --for=condition=ready pod -l app=rethinkdb -n stf --timeout=300s
```

#### 3. Déployer Triproxy (hub de communication)
```bash
kubectl apply -f services/triproxy-deployment.yaml
kubectl apply -f services/triproxy-service.yaml

# Attendre que Triproxy soit prêt
kubectl wait --for=condition=ready pod -l app=triproxy -n stf --timeout=120s
```

#### 4. Déployer les services STF
```bash
# Storage
kubectl apply -f services/storage-pvc.yaml
kubectl apply -f services/storage-deployment.yaml
kubectl apply -f services/storage-service.yaml

# Auth
kubectl apply -f services/auth-deployment.yaml
kubectl apply -f services/auth-service.yaml

# API
kubectl apply -f services/api-deployment.yaml
kubectl apply -f services/api-service.yaml

# Websocket
kubectl apply -f services/websocket-deployment.yaml
kubectl apply -f services/websocket-service.yaml

# App
kubectl apply -f services/app-deployment.yaml
kubectl apply -f services/app-service.yaml

# Processor et Reaper
kubectl apply -f services/processor-deployment.yaml
kubectl apply -f services/reaper-deployment.yaml

# Attendre que les services soient prêts
kubectl wait --for=condition=ready pod -l app=stf-app -n stf --timeout=180s
```

#### 5. Déployer le Provider (accès USB)
```bash
kubectl apply -f provider/daemonset.yaml
kubectl apply -f provider/service.yaml

# Vérifier que le provider détecte les devices
kubectl logs -n stf -l app=stf-provider -c adb-server
```

#### 6. Exposer via Ingress
```bash
kubectl apply -f ingress/ingress.yaml
```

## Vérification

### 1. État des pods
```bash
kubectl get pods -n stf
```

Tous les pods doivent être en état `Running`.

### 2. Vérifier la détection des devices
```bash
# Logs du serveur ADB
kubectl logs -n stf -l app=stf-provider -c adb-server

# Logs du provider STF
kubectl logs -n stf -l app=stf-provider -c provider
```

Vous devriez voir votre device Android listé.

### 3. Accès à l'interface web
Ouvrir dans un navigateur : **http://stf.local**

L'interface STF devrait s'afficher avec votre appareil Android visible.

### 4. Tester l'API
```bash
# Lister les devices via l'API
curl http://stf.local/api/v1/devices
```

## Accès et utilisation

### Interface Web
- **URL** : http://stf.local
- **Auth** : Mode mock (pas de mot de passe en dev)
- Vous pouvez sélectionner et contrôler vos devices Android

### API REST
- **URL** : http://stf.local/api/v1/
- Documentation : https://github.com/openstf/stf/blob/master/doc/API.md

### Websocket
- **URL** : ws://stf.local/socket.io/
- Pour streaming temps réel des events

## Troubleshooting

### Le device Android n'apparaît pas

1. **Vérifier USB sur le host**
   ```bash
   lsusb
   # Chercher votre appareil Android
   ```

2. **Vérifier ADB dans le pod provider**
   ```bash
   kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices
   ```

3. **Vérifier les permissions USB**
   ```bash
   # Sur le host Raspberry Pi
   ls -la /dev/bus/usb/*/*
   ```

4. **Autoriser le débogage USB sur l'appareil**
   - Une popup doit apparaître sur Android
   - Cocher "Toujours autoriser" et accepter

### RethinkDB ne démarre pas

1. **Vérifier le PVC**
   ```bash
   kubectl get pvc -n stf
   ```

2. **Vérifier les logs**
   ```bash
   kubectl logs -n stf -l app=rethinkdb
   ```

3. **Problème de mémoire sur RPi5**
   - Réduire `--cache-size` dans `rethinkdb/deployment.yaml`

### Les services ne communiquent pas

1. **Vérifier Triproxy**
   ```bash
   kubectl logs -n stf -l app=triproxy
   ```

2. **Vérifier la configuration**
   ```bash
   kubectl get configmap stf-config -n stf -o yaml
   ```

3. **Tester la connectivité entre pods**
   ```bash
   kubectl exec -n stf -l app=stf-app -- nc -zv rethinkdb 28015
   ```

### Ingress ne fonctionne pas

1. **Vérifier Nginx Ingress Controller**
   ```bash
   kubectl get pods -n ingress-nginx
   ```

2. **Vérifier l'Ingress**
   ```bash
   kubectl describe ingress stf-ingress -n stf
   ```

3. **Logs Nginx**
   ```bash
   kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
   ```

### Problèmes de performance sur RPi5

1. **Réduire les ressources** dans les deployments
2. **Limiter le nombre de replicas** à 1 pour tous les services
3. **Ajuster RethinkDB cache** : `--cache-size 256` ou moins

## Désinstallation

```bash
kubectl delete namespace stf
```

Cela supprimera tous les composants STF, mais **pas les PV** si vous utilisez un StorageClass avec `reclaimPolicy: Retain`.

## Sécurité - IMPORTANT

⚠️ **Cette configuration est pour un environnement de développement/test**

Pour la production :
1. **Changer le secret** dans `base/configmap.yaml`
2. **Utiliser une vraie authentification** (remplacer `auth-mock` par `auth-ldap` ou autre)
3. **Configurer HTTPS/TLS** sur l'Ingress
4. **Sécuriser RethinkDB** avec un authkey
5. **Limiter l'accès réseau** avec des NetworkPolicies
6. **Ne pas utiliser `privileged: true`** sans comprendre les risques

## Références

- Documentation STF : https://github.com/openstf/stf
- API STF : https://github.com/openstf/stf/blob/master/doc/API.md
- Images Docker : https://hub.docker.com/r/openstf/stf

## Support

Pour les problèmes :
1. Vérifier les logs : `kubectl logs -n stf <pod-name>`
2. Consulter la doc STF officielle
3. Issues GitHub : https://github.com/openstf/stf/issues
