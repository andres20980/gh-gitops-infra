#!/bin/bash

# 🚀 Enterprise Port-Forward Management Script
# Intelligent port-forward setup and management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MINIKUBE_PROFILE="gitops-dev"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} 🔍 $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1"
}

log_enterprise() {
    echo -e "${CYAN}[ENTERPRISE]${NC} 🏢 $1"
}

# Check if cluster is running
check_cluster() {
    if ! minikube status --profile="$MINIKUBE_PROFILE" 2>/dev/null | grep -q "Running"; then
        log_error "Minikube cluster '$MINIKUBE_PROFILE' is not running"
        echo "Start it with: minikube start --profile=$MINIKUBE_PROFILE"
        exit 1
    fi
    
    # Set correct context
    kubectl config use-context "$MINIKUBE_PROFILE" >/dev/null 2>&1
    log_success "Cluster is running and context is set"
}

# Kill existing port-forwards
cleanup_port_forwards() {
    log_info "Cleaning up existing port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    log_success "Cleanup completed"
}

# Setup port-forward with health check
setup_port_forward() {
    local namespace=$1
    local service=$2
    local port=$3
    local target_port=$4
    local display_name=$5
    local protocol=${6:-http}
    
    log_info "Setting up $display_name..."
    
    if kubectl get svc "$service" -n "$namespace" 2>/dev/null >/dev/null; then
        nohup kubectl port-forward -n "$namespace" svc/"$service" "$port":"$target_port" >/dev/null 2>&1 &
        local pid=$!
        
        # Quick health check
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            log_success "$display_name accessible at $protocol://localhost:$port"
            return 0
        else
            log_warning "$display_name port-forward failed to start"
            return 1
        fi
    else
        log_warning "$display_name service not found in namespace $namespace"
        return 1
    fi
}

# Main port-forward setup
setup_all_port_forwards() {
    log_enterprise "Setting up enterprise service access..."
    
    echo ""
    echo "🏢 ENTERPRISE SERVICE ACCESS SETUP"
    echo "=================================="
    
    # Core GitOps Services (puertos correlativos desde 8080)
    setup_port_forward "argocd" "argocd-server" "8080" "80" "ArgoCD GitOps Controller" "http"
    setup_port_forward "grafana" "grafana" "8081" "80" "Grafana Dashboards" "http"
    setup_port_forward "kargo" "kargo-api" "8082" "443" "Kargo Promotional Pipelines" "https"
    
    # Infrastructure Services (puertos correlativos continuos)
    setup_port_forward "gitea" "gitea-http" "8083" "3000" "Gitea Git Repository" "http"
    setup_port_forward "monitoring" "prometheus-server" "8084" "80" "Prometheus Metrics" "http"
    setup_port_forward "argo-workflows" "argo-workflows-server" "8085" "2746" "Argo Workflows" "http"
    setup_port_forward "jaeger" "jaeger-query" "8086" "16686" "Jaeger Tracing" "http"
    setup_port_forward "minio" "minio-console" "8087" "9001" "MinIO Console" "http"
    setup_port_forward "minio" "minio" "8088" "9000" "MinIO API" "http"
    
    # Demo Applications (puertos finales correlativos)
    setup_port_forward "demo-project" "frontend" "8089" "80" "Demo Frontend App" "http"
    setup_port_forward "demo-project" "backend" "8090" "3000" "Demo Backend API" "http"
    
    # Observability integration (sin puerto dedicado)
    setup_port_forward "loki" "loki-gateway" "9080" "80" "Loki Logs" "http"
    
    echo ""
    log_enterprise "All available services configured for access"
}

# Print access information
print_access_info() {
    echo ""
    echo "🏢=============================================="
    echo "   📊 ENTERPRISE SERVICE ACCESS URLS"
    echo "=============================================="
    echo ""
    echo "🎯 CONTROL PLANE:"
    echo "   ArgoCD:          http://localhost:8080"
    echo "   Kargo:           http://localhost:8082"
    echo ""
    echo "📊 OBSERVABILITY:"
    echo "   Grafana:         http://localhost:8081"
    echo "   Prometheus:      http://localhost:8084"
    echo "   Jaeger:          http://localhost:8086"
    echo "   Loki:            http://localhost:9080"
    echo ""
    echo "🗄️  INFRASTRUCTURE:"
    echo "   Gitea:           http://localhost:8083"
    echo "   MinIO Console:   http://localhost:8087"
    echo "   MinIO API:       http://localhost:8088"
    echo "   Argo Workflows:  http://localhost:8085"
    echo ""
    echo "📱 DEMO APPLICATIONS:"
    echo "   Frontend:        http://localhost:8089"
    echo "   Backend API:     http://localhost:8090"
    echo ""
    echo "🔑 DEFAULT CREDENTIALS:"
    echo "   ArgoCD:          admin / (get with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d)"
    echo "   Kargo:           admin / admin123"
    echo "   Grafana:         admin / admin"
    echo "   Gitea:           admin / admin123"
    echo "   MinIO:           admin / admin123"
    echo "   Workflows/Jaeger: Sin autenticación"
    echo ""
    echo "🛠️  MANAGEMENT:"
    echo "   Minikube Dashboard: minikube dashboard --profile=$MINIKUBE_PROFILE"
    echo "   Kill Port-forwards: $0 cleanup"
    echo "   Restart Services:   $0"
    echo ""
    echo "=============================================="
}

# Show current port-forwards
show_status() {
    echo ""
    echo "🔍 CURRENT PORT-FORWARD STATUS"
    echo "=============================="
    
    local pf_processes=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
    
    if [ "$pf_processes" -gt 0 ]; then
        log_success "$pf_processes port-forward processes running"
        echo ""
        ps aux | grep "kubectl port-forward" | grep -v grep | while read line; do
            echo "  $line"
        done
    else
        log_warning "No port-forward processes found"
    fi
    echo ""
}

# Main execution
main() {
    case "${1:-setup}" in
        "cleanup")
            cleanup_port_forwards
            log_success "Port-forwards cleaned up"
            ;;
        "status")
            show_status
            ;;
        "setup"|"")
            check_cluster
            cleanup_port_forwards
            setup_all_port_forwards
            print_access_info
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [setup|cleanup|status|help]"
            echo ""
            echo "Commands:"
            echo "  setup    - Setup all port-forwards (default)"
            echo "  cleanup  - Kill all existing port-forwards"
            echo "  status   - Show current port-forward status"
            echo "  help     - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C
trap 'log_warning "Port-forward setup interrupted"; exit 1' INT

main "$@"
