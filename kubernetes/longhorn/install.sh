#!/bin/bash
set -e

# -------------------------------
# Configuration
# -------------------------------
# Version Longhorn à récupérer
LONGHORN_VERSION="v1.10.0"
# URL du déploiement officiel
LONGHORN_URL="https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VERSION}/deploy/longhorn.yaml"
# Chemin local temporaire pour le YAML
TMP_YAML="./longhorn.yaml"

# Si k3s < 0.10.0, définir le kubelet root dir
# Remplacez ceci par le data-dir de votre k3s
K3S_DATA_DIR="/var/lib/rancher/k3s"
KUBELET_ROOT_DIR="${K3S_DATA_DIR}/agent/kubelet"

# Namespace Longhorn
LONGHORN_NAMESPACE="longhorn-system"

# -------------------------------
# Étape 1 : Récupérer le YAML
# -------------------------------
echo "Téléchargement du YAML Longhorn..."
curl -L $LONGHORN_URL -o $TMP_YAML

# -------------------------------
# Étape 2 : Modifier le kubelet-root-dir si nécessaire
# -------------------------------
echo "Modification de longhorn-driver-deployer pour k3s < 0.10.0..."
# On cherche le container longhorn-driver-deployer et on ajoute l'argument
# Si l'argument existe déjà, on le remplace
sed -i "/name: longhorn-driver-deployer/{n; n; :a; n; /args:/!ba; n; s|--kubelet-root-dir=.*|--kubelet-root-dir=${KUBELET_ROOT_DIR}|}" $TMP_YAML || true

# Si ton k3s ≥ 0.10.0, cette étape est optionnelle

# -------------------------------
# Étape 3 : Déployer Longhorn
# -------------------------------
echo "Déploiement de Longhorn..."
kubectl apply -f $TMP_YAML

# -------------------------------
# Étape 4 : Vérification
# -------------------------------
echo "Vérification des pods Longhorn..."
kubectl get pods -n $LONGHORN_NAMESPACE

echo "Longhorn a été déployé avec succès !"
