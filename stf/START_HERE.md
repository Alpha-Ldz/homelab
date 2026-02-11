# 🚨 START HERE - Fix ARM64

## Le problème que vous rencontrez

```
exec /app/bin/stf: exec format error
```

**Cause** : L'image Docker `openstf/stf:latest` n'existe pas en version ARM64 pour votre Raspberry Pi 5.

## Solution en 1 commande

```bash
cd ~/homelab/stf
./fix-arm64.sh
```

Choisissez l'**option 1** (la plus rapide, 2 minutes).

Si l'option 1 échoue, relancez et choisissez l'**option 2** (build local, 30-60 minutes).

## Alternative : Test manuel

Si vous voulez d'abord tester quelle image fonctionne :

```bash
./test-docker-image.sh
```

Ce script testera automatiquement plusieurs images et vous dira laquelle fonctionne sur ARM64.

## Ce qui va se passer

1. Le script va nettoyer votre déploiement STF actuel
2. Il va soit :
   - Tester `devicefarmer/stf:latest` (fork actif de STF)
   - Ou builder STF pour ARM64 localement
3. Mettre à jour tous les manifests Kubernetes
4. Redéployer STF avec l'image compatible

## Après le fix

Vérifiez que tout fonctionne :

```bash
# Voir l'état des pods (tous doivent être Running)
kubectl get pods -n stf

# Plus d'erreur "exec format error"
kubectl logs -n stf -l app=stf-app

# Devices détectés
make devices

# Accéder à l'interface
http://stf.local
```

## Si vous voulez comprendre le problème

Lisez ces fichiers dans l'ordre :
1. `ARM64_QUICKFIX.md` - Solutions rapides
2. `docker/SOLUTION_ARM64.md` - Explications détaillées
3. `README.md` - Documentation complète

## Besoin d'aide ?

- **Problème de build** : Consultez `docker/SOLUTION_ARM64.md`
- **Problème de déploiement** : `./troubleshoot.sh`
- **Documentation complète** : `README.md`

---

**TL;DR** : Lancez `./fix-arm64.sh` et suivez les instructions.
