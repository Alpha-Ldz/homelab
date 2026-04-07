# Credentials et Tokens

**⚠️ ATTENTION: Ne jamais commiter ce fichier dans Git!**

## OpenClaw

### Gateway Access
- **URL**: https://openclaw.freedom35.fr
- **Token**: `REDACTED_OPENCLAW_TOKEN`

### Secrets Kubernetes
```bash
# Notion API Key
kubectl get secret notion-api-key -n openclaw -o jsonpath='{.data.key}' | base64 -d

# Telegram Bot Token
kubectl get secret telegram-bot-token -n openclaw -o jsonpath='{.data.token}' | base64 -d
```

## Ollama

### API Access
- **URL interne**: http://ollama.ollama.svc.cluster.local:11434
- **Port-forward local**: `kubectl port-forward -n ollama svc/ollama 11434:11434`
- **API Key**: `ollama-local` (utilisé par OpenClaw)

## Configuration Optimale Testée

### Ollama
```yaml
Model: qwen2.5:14b (9GB)
OLLAMA_NUM_GPU: 12
GPU: RTX 4080 SUPER (16GB VRAM)
Performance:
  - Prompts simples: ~10-15 secondes
  - Prompts complexes: ~20-30 secondes
  - Tool calling (OpenClaw): ~30-40 secondes
```

### Limites Identifiées
- ❌ qwen3.5:35b (23GB) - Trop lourd, crashe systématiquement
- ❌ qwen3.5:27b (17GB) - Crash systématique avec OpenClaw (NUM_GPU=4/8/15 testés, tous crash)
- ⚠️ qwen2.5:7b (4.7GB) - Trop faible pour tool calling complexe (Notion)
- ✅ qwen2.5:14b (9GB) + OLLAMA_NUM_GPU=12 - Bon équilibre performance/stabilité pour OpenClaw

## URLs Utiles

### Services Internes
- Ollama API: http://ollama.ollama.svc.cluster.local:11434
- OpenClaw Gateway: http://openclaw.openclaw.svc.cluster.local:18789
- OpenClaw Chrome VNC: http://openclaw-chrome-vnc.openclaw.svc.cluster.local:9222

### Services Externes
- OpenClaw Gateway: https://openclaw.freedom35.fr
- Open WebUI: (vérifier ingress Traefik)

## Récupération des Secrets

### OpenClaw
```bash
# Gateway Token depuis configmap
kubectl get configmap openclaw -n openclaw -o yaml | grep '"token":'

# Notion API Key
kubectl get secret notion-api-key -n openclaw -o jsonpath='{.data.key}' | base64 -d

# Telegram Bot Token
kubectl get secret telegram-bot-token -n openclaw -o jsonpath='{.data.token}' | base64 -d
```

### Vérifier tous les secrets
```bash
kubectl get secrets -n openclaw
kubectl get secrets -n ollama
```
