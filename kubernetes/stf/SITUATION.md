# Situation actuelle : Déploiement Gnirehtet sur Kubernetes

## Problème

L'Android connecté via ADB n'a pas d'accès Internet. Gnirehtet (reverse tethering via USB/ADB) est censé résoudre ce problème, mais le déploiement échoue systématiquement.

## Erreur actuelle

```
2026-02-11 21:49:51.072 ERROR Main: Cannot start client: Command adb ["shell", "dumpsys", "package", "com.genymobile.gnirehtet"] failed: No such file or directory (os error 2)
```

**Cause** : Le container gnirehtet ne trouve pas la commande `adb`.

## Diagnostic

### État du pod
- **Pod** : `adb-56765dbd65-6ht4s` (ou similaire)
- **Namespace** : `stf`
- **Status** : 2/2 Running
- **Container gnirehtet** : Tourne mais ne trouve pas `adb`

### Images
- **Tag actuel cherché par le pod** : `gnirehtet-20260211-215901` (ou `gnirehtet:arm64`)
- **Image utilisée** : `sha256:0873f48bd6343e68fac0f7245afec54a4da0cefb885ea07072c452f409ff0cf9` (ancienne image SANS adb)
- **Image correcte buildée** : Existe dans Docker avec adb installé, mais n'arrive pas à être chargée dans containerd

### Ce qui a été tenté

1. ✅ Modification du Dockerfile pour installer `android-tools-adb`
2. ✅ Rebuild de l'image avec `--no-cache`
3. ✅ Vérification que adb est présent dans l'image Docker
4. ❌ Import de l'image dans containerd (échoue ou utilise le mauvais cache)
5. ❌ Suppression des anciennes images (containerd garde un cache persistant)
6. ❌ Utilisation de tags uniques avec timestamp
7. ❌ Restart de containerd

## Problème racine

**Containerd utilise un cache persistant d'images** et continue d'utiliser l'ancienne image `sha256:0873f48...` malgré tous les imports, suppressions et rebuilds. Kubernetes avec `imagePullPolicy: Never` cherche l'image localement et trouve toujours l'ancienne version.

## Fichiers importants

### Dockerfile
- **Chemin** : `~/homelab/kubernetes/stf/Dockerfile.gnirehtet`
- **Package installé** : `android-tools-adb` (ligne 41)
- **État** : ✅ Correct

### Déploiement
- **Chemin** : `~/homelab/kubernetes/stf/adb-with-gnirehtet.yaml`
- **Image actuelle** : `gnirehtet:arm64` ou tag avec timestamp
- **imagePullPolicy** : `Never` (problématique)
- **PATH** : Configuré avec `/usr/lib/android-sdk/platform-tools`

### Scripts disponibles
- `deploy-gnirehtet.sh` : Script de déploiement complet (ne fonctionne pas)
- `force-redeploy.sh` : Tentative avec tag unique (ne fonctionne pas)
- `fix-image-import.sh` : Diagnostic et fix (ne fonctionne pas)
- `diagnose-and-fix.sh` : Diagnostic complet (à tester)

## Commandes de diagnostic

```bash
# Vérifier l'état du pod
kubectl get pods -n stf -l app=adb
kubectl describe pod -n stf -l app=adb

# Vérifier quelle image est utilisée
kubectl get deployment adb -n stf -o jsonpath='{.spec.template.spec.containers[?(@.name=="gnirehtet")].image}'

# Voir l'Image ID réellement utilisée
kubectl describe pod -n stf -l app=adb | grep "Image ID:" | grep gnirehtet

# Vérifier les images dans Docker
sudo docker images | grep gnirehtet

# Vérifier les images dans containerd
sudo ctr -n k8s.io images ls | grep gnirehtet

# Vérifier si adb est dans l'image Docker
sudo docker run --rm --entrypoint sh gnirehtet:arm64 -c "adb version"

# Vérifier si adb est dans le container en cours d'exécution
POD=$(kubectl get pod -n stf -l app=adb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n stf $POD -c gnirehtet -- sh -c "ls -la /usr/bin/adb"

# Logs gnirehtet
kubectl logs -n stf -l app=adb -c gnirehtet --tail=50
```

## Solutions à essayer

### Solution 1 : Forcer l'utilisation de la nouvelle image (RECOMMANDÉ)

Containerd ne trouve pas l'image correctement. Il faut soit :

**Option A** : Changer `imagePullPolicy` de `Never` à `IfNotPresent`

```bash
cd ~/homelab/kubernetes/stf
nano adb-with-gnirehtet.yaml
# Changer ligne 36 : imagePullPolicy: IfNotPresent
kubectl apply -f adb-with-gnirehtet.yaml
kubectl delete pod -n stf -l app=adb
```

**Option B** : Setup un registry local

```bash
# Lancer un registry local sur le rpi5
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Taguer et pusher l'image
sudo docker tag gnirehtet:arm64 localhost:5000/gnirehtet:arm64
sudo docker push localhost:5000/gnirehtet:arm64

# Modifier le deployment pour utiliser localhost:5000/gnirehtet:arm64
# Et changer imagePullPolicy à IfNotPresent
```

**Option C** : Charger manuellement l'image dans containerd avec crictl

```bash
# Exporter l'image
sudo docker save gnirehtet:arm64 -o /tmp/gnirehtet.tar

# Charger avec crictl (pas ctr)
sudo crictl load -i /tmp/gnirehtet.tar

# Vérifier
sudo crictl images | grep gnirehtet

# Nettoyer
sudo rm /tmp/gnirehtet.tar
```

### Solution 2 : Rebuild complet et clean (dernière tentative)

```bash
cd ~/homelab/kubernetes/stf

# 1. TOUT SUPPRIMER
kubectl delete deployment adb -n stf
sudo crictl rmi $(sudo crictl images | grep gnirehtet | awk '{print $3}') 2>/dev/null || true
sudo ctr -n k8s.io images rm $(sudo ctr -n k8s.io images ls | grep gnirehtet | awk '{print $1}') 2>/dev/null || true
sudo docker rmi -f $(sudo docker images | grep gnirehtet | awk '{print $3}') 2>/dev/null || true

# 2. REBUILD
sudo docker build --no-cache \
    -f Dockerfile.gnirehtet \
    -t gnirehtet:arm64 \
    --build-arg GNIREHTET_VERSION=v2.5.1 \
    .

# 3. VÉRIFIER
sudo docker run --rm --entrypoint sh gnirehtet:arm64 -c "adb version"

# 4. CHARGER avec crictl (pas ctr)
sudo docker save gnirehtet:arm64 -o /tmp/gnirehtet.tar
sudo crictl load -i /tmp/gnirehtet.tar
sudo rm /tmp/gnirehtet.tar

# 5. VÉRIFIER
sudo crictl images | grep gnirehtet

# 6. DEPLOYER
kubectl apply -f adb-with-gnirehtet.yaml
kubectl wait --for=condition=ready pod -l app=adb -n stf --timeout=120s

# 7. TESTER
POD=$(kubectl get pod -n stf -l app=adb -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n stf $POD -c gnirehtet -- adb version
kubectl logs -n stf $POD -c gnirehtet --tail=20
```

### Solution 3 : Approche différente (ALTERNATIVE)

Si rien ne fonctionne, on peut :

1. **Utiliser un sidecar qui copie adb** au lieu de l'installer dans l'image
2. **Monter un volume partagé** entre les containers adb et gnirehtet
3. **Utiliser l'image adb:arm64** directement pour gnirehtet et installer gnirehtet dedans

## Architecture cible

```
[Pod ADB]
├─ Container ADB (adb:arm64)
│  └─ /usr/bin/adb ou /usr/lib/android-sdk/platform-tools/adb
│
└─ Container Gnirehtet (gnirehtet:arm64)
   ├─ /usr/local/bin/gnirehtet (binaire compilé)
   ├─ /data/gnirehtet.apk
   └─ /usr/bin/adb (installé via android-tools-adb) ← MANQUANT ACTUELLEMENT
```

## Informations système

- **Serveur** : rpi5 (ARM64)
- **OS** : Linux (Debian Bookworm)
- **Kubernetes** : K3s ou similaire
- **Container runtime** : containerd
- **Namespace** : stf

## Prochaines étapes recommandées

1. **Tester Solution 2** (rebuild + crictl) - 10 min
2. Si échec : **Tester Solution 1 Option C** (crictl load) - 2 min
3. Si échec : **Tester Solution 1 Option A** (changer imagePullPolicy) - 1 min
4. Si échec : **Tester Solution 3** (approche alternative) - 30 min

## Contact précédent

La session précédente a impliqué de nombreuses tentatives de debug avec :
- Modifications du Dockerfile
- Multiples rebuilds
- Tentatives d'import dans containerd
- Changements de tags
- Restart de containerd

**Tous ont échoué car containerd continue d'utiliser l'ancienne image en cache.**

## Notes importantes

- ✅ L'image Docker **contient bien adb** (vérifié avec `docker run`)
- ✅ Le Dockerfile est **correct** (`android-tools-adb` installé)
- ✅ Le PATH dans le deployment est **correct**
- ❌ Le pod utilise **l'ancienne image** sans adb
- ❌ L'import dans containerd **ne fonctionne pas correctement**

Le problème n'est PAS le code, c'est la gestion du cache d'images entre Docker et containerd/Kubernetes.
