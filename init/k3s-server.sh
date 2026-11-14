#!/usr/bin/env bash
# Bootstrap du control-plane K3s sur le Raspberry Pi 5 (remplace init.sh / kubeadm).
# Prérequis : Raspberry Pi OS (trixie), Tailscale connecté, cgroups activés dans
# /boot/firmware/cmdline.txt : cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
set -euo pipefail

TS_IP="$(tailscale ip -4)"          # 100.92.158.122 — IP stable du nœud
TS_NAME="raspberrypi.tail0c5f5e.ts.net"

# Tout le trafic du cluster passe par Tailscale (prêt pour le worker x86 "sleeper").
curl -sfL https://get.k3s.io | sh -s - \
  --node-ip="$TS_IP" \
  --advertise-address="$TS_IP" \
  --flannel-iface=tailscale0 \
  --tls-san="$TS_NAME" \
  --tls-san=192.168.1.37

# kubectl sans sudo
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
grep -q KUBECONFIG ~/.bashrc || echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
export KUBECONFIG=~/.kube/config

# Le Pi est toujours allumé : il héberge les services "always-on" (dashboard, imprimante…).
kubectl label node "$(hostname)" homelab/always-on=true --overwrite

# Portainer
kubectl apply -f https://downloads.portainer.io/ce2-45/portainer.yaml

# Worker x86 (plus tard), sur la machine "sleeper" avec Tailscale :
#   curl -sfL https://get.k3s.io | K3S_URL=https://$TS_IP:6443 K3S_TOKEN=<node-token> sh -s - \
#     --node-ip="$(tailscale ip -4)" --flannel-iface=tailscale0
#   token : sudo cat /var/lib/rancher/k3s/server/node-token (sur le Pi)
# Puis, depuis le Pi : ne rien y planifier par défaut (réveil à la demande) :
#   kubectl taint node sleeper homelab/on-demand=true:NoSchedule
