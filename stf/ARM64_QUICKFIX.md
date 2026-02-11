# Fix Rapide : exec format error sur ARM64

## Problème

Vous obtenez cette erreur dans vos pods STF :
```
exec /app/bin/stf: exec format error
```

**Cause** : L'image `openstf/stf:latest` n'a pas de build ARM64.

## Solution Rapide (2 minutes)

### Étape 1 : Nettoyer le déploiement actuel

```bash
cd ~/homelab/stf
kubectl delete namespace stf
```

### Étape 2 : Lancer le script de fix automatique

```bash
./fix-arm64.sh
```

Choisissez l'**option 1** pour tester `devicefarmer/stf:latest` (la plus rapide).

Si l'option 1 échoue, vous devrez utiliser l'option 2 (build local, ~30-60 min).

### Étape 3 : Vérifier le déploiement

```bash
# Voir l'état des pods
kubectl get pods -n stf

# Vérifier les logs (ne devrait plus avoir "exec format error")
kubectl logs -n stf -l app=stf-app
```

## Solution Manuelle Alternative

### Option A : Tester devicefarmer/stf

```bash
# 1. Mettre à jour les manifests
cd ~/homelab/stf/docker
./update-manifests.sh devicefarmer/stf:latest

# 2. Nettoyer et redéployer
cd ..
kubectl delete namespace stf
./deploy.sh
```

### Option B : Builder STF pour ARM64 (~30-60 min)

```bash
# 1. Builder l'image
cd ~/homelab/stf/docker
./build-arm64.sh

# 2. Mettre à jour les manifests
./update-manifests.sh stf-arm64:latest

# 3. Nettoyer et redéployer
cd ..
kubectl delete namespace stf
./deploy.sh
```

### Option C : Builder sur une machine puissante

Si vous avez une machine x86_64 avec Docker :

```bash
# Sur votre machine de dev
git clone https://github.com/DeviceFarmer/stf.git
cd stf

# Installer buildx si nécessaire
docker buildx create --use --name arm64-builder

# Builder pour ARM64
docker buildx build \
  --platform linux/arm64 \
  -t stf-arm64:latest \
  --load \
  .

# Sauvegarder l'image
docker save stf-arm64:latest | gzip > stf-arm64.tar.gz

# Transférer vers le RPi5
scp stf-arm64.tar.gz peuleu@<IP_RPI5>:/home/peuleu/

# Sur le RPi5
cd ~
gunzip stf-arm64.tar.gz
docker load < stf-arm64.tar

# Mettre à jour les manifests
cd ~/homelab/stf/docker
./update-manifests.sh stf-arm64:latest

# Déployer
cd ..
kubectl delete namespace stf
./deploy.sh
```

## Vérification Finale

Une fois déployé, vérifiez que tout fonctionne :

```bash
# État des pods (tous doivent être Running)
kubectl get pods -n stf

# Logs sans erreur "exec format error"
kubectl logs -n stf -l app=stf-app

# Test de l'interface web
curl -I http://stf.local

# Voir les devices détectés
make devices
```

## Temps Estimés

| Solution | Temps | Difficulté |
|----------|-------|------------|
| devicefarmer/stf | 2-5 min | Facile |
| Build local RPi5 | 30-60 min | Moyen |
| Build sur machine puissante | 10-15 min | Facile |

## Support

Si aucune solution ne fonctionne, consultez :
- `docker/SOLUTION_ARM64.md` pour plus de détails
- https://github.com/DeviceFarmer/stf/issues
- https://github.com/DeviceFarmer/stf/discussions

## Note

DeviceFarmer/STF est le fork actif et maintenu d'OpenSTF, donc leur image est probablement plus à jour et compatible multi-architecture.
