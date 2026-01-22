# STF - Démarrage rapide

## Déploiement en 3 étapes

### 1. Préparer votre appareil Android
```bash
# Sur votre appareil Android :
# - Paramètres > À propos du téléphone
# - Tapez 7 fois sur "Numéro de build"
# - Retour > Options pour développeurs
# - Activer "Débogage USB"
# - Connecter l'appareil en USB au Raspberry Pi
# - Autoriser le débogage USB (popup)
```

### 2. Configurer le DNS
```bash
# Ajouter à /etc/hosts (remplacer par l'IP de votre cluster)
echo "192.168.1.100  stf.local" | sudo tee -a /etc/hosts
```

### 3. Déployer STF
```bash
cd stf/
./deploy.sh
```

**C'est tout !** 🎉

## Accès

- **Interface Web** : http://stf.local
- **API** : http://stf.local/api/v1/

## Commandes utiles

```bash
# Voir l'état
make status

# Voir les devices détectés
make devices

# Voir les logs du provider
make logs-provider

# Redémarrer le provider
make restart-provider

# Diagnostic complet
./troubleshoot.sh

# Désinstaller
make delete
```

## Troubleshooting express

### Device non détecté ?
```bash
# 1. Vérifier USB sur le host
lsusb | grep -i android

# 2. Vérifier dans le pod
make devices

# 3. Redémarrer le provider
make restart-provider
```

### Interface web inaccessible ?
```bash
# 1. Vérifier l'ingress
kubectl get ingress -n stf

# 2. Vérifier les pods
make status

# 3. Vérifier le DNS/hosts
ping stf.local
```

### RethinkDB ne démarre pas ?
```bash
# Vérifier les PVC
kubectl get pvc -n stf

# Logs RethinkDB
make logs-rethinkdb

# Réduire la RAM si nécessaire (éditer rethinkdb/deployment.yaml)
# Changer --cache-size à 256 ou moins
```

## Architecture simplifiée

```
┌─────────────────────────────────────────────┐
│  Ingress (nginx)                            │
│  http://stf.local                           │
└────┬─────────────────────────────────────┬──┘
     │                                      │
     ▼                                      ▼
┌─────────┐  ┌──────┐  ┌──────┐      ┌──────────┐
│   App   │  │ API  │  │ Auth │      │ Websocket│
│  (Web)  │  │(REST)│  │(Mock)│      │  (WS)    │
└────┬────┘  └───┬──┘  └───┬──┘      └────┬─────┘
     │           │         │               │
     └───────────┴─────────┴───────────────┘
                 │
                 ▼
          ┌──────────────┐
          │  Triproxy    │  ◄─── Hub ZeroMQ
          │  (ZeroMQ)    │
          └──┬───────┬───┘
             │       │
     ┌───────┘       └──────────┐
     ▼                          ▼
┌─────────┐            ┌──────────────┐
│ Storage │            │   Provider   │
│(APK/IMG)│            │ (USB/ADB)    │
└─────────┘            └──────┬───────┘
                              │
     ▼                        ▼
┌──────────┐          ┌─────────────────┐
│RethinkDB │          │ Android Devices │
│   (DB)   │          │     (USB)       │
└──────────┘          └─────────────────┘
```

## Ressources

- **README complet** : `README.md`
- **Documentation STF** : https://github.com/openstf/stf
- **Diagnostic** : `./troubleshoot.sh`
- **Makefile** : `make help`

## Configuration ARM64

Les images Docker utilisées sont compatibles ARM64 :
- `openstf/stf:latest` (multi-arch)
- `rethinkdb:2.4` (ARM64 supporté)

Les ressources sont optimisées pour Raspberry Pi 5 :
- RethinkDB : cache limité à 512MB
- Chaque service : 128-512MB RAM max
- CPU limité pour éviter l'overload

## Prochaines étapes

1. **Sécuriser** : Changer le SECRET dans `base/configmap.yaml`
2. **HTTPS** : Configurer TLS sur l'ingress
3. **Auth réelle** : Remplacer auth-mock par LDAP/OAuth
4. **Monitoring** : Ajouter Prometheus/Grafana
5. **Backup** : Sauvegarder RethinkDB régulièrement

---

Pour plus de détails, consultez le **README.md** complet.
