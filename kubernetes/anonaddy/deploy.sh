#!/bin/bash
set -e

echo "=========================================="
echo "AnonAddy Deployment Script"
echo "=========================================="
echo ""

# Check if domain is configured
if grep -q "yourdomain.com" secrets.yaml; then
    echo "⚠️  WARNING: You need to configure your domain in secrets.yaml and ingress.yaml"
    echo ""
    echo "Steps:"
    echo "1. Generate APP_KEY with:"
    echo "   docker run --rm anonaddy/anonaddy:latest php artisan key:generate --show"
    echo ""
    echo "2. Edit secrets.yaml and update:"
    echo "   - APP_KEY"
    echo "   - APP_URL"
    echo "   - MAIL_DOMAIN"
    echo "   - MAIL_HOSTNAME"
    echo "   - MAIL_FROM_ADDRESS"
    echo "   - DB_ROOT_PASSWORD"
    echo "   - DB_PASSWORD"
    echo ""
    echo "3. Edit ingress.yaml and update the domain"
    echo ""
    read -p "Have you configured these files? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Deploying AnonAddy..."
echo ""

# Create namespace
echo "→ Creating namespace..."
kubectl apply -f namespace.yaml

# Create secrets
echo "→ Creating secrets..."
kubectl apply -f secrets.yaml

# Deploy MariaDB
echo "→ Deploying MariaDB..."
kubectl apply -f mariadb-pvc.yaml
kubectl apply -f mariadb-deployment.yaml

# Wait for MariaDB
echo "→ Waiting for MariaDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mariadb -n anonaddy --timeout=300s

# Deploy Redis
echo "→ Deploying Redis..."
kubectl apply -f redis-deployment.yaml

# Deploy Postfix
echo "→ Deploying Postfix..."
kubectl apply -f postfix-deployment.yaml

# Deploy AnonAddy
echo "→ Deploying AnonAddy application..."
kubectl apply -f anonaddy-pvc.yaml
kubectl apply -f anonaddy-deployment.yaml

# Wait for AnonAddy
echo "→ Waiting for AnonAddy to be ready..."
kubectl wait --for=condition=ready pod -l app=anonaddy -n anonaddy --timeout=300s

# Deploy Ingress
echo "→ Deploying Ingress..."
kubectl apply -f ingress.yaml

echo ""
echo "=========================================="
echo "✓ Deployment complete!"
echo "=========================================="
echo ""

# Show service info
echo "Services:"
kubectl get svc -n anonaddy

echo ""
echo "Pods:"
kubectl get pods -n anonaddy

echo ""
echo "Postfix LoadBalancer IP:"
POSTFIX_IP=$(kubectl get svc postfix -n anonaddy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -n "$POSTFIX_IP" ]; then
    echo "  $POSTFIX_IP"
    echo ""
    echo "⚠️  Make sure your DNS MX record points to this IP!"
else
    echo "  Waiting for LoadBalancer IP..."
fi

echo ""
echo "Next steps:"
echo "1. Configure DNS records (see README.md)"
echo "2. Access https://anonaddy.yourdomain.com"
echo "3. Create your account"
echo "4. Configure DKIM for better deliverability"
echo ""
