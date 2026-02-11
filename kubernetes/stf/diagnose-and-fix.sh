#!/bin/bash
set -e

TAG="gnirehtet-20260211-215901"

echo "=========================================="
echo "DIAGNOSTIC COMPLET"
echo "=========================================="
echo ""

echo "Tag recherché: $TAG"
echo ""

echo "1. Images dans Docker:"
sudo docker images | grep gnirehtet || echo "  Aucune"
echo ""

echo "2. Images dans containerd (ctr):"
sudo ctr -n k8s.io images ls | grep gnirehtet || echo "  Aucune"
echo ""

echo "3. Images dans containerd (crictl):"
sudo crictl images 2>/dev/null | grep gnirehtet || echo "  Aucune"
echo ""

# Vérifier si l'image existe dans Docker
if sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${TAG}$"; then
    echo "✅ Image trouvée dans Docker"
    echo ""

    echo "4. Test de l'image Docker:"
    sudo docker run --rm --entrypoint sh "$TAG" -c "adb version" || echo "  ❌ adb manquant!"
    echo ""

    echo "5. Import dans containerd avec ctr..."
    sudo docker save "$TAG" -o "/tmp/gnirehtet.tar"

    # Essayer différentes méthodes d'import
    echo "  Tentative 1: import basique"
    sudo ctr -n k8s.io images import "/tmp/gnirehtet.tar" || true

    echo "  Tentative 2: import avec all-platforms"
    sudo ctr -n k8s.io images import --all-platforms "/tmp/gnirehtet.tar" || true

    sudo rm "/tmp/gnirehtet.tar"
    echo ""

    echo "6. Vérification après import:"
    sudo ctr -n k8s.io images ls | grep gnirehtet || echo "  Toujours aucune!"
    echo ""

    # Si toujours pas présente, essayer avec crictl
    echo "7. Tentative d'import avec crictl..."
    sudo docker save "$TAG" -o "/tmp/gnirehtet.tar"
    sudo crictl pull --creds PLACEHOLDER "/tmp/gnirehtet.tar" 2>/dev/null || {
        # crictl ne peut pas charger des tar locaux, utilisons une autre approche
        echo "  crictl ne peut pas charger des tar"

        # Dernière tentative: charger dans containerd avec docker-archive
        echo "8. Import via docker-archive..."
        sudo ctr -n k8s.io images import --digests "/tmp/gnirehtet.tar"
    }
    sudo rm -f "/tmp/gnirehtet.tar"
    echo ""

    echo "9. État final dans containerd:"
    sudo ctr -n k8s.io images ls | grep gnirehtet || echo "  ÉCHEC TOTAL"
    echo ""

    # Si l'image est maintenant présente, redémarrer le pod
    if sudo ctr -n k8s.io images ls | grep -q "$TAG"; then
        echo "✅ Image présente dans containerd!"
        echo ""
        echo "10. Redémarrage du pod..."
        kubectl delete pod -n stf -l app=adb
        sleep 5
        kubectl wait --for=condition=ready pod -l app=adb -n stf --timeout=120s

        POD=$(kubectl get pod -n stf -l app=adb -o jsonpath='{.items[0].metadata.name}')
        echo "✅ Pod: $POD"
        echo ""

        kubectl exec -n stf $POD -c gnirehtet -- adb version
        echo ""
        echo "=========================================="
        echo "🎉 SUCCÈS !"
        echo "=========================================="
    else
        echo "❌ ÉCHEC: Impossible d'importer l'image dans containerd"
        echo ""
        echo "SOLUTION ALTERNATIVE:"
        echo "Changez imagePullPolicy de 'Never' à 'IfNotPresent' dans le deployment"
        echo "Ou utilisez un registry local"
    fi
else
    echo "❌ Image $TAG non trouvée dans Docker"
    echo ""
    echo "Il faut d'abord la créer avec:"
    echo "  cd ~/homelab/kubernetes/stf"
    echo "  sudo docker build --no-cache -f Dockerfile.gnirehtet -t $TAG --build-arg GNIREHTET_VERSION=v2.5.1 ."
fi
