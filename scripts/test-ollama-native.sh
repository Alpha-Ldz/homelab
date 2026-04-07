#!/usr/bin/env bash
#
# Test Ollama Native - Script de test pour Ollama natif sur sleeper
#

set -euo pipefail

OLLAMA_NATIVE="http://192.168.1.158:11434"
OLLAMA_K8S="http://ollama.ollama.svc.cluster.local:11434"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Test 1: Version check
test_version() {
    log_info "Testing Ollama version..."

    log_info "Direct access to sleeper (192.168.1.158:11434):"
    if curl -s "${OLLAMA_NATIVE}/api/version" | jq .; then
        log_info "✓ Direct access OK"
    else
        log_error "✗ Direct access failed"
        return 1
    fi

    echo ""
    log_info "Access via K8s service (ollama.ollama.svc.cluster.local:11434):"
    if kubectl run -it --rm test-ollama --image=curlimages/curl --restart=Never -- \
        sh -c "curl -s ${OLLAMA_K8S}/api/version | cat"; then
        log_info "✓ K8s service access OK"
    else
        log_error "✗ K8s service access failed"
        return 1
    fi
}

# Test 2: List models
test_list_models() {
    log_info "Listing models on native Ollama..."

    if ! curl -s "${OLLAMA_NATIVE}/api/tags" | jq -r '.models[] | "\(.name) - \(.size / 1024 / 1024 / 1024 | round)GB"'; then
        log_warn "No models found or error listing models"
        log_info "You can pull a model with: curl -X POST ${OLLAMA_NATIVE}/api/pull -d '{\"name\": \"qwen2.5:27b\"}'"
    fi
}

# Test 3: Simple generation test (requires a model)
test_generation() {
    local model="${1:-qwen2.5:14b-instruct-q8_0}"

    log_info "Testing generation with model: $model"
    log_warn "This requires the model to be downloaded first"

    local prompt="Say hello in French in one sentence."

    log_info "Sending prompt: $prompt"
    if ! curl -s -X POST "${OLLAMA_NATIVE}/api/generate" \
        -d "{\"model\": \"$model\", \"prompt\": \"$prompt\", \"stream\": false}" \
        | jq -r '.response'; then
        log_error "Generation test failed - is the model downloaded?"
        return 1
    fi
}

# Test 4: Check GPU status from logs
test_gpu_status() {
    log_info "Checking GPU detection from Ollama logs..."

    journalctl -u ollama.service -n 100 --no-pager | grep -E "GPU|vram|cuda" | tail -10 || {
        log_warn "No GPU logs found"
    }

    echo ""
    log_info "Current GPU status:"
    if nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader
    else
        log_error "nvidia-smi not available or GPU not detected"
    fi
}

# Test 5: Pull a model
test_pull_model() {
    local model="${1:-}"

    if [[ -z "$model" ]]; then
        log_error "Usage: $0 pull <model_name>"
        echo "Example: $0 pull qwen2.5:27b"
        return 1
    fi

    log_info "Pulling model: $model"
    log_warn "This may take several minutes depending on model size..."

    curl -X POST "${OLLAMA_NATIVE}/api/pull" -d "{\"name\": \"$model\"}"
}

# Main test suite
run_all_tests() {
    log_info "Running Ollama Native Test Suite"
    echo "======================================"
    echo ""

    test_version
    echo ""
    echo "======================================"
    echo ""

    test_list_models
    echo ""
    echo "======================================"
    echo ""

    test_gpu_status
    echo ""
    echo "======================================"
    echo ""

    log_info "Test suite completed"
    echo ""
    log_info "To test generation, first pull a model:"
    log_info "  $0 pull qwen2.5:14b-instruct-q8_0"
    log_info "Then run:"
    log_info "  $0 generate qwen2.5:14b-instruct-q8_0"
}

# Command dispatcher
case "${1:-all}" in
    version)
        test_version
        ;;
    list)
        test_list_models
        ;;
    generate)
        test_generation "${2:-qwen2.5:14b-instruct-q8_0}"
        ;;
    gpu)
        test_gpu_status
        ;;
    pull)
        test_pull_model "${2:-}"
        ;;
    all)
        run_all_tests
        ;;
    help|*)
        cat <<EOF
Ollama Native Test Script

Usage: $0 <command> [options]

Commands:
    version             Test version endpoint (direct + K8s service)
    list                List installed models
    generate [model]    Test generation (default: qwen2.5:14b-instruct-q8_0)
    gpu                 Check GPU detection status
    pull <model>        Pull/download a model
    all                 Run all tests (default)
    help                Show this help

Examples:
    $0 all                                      # Run full test suite
    $0 version                                  # Test connectivity
    $0 pull qwen2.5:27b                        # Download model
    $0 generate qwen2.5:27b                    # Test generation

Notes:
    - Ollama native runs on sleeper at http://192.168.1.158:11434
    - Accessible from K8s at http://ollama.ollama.svc.cluster.local:11434
    - RTX 5090 may not be detected (Blackwell compatibility issue)
    - Check README-NATIVE.md for troubleshooting
EOF
        ;;
esac
