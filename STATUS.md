# Homelab — état actuel

_Mis à jour le 15/11/2026._

Cluster **K3s mono-nœud** sur un Raspberry Pi 5, piloté par des manifests Kubernetes
versionnés dans ce dépôt (`kubectl apply -k kubernetes/<service>`). Un PC x86 avec GPU
(`sleeper`) rejoindra le cluster plus tard comme worker allumé à la demande (Wake-on-LAN).

```
            Internet                                  Tes appareils (Tailscale)
               │                                                │
     Cloudflare (DNS + tunnel)                        100.92.158.122 / raspberrypi.tail0c5f5e.ts.net
               │  connexion sortante, HTTP/2                    │
┌──────────────┼─────────────── Raspberry Pi 5 — K3s ───────────┼──────────────┐
│        cloudflared ──▶ Traefik (ingress, ports 80/443) ◀──────┘              │
│                           │   └─ forward-auth ──▶ Authelia (SSO + TOTP, OIDC)│
│        ┌──────────┬───────┴───┬───────────┬──────────┬──────────┐            │
│     Homarr   Mainsail/Klipper  Nextcloud   Immich    Backrest   Portainer    │
│              OrcaSlicer │ USB     │          │          │       (NodePort)   │
│              Ender-5 S1           └──── /srv/files ─────┘                    │
│                                     (futurs disques 4×5 To)                  │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Nœuds

| Nœud | Rôle | Matériel | État |
|---|---|---|---|
| `raspberrypi` | control-plane + tous les services, label `homelab/always-on=true` | Pi 5, ARM64, 8 Go RAM, NVMe 238 Go | actif |
| `sleeper` | worker GPU à la demande (taint `homelab/on-demand`) | x86_64, GPU NVIDIA | à ajouter |

- OS : Raspberry Pi OS (Debian 13 trixie), kernel 6.18, cgroups mémoire activés (`/boot/firmware/cmdline.txt`)
- K3s `v1.37.2+k3s1`, installé par [`init/k3s-server.sh`](init/k3s-server.sh)
- **Tout le trafic du cluster passe par Tailscale** (`--node-ip` / `--flannel-iface=tailscale0`) :
  l'IP LAN (192.168.1.37, DHCP) peut changer sans impact.
- Ajout du worker : voir les commentaires en fin de `init/k3s-server.sh`.

## Accès et réseau

- **Public** : `*.freedom35.fr` → Cloudflare → tunnel `258f54c7-…` (cloudflared dans le cluster,
  2 réplicas, HTTP/2 forcé car QUIC/UDP est bloqué) → `traefik.traefik.svc.cluster.local:80`.
  Cet alias (`kubernetes/traefik/traefik-alias.yaml`) pointe vers le Traefik intégré à K3s.
- **Privé** : via Tailscale (Portainer, accès direct Immich sans la limite Cloudflare).
- Nouvelle route publique : ajouter le hostname dans le dashboard Cloudflare
  (*Networks → Tunnels → Public Hostnames*, `HTTP` → `traefik.traefik.svc.cluster.local:80`)
  + un Ingress dans le dossier du service.
- ⚠️ Cloudflare (offre gratuite) limite les requêtes à **100 Mo** : Nextcloud envoie par morceaux
  de 90 Mo ; pour Immich mobile, utiliser l'URL Tailscale.

## Services

| Service | URL | Version | Authentification | Dossier |
|---|---|---|---|---|
| Authelia | https://auth.freedom35.fr | 4.39.28 | mot de passe + TOTP | `kubernetes/authelia` |
| Homarr (dashboard) | https://home.freedom35.fr | 2.13.1 | forward-auth + OIDC | `kubernetes/homarr` |
| Mainsail + Klipper + Moonraker | https://mainsail.freedom35.fr | Mainsail 2.19.0, Klipper 0.13.0, Moonraker 0.11.0 | forward-auth (2FA) | `kubernetes/klipper` |
| Nextcloud | https://nextcloud.freedom35.fr | 35.0.3 (+ PostgreSQL 17, Redis 8) | OIDC (2FA) ; secours `ncadmin` via `/login?direct=1` | `kubernetes/nextcloud` |
| Immich | https://immich.freedom35.fr · Tailscale `:30283` | 3.4.1 | OIDC (2FA) | `kubernetes/immich` |
| Backrest | https://backrest.freedom35.fr | 1.14.1 | forward-auth (2FA) | `kubernetes/backup` |
| OrcaSlicer (trancheur, KasmVNC) | https://orca.freedom35.fr | 2.5.1 (linuxserver ls51) | forward-auth (2FA) | `kubernetes/orcaslicer` |
| Portainer | https://raspberrypi.tail0c5f5e.ts.net:30779 (Tailscale) | CE 2.45.3 | OIDC (2FA) ; compte local de secours | manifest officiel `ce2-45` |
| cloudflared | — | 2026.11.0 | token du tunnel | `kubernetes/cloudflared` |
| Traefik | — | intégré à K3s | — | `kubernetes/traefik` (HelmChartConfig) |

### Authentification (Authelia)

- Compte unique `admin` (groupe `admins`), utilisateurs dans le Secret `authelia/authelia-users`.
- `default_policy: deny` ; `two_factor` pour home, mainsail, backrest, orca.
- **Forward-auth** : annotation `traefik.ingress.kubernetes.io/router.middlewares: authelia-forwardauth@kubernetescrd`
  sur l'Ingress + règle dans `access_control` (`kubernetes/authelia/configmap.yaml`).
- **OIDC** (SSO) : clients `homarr`, `portainer`, `nextcloud`, `immich`, tous en `two_factor`.
  Pas de forward-auth sur Nextcloud et Immich (les apps mobiles/desktop doivent joindre l'API).
- Pas de SMTP : les codes de vérification sont dans
  `kubectl -n authelia exec deploy/authelia -- cat /data/notification.txt`.

### Imprimante 3D

Creality Ender-5 S1 sous Klipper, plateau G10 fixe avec maillage 50×50 sauvegardé, tranchée avec
OrcaSlicer (Cura n'est plus utilisé). Matériel, étalonnage, procédures et pièges :
**[`kubernetes/klipper/PRINTER.md`](kubernetes/klipper/PRINTER.md)**.

- La config active vit dans le volume du pod (`config/` du dépôt = seed du premier démarrage) :
  garder les deux synchronisées (voir PRINTER.md).
- Après un redémarrage de l'imprimante ou du pod : `FIRMWARE_RESTART` dans Mainsail.
- OrcaSlicer exporte dans `/gcodes` (= `/srv/files/3d/gcodes`, visible dans Mainsail) ou envoie
  directement à `http://klipper.klipper.svc.cluster.local:7125`.

## Stockage

| Emplacement | Contenu | Support |
|---|---|---|
| `/var/lib/rancher/k3s/storage` | volumes `local-path` : bases PostgreSQL, SQLite (Authelia, Homarr), config Klipper, profils OrcaSlicer, code Nextcloud, cache ML Immich, état Backrest | NVMe |
| `/srv/files/nextcloud` | fichiers Nextcloud (uid 33) | NVMe → futurs disques |
| `/srv/files/photos` | photothèque Immich | NVMe → futurs disques |
| `/srv/files/3d/gcodes` | gcodes, partagés Klipper ↔ Nextcloud (dossier « Impression 3D ») ↔ OrcaSlicer via ACL | NVMe → futurs disques |
| `/srv/files/dumps` | dumps SQL quotidiens Nextcloud / Immich | NVMe → futurs disques |
| `/srv/files/backups/restic` | dépôt de sauvegarde | NVMe → futurs disques |

**Disques prévus** : 4×5 To dans un boîtier USB 3 alimenté, mergerfs + SnapRAID (~15 To utiles),
montés sur `/srv/files` — aucun manifest à modifier, seulement copier les données.

## Sauvegardes

| Heure | Tâche |
|---|---|
| 02:30 | dumps PostgreSQL Nextcloud (`pg_dump -Fc`) et Immich (`pg_dumpall`), 3 conservés |
| 03:00 | Backrest/restic : `/srv/files` + volumes K8s, chiffré, dédupliqué |
| 04:00 dim. | prune |
| 05:00 le 1er | check (5 % des données relues) |

- Rétention : 7 quotidiennes, 4 hebdomadaires, 6 mensuelles.
- Exclus (régénérables) : vignettes et transcodages Immich, cache ML, fichiers bruts PostgreSQL.
- Mot de passe du dépôt : Secret `backup/backrest-secrets`, **copie hors du Pi** dans le gestionnaire de mots de passe.
- ⚠️ Dépôt sur le même NVMe que les données : protège des erreurs, pas d'une panne disque.

## Secrets (hors git)

Créés directement dans le cluster ; chaque dossier a un `*.example` qui documente la commande.

| Namespace | Secret | Contenu |
|---|---|---|
| authelia | `authelia-secrets`, `authelia-users`, `authelia-oidc` | clés de session/stockage, utilisateurs, clé JWKS + digests clients OIDC |
| cloudflared | `cloudflared-credentials` | token du tunnel |
| homarr | `homarr-secrets`, `homarr-oidc` | clé de chiffrement, secret client OIDC |
| nextcloud | `nextcloud-secrets` | mots de passe PostgreSQL/Redis/ncadmin, secret client OIDC |
| immich | `immich-secrets` | mot de passe PostgreSQL |
| backup | `backrest-secrets` | mot de passe du dépôt restic |

## Commandes utiles

```bash
export KUBECONFIG=~/.kube/config
kubectl get pods -A                                   # état général
kubectl apply -k kubernetes/<service>                 # (re)déployer un service
kubectl -n <ns> rollout restart deploy/<nom>          # redémarrer
kubectl -n nextcloud exec deploy/nextcloud -c nextcloud -- runuser -u www-data -- php occ <cmd>
kubectl -n immich exec deploy/server -- immich-admin enable-password-login   # secours Immich
./kubernetes/nextcloud/post-install.sh                # reconfigurer Nextcloud (idempotent)
```

## À faire

- [ ] Copie de sauvegarde **hors site** (ex. Backblaze B2, 2e dépôt Backrest)
- [ ] Disques 4×5 To : boîtier USB, mergerfs + SnapRAID, migration de `/srv/files`
- [ ] Ajouter le worker `sleeper` (Tailscale + K3s agent, taint on-demand) ; y déplacer le ML Immich (GPU)
- [ ] Certificats HTTPS pour l'accès via Tailscale (cert-manager + DNS Cloudflare)
- [ ] Désactiver la connexion par mot de passe dans Immich une fois l'OIDC validé
- [ ] Imprimante : étalonner flow, pressure advance, rétraction, température, débit max ; créer les
      profils OrcaSlicer (imprimante / Ender PLA+ / impression) — voir `kubernetes/klipper/PRINTER.md`
- [ ] Déplacer OrcaSlicer sur `sleeper` quand il sera dans le cluster (interface lente sur le Pi)
- [ ] Services de l'ancien cluster pas encore migrés (manifests à reprendre dans `kubernetes/`) :
      Vaultwarden, Stalwart + SnappyMail, STF, OpenClaw, Ollama + Open WebUI (GPU), PostgreSQL partagé
