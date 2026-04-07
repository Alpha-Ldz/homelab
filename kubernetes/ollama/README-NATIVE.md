# Ollama Natif sur NixOS avec RTX 5090

## Vue d'ensemble

Configuration d'Ollama natif sur NixOS (machine `sleeper`) avec GPU NVIDIA RTX 5090, accessible depuis Kubernetes via un Service/Endpoint externe.

## Architecture

```
┌─────────────────────────────────────────────┐
│  sleeper (NixOS k3s-server mode)            │
│  ┌───────────────────────────────────────┐  │
│  │  Ollama Natif (systemd)               │  │
│  │  - Port: 11434                        │  │
│  │  - GPU: RTX 5090 (si d\u00e9tect\u00e9)         │  │
│  │  - Storage: /var/lib/ollama/models    │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
                    ▲
                    │ http://192.168.1.158:11434
                    │
┌─────────────────────────────────────────────┐
│  Kubernetes Cluster                         │
│  ┌───────────────────────────────────────┐  │
│  │  Service: ollama.ollama.svc          │  │
│  │  Endpoint: 192.168.1.158:11434       │  │
│  └───────────────────────────────────────┘  │
│                   │                          │
│  ┌───────────────────────────────────────┐  │
│  │  OpenClaw Pod                        │  │
│  │  - Uses: http://ollama.ollama.svc... │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

## Configuration NixOS

### Fichier: `nixos-config/features/services/ollama-server.nix`

```nix
services.ollama = {
  enable = true;
  package = pkgs-unstable.ollama.override {
    acceleration = "cuda";
  };
  host = "0.0.0.0";
  port = 11434;
  acceleration = "cuda";

  environmentVariables = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
    CUDA_PATH = "/run/opengl-driver";
    OLLAMA_DEBUG = "1";
    NVIDIA_VISIBLE_DEVICES = "all";
    NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
  };
};
```

### Activation

Pour utiliser Ollama natif, démarrer en mode `k3s-server` :

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --specialisation k3s-server
```

Ou au boot, sélectionner "NixOS (k3s-server)" dans le menu systemd-boot.

## Problème Connu: RTX 5090 Blackwell

### Symptômes

- Ollama 0.18.0 ne détecte pas le GPU RTX 5090
- Logs montrent: `initial_count=0` et `total_vram="0 B"`
- Fallback sur CPU uniquement

### Cause

La RTX 5090 utilise l'architecture **Blackwell (GB202)** avec **compute capability 12.0**, qui nécessite :
- CUDA 13.0+ (nous avons CUDA 12.8)
- Support incomplet dans Ollama 0.18.0

### Références

- GitHub Issue: https://github.com/ollama/ollama/issues/13338
- NixOS Discourse: https://discourse.nixos.org/t/nvidia-offload-with-ollama-not-recognising-gpu/63961
- NVIDIA Driver: 580.119.02 (OK)
- CUDA Toolkit: 12.8 (insuffisant pour Blackwell)

### Vérifications

```bash
# Vérifier que le GPU est détecté par le driver
lspci | grep -i nvidia
# Output: 05:00.0 VGA compatible controller: NVIDIA Corporation GB202 [GeForce RTX 5090]

# Vérifier les modules kernel NVIDIA
lsmod | grep nvidia

# Vérifier le service Ollama
systemctl status ollama
journalctl -u ollama.service -n 50 | grep GPU

# UUID du GPU (pour référence)
cat /proc/driver/nvidia/gpus/*/information | grep "GPU UUID"
# Output: GPU-845851fc-ba8a-f233-707c-6c4f5d9648ba
```

### Workarounds Tentés

1. ✅ Ajout de `NVIDIA_VISIBLE_DEVICES="all"`
2. ✅ Ajout de `NVIDIA_DRIVER_CAPABILITIES="compute,utility"`
3. ❌ `CUDA_VISIBLE_DEVICES="0"` (cause warning, retiré)
4. ✅ Configuration utilisateur/groupe ollama avec permissions GPU
5. ❌ Recharge module `nvidia_uvm` (pas nécessaire)

### Solutions Potentielles

1. **Attendre Ollama > 0.18.0** avec support Blackwell complet
2. **Compiler Ollama** depuis source avec CUDA 13.0+
3. **Utiliser le deployment Kubernetes** existant (fonctionnel)

## Deployment Kubernetes (Alternative Fonctionnelle)

Le deployment Ollama dans Kubernetes (`kubernetes/ollama/deployment.yaml`) fonctionne et détecte le GPU via nvidia-container-toolkit.

Avantages:
- GPU détecté et fonctionnel
- Isolation via containers
- Gestion via K8s (scaling, health checks)

Inconvénients:
- Overhead du container runtime
- Configuration plus complexe (drivers dans container)

## Service Kubernetes vers Ollama Natif

### Fichier: `kubernetes/ollama/service-external.yaml`

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ollama
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 11434
      targetPort: 11434
---
apiVersion: v1
kind: Endpoints
metadata:
  name: ollama
  namespace: ollama
subsets:
  - addresses:
      - ip: 192.168.1.158  # sleeper IP
    ports:
      - name: http
        port: 11434
```

### Application

```bash
kubectl apply -f kubernetes/ollama/service-external.yaml

# Vérifier
kubectl get svc -n ollama ollama
kubectl get endpoints -n ollama ollama

# Tester depuis un pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://ollama.ollama.svc.cluster.local:11434/api/version
```

## Gestion des Modèles

### Télécharger un modèle

```bash
# Via curl direct
curl -X POST http://localhost:11434/api/pull \
  -d '{"name": "qwen2.5:27b"}'

# Via ollama CLI (sur sleeper)
ollama pull qwen2.5:27b
```

### Lister les modèles

```bash
curl http://localhost:11434/api/tags | jq '.models[] | {name, size}'

# Ou
ollama list
```

### Espace disque

```bash
du -sh /var/lib/ollama/models
```

## Configuration OpenClaw

### Fichier: `kubernetes/openclaw/values.yaml`

Modifier la section `models.providers.ollama`:

```yaml
models:
  providers:
    ollama:
      baseUrl: "http://ollama.ollama.svc.cluster.local:11434"
      apiKey: "ollama-local"
      models:
        - id: "qwen2.5:27b"
          name: "Qwen 2.5 27B - Native Ollama"
```

Appliquer:

```bash
helm upgrade openclaw ./kubernetes/openclaw \
  -f kubernetes/openclaw/values.yaml \
  -n openclaw
```

## Monitoring

### Logs Ollama

```bash
journalctl -u ollama.service -f
journalctl -u ollama.service -n 100 | grep -E "GPU|vram|cuda"
```

### Métriques GPU

```bash
# Sur sleeper
watch -n 1 nvidia-smi

# Depuis K8s (si nvidia-smi disponible dans container)
kubectl exec -n ollama deployment/ollama -- nvidia-smi
```

## Firewall

Port 11434 est ouvert automatiquement par la configuration NixOS:

```nix
networking.firewall.allowedTCPPorts = [ 11434 ];
```

Vérifier:

```bash
ss -tlnp | grep 11434
curl http://192.168.1.158:11434/api/version
```

## Troubleshooting

### Ollama ne démarre pas

```bash
systemctl status ollama
journalctl -u ollama.service -n 100
```

### GPU non détecté

```bash
# Vérifier driver
nvidia-smi

# Vérifier permissions
id ollama
ls -l /dev/nvidia*

# Recharger module UVM
sudo rmmod nvidia_uvm && sudo modprobe nvidia_uvm
systemctl restart ollama
```

### Service K8s non accessible

```bash
# Vérifier endpoint
kubectl get endpoints -n ollama ollama -o yaml

# Tester connectivité depuis pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl -v http://192.168.1.158:11434/api/version
```

## Statut Actuel

- ✅ Ollama natif configuré et en cours d'exécution
- ✅ Port 11434 ouvert et accessible
- ❌ GPU RTX 5090 **non détecté** (problème Blackwell)
- ✅ Fallback CPU fonctionnel
- ✅ Service K8s externe prêt
- ⏳ En attente support complet RTX 5090 dans Ollama

## Prochaines Étapes

1. ✅ Rebuild NixOS avec configuration mise à jour (fait)
2. ✅ Créer service/endpoint Kubernetes (fait - `service-external.yaml`)
3. ⏳ Attendre Ollama > 0.18.0 ou CUDA 13.0+ pour support RTX 5090
4. ⏳ Configurer OpenClaw pour utiliser le service externe
5. ⏳ Télécharger modèle qwen2.5:27b

## Notes

- En attendant le support GPU complet, le deployment Kubernetes existant peut être utilisé
- Le service externe peut pointer vers le deployment K8s au lieu du natif
- La configuration est prête et activera automatiquement le GPU une fois supporté
