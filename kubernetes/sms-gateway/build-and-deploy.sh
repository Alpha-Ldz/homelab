#!/bin/bash
set -e

echo "=========================================="
echo "SMS Gateway Deployment Script"
echo "=========================================="
echo ""

# Check if API keys are configured
if grep -q "CHANGEME" secrets.yaml; then
    echo "⚠️  WARNING: You need to configure your API keys in secrets.yaml"
    echo ""
    echo "Steps:"
    echo "1. Get API keys from:"
    echo "   - SMS-Activate: https://sms-activate.org"
    echo "   - 5SIM: https://5sim.net"
    echo ""
    echo "2. Edit secrets.yaml and update:"
    echo "   - SMS_ACTIVATE_API_KEY"
    echo "   - FIVE_SIM_API_KEY"
    echo "   - DEFAULT_PROVIDER"
    echo ""
    echo "3. Edit ingress.yaml and update the domain"
    echo ""
    read -p "Have you configured secrets.yaml? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Build Docker image
echo "→ Building Docker image..."
docker build -t sms-gateway:latest .

# If using a registry, tag and push
read -p "Do you want to push to a registry? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter registry URL (e.g., registry.yourdomain.com): " REGISTRY
    docker tag sms-gateway:latest $REGISTRY/sms-gateway:latest
    docker push $REGISTRY/sms-gateway:latest
    echo "→ Updating deployment.yaml with registry URL..."
    sed -i.bak "s|image: sms-gateway:latest|image: $REGISTRY/sms-gateway:latest|" deployment.yaml
fi

echo ""
echo "Deploying SMS Gateway..."
echo ""

# Create namespace
echo "→ Creating namespace..."
kubectl apply -f namespace.yaml

# Create secrets and configmap
echo "→ Creating secrets and configmap..."
kubectl apply -f secrets.yaml
kubectl apply -f configmap.yaml

# Deploy application
echo "→ Deploying SMS Gateway..."
kubectl apply -f deployment.yaml

# Wait for deployment
echo "→ Waiting for SMS Gateway to be ready..."
kubectl wait --for=condition=ready pod -l app=sms-gateway -n sms-gateway --timeout=180s

# Deploy Ingress
echo "→ Deploying Ingress..."
kubectl apply -f ingress.yaml

echo ""
echo "=========================================="
echo "✓ Deployment complete!"
echo "=========================================="
echo ""

# Show service info
echo "Pods:"
kubectl get pods -n sms-gateway

echo ""
echo "Service:"
kubectl get svc -n sms-gateway

echo ""
echo "Ingress:"
kubectl get ingress -n sms-gateway

echo ""
echo "Next steps:"
echo "1. Access https://sms.yourdomain.com/docs for API documentation"
echo "2. Test the API with:"
echo "   curl https://sms.yourdomain.com/"
echo "3. Check balance:"
echo "   curl https://sms.yourdomain.com/balance"
echo ""
echo "Example usage:"
echo "  # Get a number for Google"
echo "  curl -X POST https://sms.yourdomain.com/number \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"service\": \"go\", \"country\": \"0\"}'"
echo ""
