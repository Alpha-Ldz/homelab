#!/usr/bin/env bash
# Configuration de Nextcloud après la première installation (idempotent).
#   ./post-install.sh               -> réglages, OIDC Authelia, stockage externe 3D
#   ./post-install.sh grant <user>  -> après la 1re connexion OIDC de <user> : droits admin
#                                      + accès au dossier "Impression 3D"
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
occ() { kubectl -n nextcloud exec -i deploy/nextcloud -c nextcloud -- runuser -u www-data -- php occ "$@"; }

if [ "${1:-}" = "grant" ]; then
  user="${2:?usage: $0 grant <user>}"
  occ group:adduser admin "$user"
  id=$(occ files_external:list --output=json | python3 -I -c 'import json,sys
print(next((m["mount_id"] for m in json.load(sys.stdin) if m["mount_point"]=="/Impression 3D"), ""))')
  [ -n "$id" ] && occ files_external:applicable --add-user="$user" "$id"
  exit 0
fi

# --- Réglages généraux
occ background:cron
occ config:system:set overwritehost --value=nextcloud.freedom35.fr
occ config:system:set default_phone_region --value=FR
occ config:system:set maintenance_window_start --type=integer --value=1
# Cloudflare (offre gratuite) refuse les requêtes > 100 Mo : envois découpés en morceaux de 90 Mo
occ config:app:set files max_chunk_size --value=94371840
occ db:add-missing-indices
occ maintenance:repair --include-expensive

# --- Connexion via Authelia (OIDC, mot de passe + TOTP)
occ app:install user_oidc || occ app:enable user_oidc
secret=$(kubectl -n nextcloud get secret nextcloud-secrets -o jsonpath='{.data.OIDC_CLIENT_SECRET}' | base64 -d)
occ user_oidc:provider Authelia \
  --clientid=nextcloud \
  --clientsecret="$secret" \
  --discoveryuri=https://auth.freedom35.fr/.well-known/openid-configuration \
  --scope="openid email profile groups" \
  --unique-uid=0 \
  --mapping-uid=preferred_username \
  --mapping-display-name=name \
  --mapping-email=email
# Redirection automatique vers Authelia. Compte de secours ncadmin : /login?direct=1
occ config:app:set user_oidc allow_multiple_user_backends --value=0

# --- Dossier partagé avec Klipper (/srv/files/3d sur l'hôte, /mnt/3d dans le pod)
occ app:enable files_external
if ! occ files_external:list --output=json | grep -q '"mount_point":"\\/Impression 3D"'; then
  occ files_external:create "/Impression 3D" local null::null -c datadir=/mnt/3d
fi
echo "OK. Après ta première connexion via Authelia : $0 grant admin"
