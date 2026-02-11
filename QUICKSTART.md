# Guide de démarrage rapide

Installation rapide des services AnonAddy et SMS Gateway dans votre homelab.

## Prérequis

- Cluster Kubernetes fonctionnel avec :
  - Traefik (ingress controller)
  - MetalLB (load balancer)
  - Longhorn (storage)
  - cert-manager (certificats SSL)
- Nom de domaine avec accès DNS
- Compte sur SMS-Activate ou 5SIM (pour le SMS Gateway)

## Installation AnonAddy

### 1. Générer la clé d'application

```bash
docker run --rm anonaddy/anonaddy:latest php artisan key:generate --show
```

Copier la sortie (format: `base64:...`)

### 2. Configurer les secrets

Éditer `kubernetes/anonaddy/secrets.yaml` :

```yaml
APP_KEY: "base64:VOTRE_CLE_GENEREE"
APP_URL: "https://anonaddy.votredomaine.com"
MAIL_DOMAIN: "anonaddy.votredomaine.com"
MAIL_HOSTNAME: "mail.votredomaine.com"
MAIL_FROM_ADDRESS: "noreply@anonaddy.votredomaine.com"
DB_ROOT_PASSWORD: "votre_mot_de_passe_root"
DB_PASSWORD: "votre_mot_de_passe_db"
```

### 3. Configurer l'ingress

Éditer `kubernetes/anonaddy/ingress.yaml` :
- Remplacer `anonaddy.yourdomain.com` par votre domaine

### 4. Configurer le DNS

Ajouter ces enregistrements DNS :

```
anonaddy.votredomaine.com.    A     <votre-IP-publique>
mail.votredomaine.com.        A     <votre-IP-publique>
anonaddy.votredomaine.com.    MX    10 mail.votredomaine.com.
anonaddy.votredomaine.com.    TXT   "v=spf1 ip4:<votre-IP> ~all"
```

### 5. Déployer

```bash
cd kubernetes/anonaddy
./deploy.sh
```

### 6. Accéder à l'interface

Ouvrir `https://anonaddy.votredomaine.com` et créer un compte.

## Installation SMS Gateway

### 1. Obtenir les clés API

- **SMS-Activate:** https://sms-activate.org → Compte → API Key
- **5SIM:** https://5sim.net → Profile → API Key

### 2. Configurer les secrets

Éditer `kubernetes/sms-gateway/secrets.yaml` :

```yaml
SMS_ACTIVATE_API_KEY: "votre_cle_sms_activate"
FIVE_SIM_API_KEY: "votre_cle_5sim"
DEFAULT_PROVIDER: "sms-activate"
```

### 3. Configurer l'ingress

Éditer `kubernetes/sms-gateway/ingress.yaml` :
- Remplacer `sms.yourdomain.com` par votre domaine

### 4. Configurer le DNS

```
sms.votredomaine.com.    A    <votre-IP-publique>
```

### 5. Déployer

```bash
cd kubernetes/sms-gateway
./build-and-deploy.sh
```

### 6. Tester l'API

```bash
# Vérifier que le service fonctionne
curl https://sms.votredomaine.com/

# Vérifier le solde
curl https://sms.votredomaine.com/balance
```

## Utilisation

### AnonAddy - Créer un alias

1. Connectez-vous à `https://anonaddy.votredomaine.com`
2. Cliquez sur "Create Alias"
3. Utilisez l'alias pour vous inscrire sur des sites
4. Les emails seront transférés à votre adresse principale

### SMS Gateway - Recevoir un SMS

```bash
# 1. Obtenir un numéro pour Google (service code: 'go')
curl -X POST "https://sms.votredomaine.com/number" \
  -H "Content-Type: application/json" \
  -d '{"service": "go", "country": "0"}'

# Réponse:
# {"id": "123456", "number": "+79123456789", ...}

# 2. Attendre quelques secondes puis récupérer le SMS
curl "https://sms.votredomaine.com/sms/123456"

# Réponse (quand reçu):
# {"id": "123456", "code": "123456", "status": "completed"}
```

### Services disponibles (codes)

- `go` - Google/Gmail
- `wa` - WhatsApp
- `tg` - Telegram
- `fb` - Facebook
- `ig` - Instagram
- `tw` - Twitter
- `vk` - VKontakte
- Voir la liste complète : https://sms-activate.org/en/api2

## Script Python pour automatiser

```python
import requests
import time

SMS_API = "https://sms.votredomaine.com"

def get_verification_code(service="go", country="0"):
    """Obtenir un code de vérification SMS"""

    # 1. Demander un numéro
    response = requests.post(
        f"{SMS_API}/number",
        json={"service": service, "country": country}
    )
    activation = response.json()
    phone = activation['number']
    activation_id = activation['id']

    print(f"📱 Numéro: {phone}")
    print(f"🔑 ID: {activation_id}")

    # 2. Attendre le SMS (max 5 minutes)
    for i in range(60):
        time.sleep(5)

        response = requests.get(f"{SMS_API}/sms/{activation_id}")
        sms = response.json()

        if sms['status'] == 'completed':
            print(f"✅ Code reçu: {sms['code']}")
            return phone, sms['code']
        elif sms['status'] != 'waiting':
            print(f"❌ Erreur: {sms['status']}")
            return phone, None

        print(f"⏳ Attente... ({i*5}s)")

    print("⏰ Timeout")
    return phone, None

# Utilisation
phone, code = get_verification_code(service="go")
if code:
    print(f"Utilisez le numéro {phone} et le code {code}")
```

## Dépannage

### AnonAddy : Les emails ne sont pas reçus

```bash
# Vérifier les logs
kubectl logs -n anonaddy -l app=anonaddy -f
kubectl logs -n anonaddy -l app=postfix -f

# Vérifier l'IP du LoadBalancer
kubectl get svc postfix -n anonaddy

# Tester la connexion SMTP
telnet <IP-postfix> 25
```

### SMS Gateway : Erreur API

```bash
# Vérifier les logs
kubectl logs -n sms-gateway -l app=sms-gateway -f

# Tester localement
kubectl port-forward -n sms-gateway svc/sms-gateway 8080:8080
curl http://localhost:8080/balance
```

### Vérifier l'état général

```bash
# AnonAddy
kubectl get all -n anonaddy

# SMS Gateway
kubectl get all -n sms-gateway
```

## Documentation complète

- **Architecture:** [SERVICES.md](SERVICES.md)
- **AnonAddy:** [kubernetes/anonaddy/README.md](kubernetes/anonaddy/README.md)
- **SMS Gateway:** [kubernetes/sms-gateway/README.md](kubernetes/sms-gateway/README.md)

## Support

- **Issues AnonAddy:** https://github.com/anonaddy/anonaddy/issues
- **API SMS-Activate:** https://sms-activate.org/en/api2
- **API 5SIM:** https://5sim.net/docs
