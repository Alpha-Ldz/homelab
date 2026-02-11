# SMS Gateway API

Service API pour recevoir des SMS via différents providers (SMS-Activate, 5SIM, etc.)

## Configuration

1. **Obtenez vos clés API** :
   - SMS-Activate : https://sms-activate.org
   - 5SIM : https://5sim.net

2. **Modifiez les secrets** :
   ```bash
   kubectl edit secret sms-gateway-secrets -n sms-gateway
   ```

3. **Construisez l'image Docker** :
   ```bash
   cd kubernetes/sms-gateway
   docker build -t sms-gateway:latest .
   ```

4. **Déployez** :
   ```bash
   kubectl apply -f kubernetes/sms-gateway/
   ```

## Utilisation de l'API

### Obtenir un numéro

```bash
curl -X POST "https://sms.yourdomain.com/number" \
  -H "Content-Type: application/json" \
  -d '{
    "service": "go",
    "country": "0",
    "provider": "sms-activate"
  }'
```

Réponse :
```json
{
  "id": "123456",
  "number": "+79123456789",
  "provider": "sms-activate",
  "service": "go",
  "cost": 0.15
}
```

### Récupérer le SMS

```bash
curl "https://sms.yourdomain.com/sms/123456?provider=sms-activate"
```

Réponse (en attente) :
```json
{
  "id": "123456",
  "code": null,
  "full_text": null,
  "status": "waiting"
}
```

Réponse (reçu) :
```json
{
  "id": "123456",
  "code": "123456",
  "full_text": "Your code is: 123456",
  "status": "completed"
}
```

### Vérifier le solde

```bash
curl "https://sms.yourdomain.com/balance"
```

Réponse :
```json
[
  {
    "provider": "sms-activate",
    "balance": 10.50
  },
  {
    "provider": "5sim",
    "balance": 5.25
  }
]
```

### Annuler une activation

```bash
curl -X POST "https://sms.yourdomain.com/cancel/123456?provider=sms-activate"
```

## Codes de service courants

- `vk` - VKontakte
- `ok` - Odnoklassniki
- `wa` - WhatsApp
- `vi` - Viber
- `tg` - Telegram
- `go` - Google/Gmail
- `fb` - Facebook
- `tw` - Twitter
- `ig` - Instagram
- `ot` - Autres (voir docs API)

## Exemple d'utilisation en Python

```python
import requests
import time

API_URL = "https://sms.yourdomain.com"

# 1. Obtenir un numéro pour Google
response = requests.post(f"{API_URL}/number", json={
    "service": "go",
    "country": "0"
})
activation = response.json()
print(f"Numéro: {activation['number']}")
print(f"ID: {activation['id']}")

# 2. Attendre le SMS (polling)
while True:
    response = requests.get(f"{API_URL}/sms/{activation['id']}")
    sms = response.json()

    if sms['status'] == 'completed':
        print(f"Code reçu: {sms['code']}")
        break
    elif sms['status'] == 'waiting':
        print("En attente du SMS...")
        time.sleep(5)
    else:
        print(f"Erreur: {sms['status']}")
        break
```

## Documentation interactive

Une fois déployé, accédez à :
- Swagger UI : https://sms.yourdomain.com/docs
- ReDoc : https://sms.yourdomain.com/redoc
