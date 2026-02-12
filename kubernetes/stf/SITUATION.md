# STF - Smartphone Test Farm sur Kubernetes (K3s / RPi5)

## Architecture

```
[Ingress] stf.freedom35.fr
    |
[Service STF] :7100
    |
[Pod STF] (stf-deployment.yaml)
    |-- Connexion ADB via service adb:5037
    |
[Pod ADB + Gnirehtet] (adb-with-gnirehtet.yaml)
    |-- Container ADB : serveur ADB, accès USB, clés persistées
    |-- Container Gnirehtet : relay reverse tethering USB → Internet
    |
[Pod RethinkDB] (rethinkdb.yaml)
    |-- PVC Longhorn 5Gi
    |
[Pod Proxy Squid] (proxy.yaml) — optionnel, pour multi-proxy futur
```

## Informations système

- **Serveur** : rpi5 (ARM64, Debian Bookworm)
- **IP** : 192.168.1.17
- **Kubernetes** : K3s v1.33.5
- **Container runtime** : containerd (socket K3s : `/run/k3s/containerd/containerd.sock`)
- **Namespace** : `stf`
- **Domaine** : stf.freedom35.fr

## Fichiers du projet

| Fichier | Rôle |
|---------|------|
| `namespace.yaml` | Namespace `stf` |
| `rethinkdb-pvc.yaml` | PVC Longhorn pour RethinkDB |
| `rethinkdb.yaml` | Deployment + Service RethinkDB |
| `stf-deployment.yaml` | Deployment principal STF |
| `stf-service.yaml` | Service STF (ports 7100, 7110, 7400-7405) |
| `stf-ingress.yaml` | Ingress nginx pour stf.freedom35.fr |
| `adb-with-gnirehtet.yaml` | Pod ADB + sidecar Gnirehtet |
| `proxy.yaml` | Proxy Squid (optionnel) |
| `Dockerfile.gnirehtet` | Build multi-stage Gnirehtet (Rust) + adb |
| `setup.sh` | Installation complète depuis zéro |
| `teardown.sh` | Suppression complète de tout |

## Problème résolu : Gnirehtet — pas d'Internet sur le téléphone

### Cause racine

Le `http_proxy` Android était configuré sur `proxy.stf.svc.cluster.local:3128` — un nom DNS interne Kubernetes **inaccessible depuis le téléphone**. Le téléphone ne peut pas résoudre les noms `.cluster.local` (son DNS passe par 8.8.8.8 via gnirehtet). Toutes les requêtes HTTP/HTTPS des apps étaient redirigées vers un proxy injoignable, provoquant des timeouts et des connexions qui se fermaient sans transfert de données.

### Résolution

```bash
# Supprimer le proxy inaccessible
adb shell "settings put global http_proxy :0"
```

### Ce qui fonctionne maintenant

- **Image gnirehtet:arm64** : buildée correctement, contient `adb` (android-tools-adb)
- **Import dans K3s containerd** : fonctionne via `sudo k3s ctr -n k8s.io images import`
- **Serveur ADB** : détecte le téléphone, autorisé (`device`)
- **Clés ADB** : persistées via hostPath `/home/peuleu_server/.android`
- **Gnirehtet relay** : démarre, installe l'APK sur le téléphone, tunnel VPN actif (tun0 UP)
- **adb reverse** : configuré (`localabstract:gnirehtet tcp:31416`)
- **VPN Android** : CONNECTED, VALIDATED par Android
- **WiFi** : VALIDATED (après suppression du proxy)
- **Internet via gnirehtet** : le relay relaie le trafic correctement

### Notes sur le proxy pour usage futur

Le téléphone **ne peut pas** utiliser un proxy avec un nom DNS Kubernetes interne (`*.svc.cluster.local`). Pour utiliser le proxy Squid depuis le téléphone via gnirehtet, il faut utiliser le **ClusterIP** directement :

```bash
# Récupérer le ClusterIP du proxy
kubectl get svc proxy -n stf -o jsonpath='{.spec.clusterIP}'
# Exemple : 10.43.6.129

# Configurer le proxy sur le téléphone (via ClusterIP)
adb shell "settings put global http_proxy 10.43.6.129:3128"
```

Cela fonctionne car le trafic du téléphone passe par gnirehtet → relay (dans le pod K8s) → réseau cluster → proxy Squid.

## Pièges découverts (à retenir)

### 1. K3s utilise son propre containerd

```bash
# MAUVAIS — containerd système, ignoré par K3s
sudo ctr -n k8s.io images import image.tar

# BON — containerd K3s
sudo k3s ctr -n k8s.io images import image.tar --all-platforms

# Vérification
sudo k3s crictl images | grep <image>
```

### 2. Clés ADB non persistées = unauthorized à chaque restart

Solution : monter `/home/peuleu_server/.android` en hostPath sur `/root/.android` dans le container ADB.

### 3. Gnirehtet démarre avant ADB

Le sidecar gnirehtet démarre en même temps que le container ADB. Si ADB n'a pas encore détecté le device, gnirehtet échoue et ne retente pas.

Solution : boucle d'attente dans la commande de démarrage :
```yaml
command: ["/bin/sh", "-c"]
args:
  - |
    while ! adb devices 2>/dev/null | grep -q 'device$'; do
      sleep 2
    done
    exec /usr/local/bin/gnirehtet run
```

### 4. Popup VPN Android

Au premier lancement, Android affiche un dialogue "Autoriser la connexion VPN ?" qu'il faut accepter manuellement sur le téléphone. L'autorisation persiste ensuite.

### 5. Proxy HTTP Android et DNS Kubernetes

Ne **jamais** configurer `http_proxy` Android avec un nom DNS K8s (`proxy.stf.svc.cluster.local`). Le téléphone résout les DNS via 8.8.8.8 (gnirehtet) ou le DNS local, qui ne connaissent pas `.cluster.local`. Utiliser le ClusterIP directement ou ne pas mettre de proxy.

```bash
# MAUVAIS — le téléphone ne peut pas résoudre ce DNS
adb shell "settings put global http_proxy proxy.stf.svc.cluster.local:3128"

# BON — utiliser le ClusterIP
adb shell "settings put global http_proxy 10.43.6.129:3128"

# RESET — supprimer le proxy
adb shell "settings put global http_proxy :0"
```

### 6. Android et le réseau par défaut

Android ne met pas un VPN comme réseau par défaut s'il n'y a aucun réseau physique actif (WiFi ou mobile data). Il faut au moins un réseau physique connecté.

## Objectif futur

- Plusieurs téléphones Android connectés via USB
- Chaque téléphone avec un proxy différent
- Gestion via STF (Smartphone Test Farm)
- Proxy par device configurable via `adb shell settings put global http_proxy <ip>:<port>` ou via routing K8s
