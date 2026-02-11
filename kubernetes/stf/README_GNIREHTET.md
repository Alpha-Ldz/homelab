# Gnirehtet ARM64 - Internet via USB sans WiFi

## TL;DR - Démarrage rapide

```bash
# 1. Builder l'image (sur rpi5 ou votre PC)
cd ~/homelab/kubernetes/stf
./build-gnirehtet.sh

# 2. Déployer sur K8s
kubectl apply -f adb-with-gnirehtet.yaml

# 3. Vérifier
kubectl get pods -n stf -l app=adb
kubectl logs -n stf -l app=adb -c gnirehtet -f

# 4. Tester depuis Freedom35
cd ~/Freedom35
poetry run freedom35 network test
```

## Fichiers créés

```
~/homelab/kubernetes/stf/
├── Dockerfile.gnirehtet          # Dockerfile pour compiler Gnirehtet ARM64
├── build-gnirehtet.sh            # Script de build automatisé
├── adb-with-gnirehtet.yaml       # Déploiement ADB + Gnirehtet (sidecar)
├── GNIREHTET_DEPLOYMENT.md       # Documentation complète
└── README_GNIREHTET.md           # Ce fichier (résumé)
```

## Ce qui va se passer

1. **Build** : Compilation de Gnirehtet depuis les sources Rust pour ARM64 (~10-15 min)
2. **Image** : Création d'une image Docker `gnirehtet:arm64` (~150 MB)
3. **Déploiement** : Pod ADB avec 2 containers (ADB + Gnirehtet)
4. **VPN** : Gnirehtet crée un VPN sur Android → Internet via USB

## Architecture

```
Freedom35 (PC) → kubectl → Pod ADB (rpi5)
                              ├─ ADB
                              └─ Gnirehtet → VPN → Internet
                                    ↓
                                Android (USB)
```

## Avantages

✅ **Pas de WiFi** : Internet 100% via USB/ADB
✅ **ARM64 natif** : Compilé pour votre architecture
✅ **Automatique** : Redémarre avec le pod
✅ **Simple** : Tout dans le même pod (sidecar)

## Prérequis

- Docker installé sur rpi5 (ou buildx sur votre PC)
- Rust toolchain (géré automatiquement par le Dockerfile)
- ~2 GB d'espace disque pour la compilation

## Temps estimé

- **Build** : 10-15 minutes (première fois)
- **Déploiement** : 30 secondes
- **Premier établissement VPN** : 10-30 secondes

## Documentation

- **Guide complet** : `GNIREHTET_DEPLOYMENT.md`
- **Troubleshooting** : Voir section dans `GNIREHTET_DEPLOYMENT.md`

## Support

En cas de problème :

1. Voir les logs : `kubectl logs -n stf -l app=adb -c gnirehtet -f`
2. Vérifier le pod : `kubectl describe pod -n stf -l app=adb`
3. Consulter la doc complète : `GNIREHTET_DEPLOYMENT.md`
