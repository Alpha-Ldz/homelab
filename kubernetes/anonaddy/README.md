# AnonAddy - Gestionnaire d'alias email

Service open-source pour créer des alias email anonymes et protéger votre adresse email principale.

## Prérequis

1. **Nom de domaine** : Vous devez posséder un domaine (ex: `yourdomain.com`)
2. **Configuration DNS** : Ajouter les enregistrements suivants :

### Enregistrements DNS requis

```
# A record pour le web
anonaddy.yourdomain.com.    A    <votre-IP-publique>

# MX record pour recevoir les emails
anonaddy.yourdomain.com.    MX   10 mail.yourdomain.com.
mail.yourdomain.com.        A    <votre-IP-publique>

# SPF record
anonaddy.yourdomain.com.    TXT  "v=spf1 ip4:<votre-IP-publique> ~all"

# DMARC record
_dmarc.anonaddy.yourdomain.com. TXT "v=DMARC1; p=quarantine; rua=mailto:postmaster@yourdomain.com"
```

## Installation

### 1. Générer la clé APP_KEY

```bash
docker run --rm anonaddy/anonaddy:latest php artisan key:generate --show
```

Copiez la sortie (format: `base64:...`)

### 2. Modifier les secrets

Éditez `kubernetes/anonaddy/secrets.yaml` et modifiez :
- `APP_KEY` : La clé générée à l'étape 1
- `APP_URL` : `https://anonaddy.yourdomain.com`
- `MAIL_DOMAIN` : `anonaddy.yourdomain.com`
- `MAIL_HOSTNAME` : `mail.yourdomain.com`
- `MAIL_FROM_ADDRESS` : `noreply@anonaddy.yourdomain.com`
- `DB_ROOT_PASSWORD` : Mot de passe root MariaDB
- `DB_PASSWORD` : Mot de passe utilisateur anonaddy

### 3. Modifier l'ingress

Éditez `kubernetes/anonaddy/ingress.yaml` et remplacez `anonaddy.yourdomain.com` par votre domaine.

### 4. Déployer

```bash
kubectl apply -f kubernetes/anonaddy/
```

### 5. Vérifier le déploiement

```bash
# Vérifier les pods
kubectl get pods -n anonaddy

# Vérifier les logs
kubectl logs -n anonaddy deployment/anonaddy -f

# Vérifier les services
kubectl get svc -n anonaddy
```

### 6. Configurer le service SMTP (LoadBalancer)

Le service Postfix est exposé via un LoadBalancer sur les ports 25 et 587.

Si vous utilisez MetalLB, vérifiez l'IP assignée :
```bash
kubectl get svc postfix -n anonaddy
```

Notez l'EXTERNAL-IP et assurez-vous que vos enregistrements DNS pointent vers cette IP.

### 7. Premier accès

Accédez à `https://anonaddy.yourdomain.com` et créez votre compte.

## Configuration DNS avancée (DKIM)

Pour améliorer la délivrabilité, configurez DKIM :

1. Générez les clés DKIM dans AnonAddy (interface web > Settings > DKIM)
2. Ajoutez l'enregistrement TXT fourni dans votre DNS :

```
default._domainkey.anonaddy.yourdomain.com. TXT "v=DKIM1; k=rsa; p=<votre-clé-publique>"
```

## Utilisation

### Créer un alias

Dans l'interface web AnonAddy, cliquez sur "Create Alias" et choisissez :
- **Standard alias** : `random-string@anonaddy.yourdomain.com`
- **Custom alias** : `custom-name@anonaddy.yourdomain.com`
- **Shared domain** : Utilise un sous-domaine partagé

### Utiliser un alias

Donnez l'alias à n'importe quel site web. Les emails envoyés à cet alias seront transférés à votre email principal.

### Répondre via un alias

Répondez simplement à l'email reçu. AnonAddy enverra la réponse via l'alias.

### Désactiver un alias

Si vous recevez du spam, désactivez l'alias dans l'interface web. Vous pouvez le réactiver à tout moment.

## Dépannage

### Les emails ne sont pas reçus

1. Vérifiez les logs Postfix :
   ```bash
   kubectl logs -n anonaddy deployment/postfix -f
   ```

2. Vérifiez les logs AnonAddy :
   ```bash
   kubectl logs -n anonaddy deployment/anonaddy -f
   ```

3. Testez la connexion SMTP :
   ```bash
   telnet <postfix-external-ip> 25
   ```

### Les emails sont marqués comme spam

Assurez-vous que :
- Les enregistrements SPF, DKIM et DMARC sont correctement configurés
- Votre IP n'est pas sur une blacklist
- Le reverse DNS de votre IP pointe vers votre domaine

### Base de données corrompue

Restaurez depuis un backup ou réinitialisez :
```bash
kubectl delete pvc mariadb-data -n anonaddy
kubectl delete pod -l app=mariadb -n anonaddy
```

## Backup

### Sauvegarder la base de données

```bash
kubectl exec -n anonaddy deployment/mariadb -- \
  mysqldump -uanonaddy -p<password> anonaddy > anonaddy-backup.sql
```

### Restaurer la base de données

```bash
kubectl exec -i -n anonaddy deployment/mariadb -- \
  mysql -uanonaddy -p<password> anonaddy < anonaddy-backup.sql
```

## Mise à jour

```bash
kubectl set image deployment/anonaddy anonaddy=anonaddy/anonaddy:latest -n anonaddy
kubectl set image deployment/anonaddy-worker worker=anonaddy/anonaddy:latest -n anonaddy
```

## Ressources

- Documentation officielle : https://anonaddy.com/help
- GitHub : https://github.com/anonaddy/anonaddy
- Forum : https://forum.anonaddy.com
