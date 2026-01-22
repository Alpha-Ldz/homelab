# STF API - Exemples d'utilisation

Documentation des endpoints API REST de STF avec exemples curl.

## Configuration

```bash
# Variables d'environnement
export STF_URL="http://stf.local"
export STF_TOKEN="your-api-token-here"  # Obtenir via l'interface web
```

## Authentification

### Obtenir un token d'accès

1. Aller sur l'interface web : http://stf.local
2. Cliquer sur votre profil en haut à droite
3. Aller dans "Settings" > "Keys"
4. Créer un nouveau token d'accès

## Endpoints API

### 1. Lister tous les devices

```bash
curl -X GET \
  "${STF_URL}/api/v1/devices" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

**Réponse** :
```json
{
  "success": true,
  "devices": [
    {
      "serial": "ABCD1234",
      "present": true,
      "ready": true,
      "using": false,
      "owner": null,
      "manufacturer": "Google",
      "model": "Pixel 6",
      "version": "13",
      "abi": "arm64-v8a",
      "sdk": "33",
      "display": {
        "width": 1080,
        "height": 2400
      }
    }
  ]
}
```

### 2. Obtenir les détails d'un device

```bash
curl -X GET \
  "${STF_URL}/api/v1/devices/ABCD1234" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

### 3. Réserver un device

```bash
curl -X POST \
  "${STF_URL}/api/v1/user/devices" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "serial": "ABCD1234",
    "timeout": 900000
  }'
```

**Paramètres** :
- `serial` : Numéro de série du device
- `timeout` : Durée de réservation en millisecondes (900000 = 15 minutes)

### 4. Lister les devices de l'utilisateur

```bash
curl -X GET \
  "${STF_URL}/api/v1/user/devices" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

### 5. Libérer un device

```bash
curl -X DELETE \
  "${STF_URL}/api/v1/user/devices/ABCD1234" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

### 6. Obtenir le port ADB distant

```bash
curl -X POST \
  "${STF_URL}/api/v1/user/devices/ABCD1234/remoteConnect" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

**Réponse** :
```json
{
  "success": true,
  "remoteConnectUrl": "192.168.1.100:7401"
}
```

**Utilisation** :
```bash
# Connecter ADB au device distant
adb connect 192.168.1.100:7401

# Vérifier la connexion
adb devices

# Utiliser ADB normalement
adb shell getprop ro.product.model
```

### 7. Se déconnecter d'ADB distant

```bash
curl -X DELETE \
  "${STF_URL}/api/v1/user/devices/ABCD1234/remoteConnect" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

### 8. Obtenir la liste des utilisateurs (admin)

```bash
curl -X GET \
  "${STF_URL}/api/v1/users" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

### 9. Obtenir les informations de l'utilisateur

```bash
curl -X GET \
  "${STF_URL}/api/v1/user" \
  -H "Authorization: Bearer ${STF_TOKEN}"
```

## Cas d'usage avancés

### Automatiser la réservation et l'exécution de tests

```bash
#!/bin/bash

STF_URL="http://stf.local"
STF_TOKEN="your-token"
DEVICE_SERIAL="ABCD1234"

# 1. Réserver le device
echo "Réservation du device ${DEVICE_SERIAL}..."
curl -X POST \
  "${STF_URL}/api/v1/user/devices" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"serial\": \"${DEVICE_SERIAL}\", \"timeout\": 900000}" \
  -s > /dev/null

# 2. Obtenir le port ADB
echo "Connexion ADB distant..."
REMOTE_URL=$(curl -X POST \
  "${STF_URL}/api/v1/user/devices/${DEVICE_SERIAL}/remoteConnect" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -s | jq -r '.remoteConnectUrl')

# 3. Connecter ADB
adb connect "${REMOTE_URL}"

# 4. Exécuter vos tests
echo "Installation de l'APK..."
adb install -r app.apk

echo "Lancement des tests..."
adb shell am instrument -w com.example.app.test/androidx.test.runner.AndroidJUnitRunner

# 5. Récupérer les résultats
adb pull /sdcard/test-results.xml ./

# 6. Déconnecter ADB
adb disconnect "${REMOTE_URL}"

# 7. Libérer le device
echo "Libération du device..."
curl -X DELETE \
  "${STF_URL}/api/v1/user/devices/${DEVICE_SERIAL}/remoteConnect" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -s > /dev/null

curl -X DELETE \
  "${STF_URL}/api/v1/user/devices/${DEVICE_SERIAL}" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -s > /dev/null

echo "Terminé !"
```

### Trouver et réserver un device disponible automatiquement

```bash
#!/bin/bash

STF_URL="http://stf.local"
STF_TOKEN="your-token"

# Récupérer un device disponible avec Android 13+
DEVICE_SERIAL=$(curl -X GET \
  "${STF_URL}/api/v1/devices" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -s | jq -r '.devices[] | select(.present == true and .ready == true and .using == false and (.sdk | tonumber) >= 33) | .serial' | head -n 1)

if [ -z "$DEVICE_SERIAL" ]; then
  echo "Aucun device disponible"
  exit 1
fi

echo "Device trouvé : ${DEVICE_SERIAL}"

# Réserver le device
curl -X POST \
  "${STF_URL}/api/v1/user/devices" \
  -H "Authorization: Bearer ${STF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"serial\": \"${DEVICE_SERIAL}\", \"timeout\": 900000}"

echo "Device réservé avec succès"
```

### Monitorer l'état des devices

```bash
#!/bin/bash

STF_URL="http://stf.local"
STF_TOKEN="your-token"

while true; do
  clear
  echo "=== État des devices STF ==="
  echo ""

  curl -X GET \
    "${STF_URL}/api/v1/devices" \
    -H "Authorization: Bearer ${STF_TOKEN}" \
    -s | jq -r '.devices[] | "\(.serial)\t\(.manufacturer) \(.model)\t\(.version)\t\(if .using then "UTILISÉ" else "LIBRE" end)"'

  sleep 5
done
```

## Intégration CI/CD

### GitHub Actions

```yaml
name: Android Tests on STF

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Reserve STF Device
        id: stf_reserve
        run: |
          DEVICE=$(curl -X POST \
            "${{ secrets.STF_URL }}/api/v1/user/devices" \
            -H "Authorization: Bearer ${{ secrets.STF_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{"serial": "${{ secrets.STF_DEVICE_SERIAL }}", "timeout": 900000}' \
            -s | jq -r '.serial')

          REMOTE_URL=$(curl -X POST \
            "${{ secrets.STF_URL }}/api/v1/user/devices/${DEVICE}/remoteConnect" \
            -H "Authorization: Bearer ${{ secrets.STF_TOKEN }}" \
            -s | jq -r '.remoteConnectUrl')

          echo "::set-output name=device::${DEVICE}"
          echo "::set-output name=remote_url::${REMOTE_URL}"

      - name: Connect ADB
        run: |
          adb connect ${{ steps.stf_reserve.outputs.remote_url }}
          adb wait-for-device

      - name: Run Tests
        run: |
          ./gradlew connectedAndroidTest

      - name: Release STF Device
        if: always()
        run: |
          curl -X DELETE \
            "${{ secrets.STF_URL }}/api/v1/user/devices/${{ steps.stf_reserve.outputs.device }}" \
            -H "Authorization: Bearer ${{ secrets.STF_TOKEN }}"
```

### GitLab CI

```yaml
android_tests:
  stage: test
  image: openjdk:11
  before_script:
    - apt-get update && apt-get install -y android-tools-adb jq curl
  script:
    # Réserver device
    - |
      DEVICE=$(curl -X POST \
        "${STF_URL}/api/v1/user/devices" \
        -H "Authorization: Bearer ${STF_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"serial\": \"${STF_DEVICE_SERIAL}\", \"timeout\": 900000}" \
        -s | jq -r '.serial')

    - |
      REMOTE_URL=$(curl -X POST \
        "${STF_URL}/api/v1/user/devices/${DEVICE}/remoteConnect" \
        -H "Authorization: Bearer ${STF_TOKEN}" \
        -s | jq -r '.remoteConnectUrl')

    # Connecter ADB
    - adb connect ${REMOTE_URL}
    - adb wait-for-device

    # Tests
    - ./gradlew connectedAndroidTest

  after_script:
    # Libérer device
    - |
      curl -X DELETE \
        "${STF_URL}/api/v1/user/devices/${DEVICE}" \
        -H "Authorization: Bearer ${STF_TOKEN}"
```

## Erreurs courantes

### 401 Unauthorized
```json
{"success": false, "error": "Unauthorized"}
```
**Solution** : Vérifiez votre token d'API.

### 403 Forbidden
```json
{"success": false, "error": "Device already in use"}
```
**Solution** : Le device est déjà utilisé par quelqu'un d'autre.

### 404 Not Found
```json
{"success": false, "error": "Device not found"}
```
**Solution** : Le numéro de série est incorrect ou le device n'est pas connecté.

### 500 Internal Server Error
**Solution** : Vérifiez les logs du serveur STF.

## Ressources

- **Documentation API officielle** : https://github.com/openstf/stf/blob/master/doc/API.md
- **Swagger UI** : http://stf.local/api/v1/docs (si activé)
- **WebSocket API** : Pour le streaming temps réel

## Support

Pour plus d'informations, consultez le README.md principal.
