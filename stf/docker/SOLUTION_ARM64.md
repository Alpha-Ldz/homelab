# Solutions pour STF sur ARM64

Le problème : `openstf/stf:latest` n'a pas de build ARM64, d'où l'erreur `exec format error`.

## Solution 1 : Utiliser DeviceFarmer/STF (Recommandé)

DeviceFarmer est le fork actif de OpenSTF et pourrait avoir des images multi-arch.

### Essayer l'image devicefarmer/stf

```bash
# Tester si l'image devicefarmer/stf fonctionne sur ARM64
docker pull devicefarmer/stf:latest
docker run --rm devicefarmer/stf:latest --version
```

Si ça fonctionne, mettez à jour les manifests :

```bash
cd ~/homelab/stf/docker
./update-manifests.sh devicefarmer/stf:latest
cd ..
./deploy.sh
```

## Solution 2 : Builder STF pour ARM64 (Long ~30-60min)

### Sur le Raspberry Pi 5 directement

```bash
cd ~/homelab/stf/docker
./build-arm64.sh
```

**Attention** : Cela prendra 30-60 minutes sur un RPi5 et consommera beaucoup de RAM.

Ensuite, mettez à jour les manifests :

```bash
./update-manifests.sh stf-arm64:latest
cd ..
./deploy.sh
```

### Ou builder sur une machine plus puissante (cross-compilation)

Sur votre machine de dev (x86_64) :

```bash
# Cloner le repo
git clone https://github.com/DeviceFarmer/stf.git
cd stf

# Builder pour ARM64 avec buildx
docker buildx create --use
docker buildx build \
  --platform linux/arm64 \
  -t stf-arm64:latest \
  --load \
  .

# Sauvegarder l'image
docker save stf-arm64:latest > stf-arm64.tar

# Transférer sur le RPi5
scp stf-arm64.tar peuleu@rpi5:/home/peuleu/

# Sur le RPi5
docker load < ~/stf-arm64.tar
```

Puis mettez à jour les manifests comme ci-dessus.

## Solution 3 : Utiliser un Registry local Kubernetes

### Déployer un registry dans Kubernetes

```bash
kubectl create namespace registry

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
      volumes:
      - name: registry-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  type: NodePort
  ports:
  - port: 5000
    nodePort: 30500
  selector:
    app: registry
EOF
```

### Builder et pousser l'image

```bash
# Builder
cd ~/homelab/stf/docker
./build-arm64.sh

# Tag et push vers le registry local
docker tag stf-arm64:latest localhost:30500/stf-arm64:latest
docker push localhost:30500/stf-arm64:latest

# Mettre à jour les manifests
./update-manifests.sh localhost:30500/stf-arm64:latest
```

## Solution 4 : Utiliser une image pré-buildée tierce

Si quelqu'un a déjà buildé STF pour ARM64, vous pouvez l'utiliser :

```bash
# Exemple (remplacer par une vraie image si disponible)
docker pull <registry>/stf-arm64:latest

# Mettre à jour les manifests
cd ~/homelab/stf/docker
./update-manifests.sh <registry>/stf-arm64:latest
```

## Solution 5 : Utiliser QEMU (Non recommandé - très lent)

En dernier recours, vous pouvez émuler x86_64 sur ARM64 avec QEMU, mais ce sera **TRÈS lent**.

```bash
# Installer QEMU
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Tenter d'utiliser l'image x86_64 (lent)
# Ne pas utiliser en production
```

## Recommandation

**Option 1** est la plus rapide si l'image existe.
**Option 2** (build local) est la plus fiable mais la plus longue.
**Option 3** (registry local) est la meilleure pour un environnement de production.

## Vérification après déploiement

```bash
# Vérifier que les pods démarrent
kubectl get pods -n stf

# Vérifier les logs
kubectl logs -n stf -l app=stf-app

# Ne devrait plus avoir "exec format error"
```

## Aide

Si vous avez besoin d'aide pour builder l'image, contactez la communauté STF :
- https://github.com/DeviceFarmer/stf/issues
- https://github.com/DeviceFarmer/stf/discussions
