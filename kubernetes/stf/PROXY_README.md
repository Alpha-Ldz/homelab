# Proxy HTTP pour Android

Service proxy HTTP (Squid) permettant aux appareils Android de se connecter à Internet via le cluster Kubernetes.

## Déploiement

```bash
# Déployer le proxy
kubectl apply -f ~/homelab/kubernetes/stf/proxy.yaml

# Vérifier le déploiement
kubectl get pods -n stf | grep proxy
kubectl get svc -n stf proxy
```

## Vérification

```bash
# Vérifier que le pod est en cours d'exécution
kubectl get pods -n stf -l app=proxy

# Voir les logs
kubectl logs -n stf -l app=proxy -f

# Tester le service
kubectl get svc -n stf proxy
```

## Utilisation avec Freedom35

Le proxy est accessible via le DNS interne Kubernetes :

```python
from freedom35 import ADBClient, NetworkManager
from freedom35.config_loader import get_config_loader

config_loader = get_config_loader()
adb_config = config_loader.get_adb_config()

with ADBClient(**adb_config.to_client_kwargs()) as client:
    network = NetworkManager(client)

    # Configurer l'Android pour utiliser le proxy
    network.set_proxy('proxy.stf.svc.cluster.local', 3128)

    # Tester la connectivité
    result = network.test_connectivity()
    print(f"Internet: {'✓' if result['success'] else '✗'}")
```

## Configuration dans config.yaml (Freedom35)

Ajoutez dans `~/Freedom35/config.yaml` :

```yaml
default: development

profiles:
  development:
    adb:
      mode: kubernetes
      namespace: stf
      service: adb

    network:
      proxy_host: proxy.stf.svc.cluster.local
      proxy_port: 3128
```

## Désinstallation

```bash
kubectl delete -f ~/homelab/kubernetes/stf/proxy.yaml
```

## Troubleshooting

### Le pod ne démarre pas

```bash
# Voir les events
kubectl describe pod -n stf -l app=proxy

# Voir les logs
kubectl logs -n stf -l app=proxy
```

### Le proxy ne répond pas

```bash
# Tester depuis un autre pod
kubectl run -n stf test --image=curlimages/curl --rm -it -- sh
# Puis dans le pod :
curl -I --proxy proxy.stf.svc.cluster.local:3128 http://www.google.com
```

### Voir le trafic qui passe par le proxy

```bash
# Voir les logs d'accès Squid
kubectl logs -n stf -l app=proxy -f | grep access.log
```

## Architecture

```
Freedom35 (PC de dev)
       ↓
  kubectl port-forward
       ↓
  Service ADB (K8s)
       ↓
  Android device (USB)
       ↓
  Service Proxy (K8s)
       ↓
    Internet
```

## Spécifications

- **Type de service** : ClusterIP (interne au cluster)
- **Port** : 3128 (standard Squid)
- **Image** : ubuntu/squid:latest
- **Ressources** :
  - Requests: 256Mi RAM, 100m CPU
  - Limits: 512Mi RAM, 500m CPU
- **Cache** : 100 MB (emptyDir)
- **Logs** : emptyDir (non persistant)
