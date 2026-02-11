# Homelab Services

Documentation des services installés dans le homelab.

## Services de communication

### AnonAddy - Gestionnaire d'alias email
**Path:** `kubernetes/anonaddy/`

Gestionnaire d'alias email open-source pour protéger votre adresse email principale.

**Fonctionnalités:**
- Création illimitée d'alias email
- Transfert automatique vers votre email principal
- Possibilité de répondre via les alias
- Désactivation/activation des alias à la volée
- Protection contre le spam
- Support de domaines personnalisés

**Composants:**
- AnonAddy (application web + API)
- MariaDB (base de données)
- Redis (cache et queues)
- Postfix (serveur SMTP)

**Déploiement:**
```bash
cd kubernetes/anonaddy
# Configurer secrets.yaml et ingress.yaml
./deploy.sh
```

**Documentation:** [kubernetes/anonaddy/README.md](kubernetes/anonaddy/README.md)

### SMS Gateway - API pour réception de SMS
**Path:** `kubernetes/sms-gateway/`

Service API REST pour recevoir des SMS de vérification via différents providers (SMS-Activate, 5SIM).

**Fonctionnalités:**
- Support de multiples providers (SMS-Activate, 5SIM)
- API REST simple et documentée
- Obtention de numéros temporaires
- Réception de codes de vérification
- Gestion du solde
- Annulation d'activations

**Cas d'usage:**
- Tests automatisés nécessitant des vérifications SMS
- Création de comptes multiples
- Développement d'applications nécessitant des validations SMS

**Déploiement:**
```bash
cd kubernetes/sms-gateway
# Configurer secrets.yaml
./build-and-deploy.sh
```

**API Endpoints:**
- `POST /number` - Obtenir un numéro
- `GET /sms/{id}` - Récupérer le SMS
- `GET /balance` - Vérifier le solde
- `POST /cancel/{id}` - Annuler une activation
- `GET /docs` - Documentation Swagger

**Documentation:** [kubernetes/sms-gateway/README.md](kubernetes/sms-gateway/README.md)

## Services existants

### Traefik
Reverse proxy et ingress controller

### Authelia
Service d'authentification et SSO

### MetalLB
Load balancer pour Kubernetes

### Longhorn
Système de stockage persistant

### STF (Smartphone Test Farm)
Plateforme de test de smartphones

### Klipper
Contrôle d'imprimante 3D

### Cloudflared
Tunnel Cloudflare

### Homarr
Dashboard du homelab

## Architecture réseau

```
Internet
    │
    ├─→ Cloudflared Tunnel
    │       │
    │       └─→ Traefik (Ingress Controller)
    │               │
    │               ├─→ Authelia (SSO)
    │               ├─→ Homarr (Dashboard)
    │               ├─→ AnonAddy (Email Aliases)
    │               ├─→ SMS Gateway (API)
    │               └─→ STF (Device Farm)
    │
    └─→ MetalLB (LoadBalancer)
            │
            └─→ Postfix (SMTP - ports 25, 587)
```

## Configuration DNS requise

### Pour AnonAddy
```
anonaddy.yourdomain.com.    A     <IP-publique>
mail.yourdomain.com.        A     <IP-publique>
anonaddy.yourdomain.com.    MX    10 mail.yourdomain.com.
anonaddy.yourdomain.com.    TXT   "v=spf1 ip4:<IP-publique> ~all"
_dmarc.anonaddy.yourdomain.com. TXT "v=DMARC1; p=quarantine;"
```

### Pour SMS Gateway
```
sms.yourdomain.com.         A     <IP-publique>
```

## Maintenance

### Logs
```bash
# AnonAddy
kubectl logs -n anonaddy -l app=anonaddy -f

# SMS Gateway
kubectl logs -n sms-gateway -l app=sms-gateway -f
```

### Backup
```bash
# AnonAddy database
kubectl exec -n anonaddy deployment/mariadb -- \
  mysqldump -uanonaddy -p<password> anonaddy > backup.sql
```

### Mise à jour
```bash
# AnonAddy
kubectl set image deployment/anonaddy anonaddy=anonaddy/anonaddy:latest -n anonaddy

# SMS Gateway
cd kubernetes/sms-gateway
./build-and-deploy.sh
```

## Support et documentation

- **AnonAddy:** https://anonaddy.com/help
- **SMS-Activate:** https://sms-activate.org/en/api2
- **5SIM:** https://5sim.net/docs
- **Traefik:** https://doc.traefik.io/traefik/
- **Kubernetes:** https://kubernetes.io/docs/
