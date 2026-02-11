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

## Problème en cours : Gnirehtet — pas d'Internet sur le téléphone

### Ce qui fonctionne

- **Image gnirehtet:arm64** : buildée correctement, contient `adb` (android-tools-adb)
- **Import dans K3s containerd** : fonctionne via `sudo k3s ctr -n k8s.io images import`
- **Serveur ADB** : détecte le téléphone, autorisé (`device`)
- **Clés ADB** : persistées via hostPath `/home/peuleu_server/.android`
- **Gnirehtet relay** : démarre, installe l'APK sur le téléphone, tunnel VPN actif (tun0 UP)
- **adb reverse** : configuré (`localabstract:gnirehtet tcp:31416`)
- **VPN Android** : CONNECTED, VALIDATED par Android (connectivity check passé)

### Ce qui ne fonctionne pas

**Le téléphone n'a pas d'accès Internet malgré le tunnel gnirehtet actif.**

#### Diagnostic détaillé

1. **Sans WiFi** : `Active default network: none`. Android refuse de promouvoir le VPN comme réseau par défaut sans réseau physique sous-jacent. Les apps disent "pas de réseau".

2. **Avec WiFi (réseau local)** : `Active default network: 603 (WiFi)`. Le VPN capture le trafic (visible dans les logs du relay), mais les connexions TCP se ferment rapidement (~200ms-1.5s) sans que les données transitent réellement. Le relay du pod a accès à Internet (vérifié via `openssl s_client`), mais les connexions relayées échouent silencieusement.

3. **Logs relay typiques** :
   ```
   TcpConnection: 10.0.0.2:57206 -> 172.217.18.206:443 Open
   TcpConnection: 10.0.0.2:57206 -> 172.217.18.206:443 Close   # 147ms après
   ```

#### Causes possibles

- Bug gnirehtet v2.5.1 sur ARM64 (relay compilé pour ARM64)
- Problème de MTU sur le tun0 (MTU 16384, peut être trop grand)
- Problème de buffer/throughput sur le relay via adb reverse
- Incompatibilité Samsung (com.sec.android.app.launcher)

### Pistes à explorer

1. **Réduire le MTU** du VPN gnirehtet (modifier le code source ou config)
2. **Tester gnirehtet directement sur le host** (hors Kubernetes) pour isoler si le problème vient de K8s
3. **Utiliser une version plus récente de gnirehtet** ou un fork
4. **Alternative RNDIS/USB tethering** : bridge réseau USB sans VPN Android
5. **Alternative : proxy HTTP simple** sans reverse tethering (via WiFi local + proxy Squid)

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

### 5. Android et le réseau par défaut

Android ne met pas un VPN comme réseau par défaut s'il n'y a aucun réseau physique actif (WiFi ou mobile data). Il faut au moins un réseau physique connecté.

## Objectif futur

- Plusieurs téléphones Android connectés via USB
- Chaque téléphone avec un proxy différent
- Gestion via STF (Smartphone Test Farm)
- Proxy par device configurable via `adb shell settings put global http_proxy <ip>:<port>` ou via routing K8s
