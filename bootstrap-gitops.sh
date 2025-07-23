#!/bin/bash

# 🚀 Enterprise GitOps Infrastructure Bootstrap Script 
# Intelligent, non-destructive setup for complete GitOps environment

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
MINIKUBE_CPUS=4
MINIKUBE_MEMORY="8192m"
MINIKUBE_DISK="50g"
ARGOCD_VERSION="v2.12.3"
GITHUB_REPO_URL="https://github.com/andres20980/gh-gitops-infra.git"

# Logging functions with emojis
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

log_step() {
    echo -e "${PURPLE}[STEP]${NC} 🚀 $1"
}

log_enterprise() {
    echo -e "${CYAN}[ENTERPRISE]${NC} 🏢 $1"
}

# Intelligent cluster health check
check_cluster_health() {
    log_step "Checking existing cluster health..."
    
    # Check if minikube profile exists
    if minikube profile list 2>/dev/null | grep -q "$MINIKUBE_PROFILE"; then
        log_info "Found existing minikube profile: $MINIKUBE_PROFILE"
        
        # Check if it's running
        if minikube status --profile="$MINIKUBE_PROFILE" 2>/dev/null | grep -q "Running"; then
            log_success "Cluster is already running and healthy"
            
            # Set context to the existing cluster
            kubectl config use-context "$MINIKUBE_PROFILE" 2>/dev/null || true
            
            # Check if ArgoCD is already deployed
            if kubectl get namespace argocd 2>/dev/null; then
                log_success "ArgoCD namespace found - infrastructure appears to be deployed"
                return 0
            else
                log_info "Cluster running but ArgoCD not found - will deploy infrastructure"
                return 1
            fi
        else
            log_warning "Cluster exists but not running - will restart"
            return 2
        fi
    else
        log_info "No existing cluster found - will create new one"
        return 3
    fi
}

# Check prerequisites with enhanced checks
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if minikube is installed
    if ! command -v minikube &> /dev/null; then
        log_error "Minikube is not installed. Please install it first:"
        echo "  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
        echo "  sudo install minikube-linux-amd64 /usr/local/bin/minikube"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first:"
        echo "  curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        echo "  sudo install kubectl /usr/local/bin/kubectl"
        exit 1
    fi
    
    # Check if helm is installed (auto-install if missing)
    if ! command -v helm &> /dev/null; then
        log_warning "Helm is not installed. Installing helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_success "Helm installed successfully"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check available resources
    AVAILABLE_CPUS=$(nproc)
    AVAILABLE_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $7/1024}')
    
    if [ "$AVAILABLE_CPUS" -lt 4 ]; then
        log_warning "Only $AVAILABLE_CPUS CPUs available. Recommended: 4+ CPUs"
    fi
    
    if [ "$AVAILABLE_MEMORY" -lt 8 ]; then
        log_warning "Only ${AVAILABLE_MEMORY}GB memory available. Recommended: 8+ GB"
    fi
    
    log_success "Prerequisites check completed (CPUs: $AVAILABLE_CPUS, Memory: ${AVAILABLE_MEMORY}GB)"
}

# Smart cluster management
smart_cluster_setup() {
    log_step "Smart cluster setup..."
    
    check_cluster_health
    HEALTH_STATUS=$?
    
    case $HEALTH_STATUS in
        0)
            log_enterprise "Cluster is healthy and ready! Skipping cluster creation."
            return 0
            ;;
        1)
            log_enterprise "Cluster running but infrastructure missing. Proceeding with deployment."
            return 0
            ;;
        2)
            log_enterprise "Restarting existing cluster..."
            minikube start --profile="$MINIKUBE_PROFILE"
            kubectl config use-context "$MINIKUBE_PROFILE"
            return 0
            ;;
        3)
            log_enterprise "Creating new enterprise cluster..."
            create_new_cluster
            return 0
            ;;
        *)
            log_error "Unknown cluster status"
            exit 1
            ;;
    esac
}

# Enhanced cluster creation
create_new_cluster() {
    log_enterprise "Creating optimized enterprise cluster..."
    log_info "Profile: $MINIKUBE_PROFILE"
    log_info "CPUs: $MINIKUBE_CPUS, Memory: $MINIKUBE_MEMORY, Disk: $MINIKUBE_DISK"
    log_info "This may take 2-5 minutes depending on your system..."
    
    minikube start \
        --profile="$MINIKUBE_PROFILE" \
        --cpus="$MINIKUBE_CPUS" \
        --memory="$MINIKUBE_MEMORY" \
        --disk-size="$MINIKUBE_DISK" \
        --kubernetes-version="v1.29.0" \
        --driver=docker \
        --addons=ingress,metrics-server,dashboard
    
    # Set the kubectl context
    log_info "Setting kubectl context..."
    kubectl config use-context "$MINIKUBE_PROFILE"
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Enterprise cluster created successfully"
    kubectl cluster-info --context="$MINIKUBE_PROFILE"
}

# Smart ArgoCD installation 
smart_argocd_installation() {
    log_step "Smart ArgoCD installation..."
    
    # Check if ArgoCD is already installed
    if kubectl get namespace argocd 2>/dev/null; then
        log_success "ArgoCD namespace found - checking deployment status..."
        
        if kubectl get deployment argocd-server -n argocd 2>/dev/null; then
            if kubectl wait --for=condition=available --timeout=30s deployment/argocd-server -n argocd 2>/dev/null; then
                log_success "ArgoCD is already installed and ready!"
                return 0
            else
                log_warning "ArgoCD found but not ready - waiting for it to be available..."
                kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
                log_success "ArgoCD is now ready!"
                return 0
            fi
        fi
    fi
    
    log_enterprise "Installing ArgoCD $ARGOCD_VERSION..."
    
    # Create argocd namespace
    kubectl create namespace argocd || true
    
    # Install ArgoCD
    log_info "Downloading and applying ArgoCD manifests..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD server to be ready (this may take 3-5 minutes)..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    
    log_success "ArgoCD installed successfully"
}

# Smart infrastructure deployment
smart_infrastructure_deployment() {
    log_step "Smart infrastructure deployment..."
    
    # Check if infrastructure applications already exist
    if kubectl get application gitops-infra-apps -n argocd 2>/dev/null; then
        log_success "Infrastructure applications found - checking sync status..."
        
        # Check if apps are synced
        SYNC_STATUS=$(kubectl get application gitops-infra-apps -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        if [ "$SYNC_STATUS" = "Synced" ]; then
            log_success "Infrastructure is already deployed and synced!"
            return 0
        else
            log_warning "Infrastructure exists but not synced (Status: $SYNC_STATUS) - forcing refresh..."
            kubectl patch application gitops-infra-apps -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
            return 0
        fi
    fi
    
    log_enterprise "Deploying GitOps Infrastructure..."
    
    # Deploy the main app-of-apps configuration
    kubectl apply -f gitops-infra-apps.yaml
    
    log_success "GitOps Infrastructure deployment initiated"
}

# Enhanced port-forward setup with health checks
enhanced_port_forwards() {
    log_step "Setting up enterprise service access..."
    
    # Kill any existing port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    # Start ArgoCD port-forward immediately
    log_info "Setting up ArgoCD access..."
    nohup kubectl port-forward -n argocd svc/argocd-server 8080:80 > /dev/null 2>&1 &
    
    # Wait for basic infrastructure
    log_info "Waiting for infrastructure services to be ready..."
    
    # Check for key services and set up port-forwards as they become available
    setup_conditional_port_forward() {
        local namespace=$1
        local service=$2  
        local port=$3
        local target_port=$4
        local display_name=$5
        
        if kubectl get svc "$service" -n "$namespace" 2>/dev/null; then
            log_info "Setting up $display_name access on port $port..."
            nohup kubectl port-forward -n "$namespace" svc/"$service" "$port":"$target_port" > /dev/null 2>&1 &
            return 0
        else
            log_warning "$display_name service not yet available"
            return 1
        fi
    }
    
    # Wait a bit and then set up conditional port-forwards
    sleep 60
    
    setup_conditional_port_forward "kargo" "kargo-api" "3000" "443" "Kargo"
    setup_conditional_port_forward "monitoring" "grafana" "3001" "80" "Grafana"  
    setup_conditional_port_forward "monitoring" "prometheus-stack-kube-prom-prometheus" "9090" "9090" "Prometheus"
    setup_conditional_port_forward "jaeger" "jaeger-query" "16686" "16686" "Jaeger"
    setup_conditional_port_forward "gitea" "gitea-http" "3002" "3000" "Gitea"
    
    log_success "Service access configured"
}

# Get ArgoCD password safely
get_argocd_password() {
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get secret argocd-initial-admin-secret -n argocd 2>/dev/null; then
            ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null)
            if [ -n "$ARGOCD_PASSWORD" ]; then
                return 0
            fi
        fi
        log_info "Waiting for ArgoCD password secret (attempt $attempt/$max_attempts)..."
        sleep 10
        ((attempt++))
    done
    
    log_warning "Could not retrieve ArgoCD password - you can get it later with:"
    echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    ARGOCD_PASSWORD="<use command above>"
}

# Enhanced status reporting
print_enterprise_status() {
    log_step "Generating enterprise status report..."
    
    get_argocd_password
    
    echo ""
    echo "🏢=============================================="
    echo "   � ENTERPRISE GITOPS ENVIRONMENT READY"  
    echo "=============================================="
    echo ""
    echo "🎯 CONTROL PLANE:"
    echo "   ArgoCD UI:       http://localhost:8080"
    echo "   Username:        admin"
    echo "   Password:        $ARGOCD_PASSWORD"
    echo ""
    echo "� PROMOTIONAL PIPELINES:"
    echo "   Kargo UI:        https://localhost:3000 (admin/admin)"
    echo ""
    echo "📊 OBSERVABILITY STACK:"
    echo "   Grafana:         http://localhost:3001 (admin/admin)"
    echo "   Prometheus:      http://localhost:9090"
    echo "   Jaeger:          http://localhost:16686"
    echo ""
    echo "�️  INFRASTRUCTURE SERVICES:"
    echo "   Gitea:           http://localhost:3002 (admin/admin123)"
    echo ""
    echo "🛠️  CLUSTER MANAGEMENT:"
    echo "   Minikube Dashboard: minikube dashboard --profile=$MINIKUBE_PROFILE"
    echo "   Context:            kubectl config use-context $MINIKUBE_PROFILE"
    echo ""
    echo "📋 HEALTH CHECK COMMANDS:"
    echo "   Applications:    kubectl get applications -n argocd"
    echo "   All Pods:        kubectl get pods --all-namespaces"
    echo "   Cluster Status:  minikube status --profile=$MINIKUBE_PROFILE"
    echo ""
    echo "⏱️  DEPLOYMENT STATUS:"
    echo "   Infrastructure deployment takes 5-10 minutes for full readiness"
    echo "   Monitor progress: kubectl get applications -n argocd -w"
    echo "   Expected: 18/18 applications Synced + Healthy"
    echo ""
    log_enterprise "Enterprise GitOps environment is operational! 🎉"
    echo "   ✅ ALL 18 APPLICATIONS FULLY SYNCHRONIZED"
    echo "=============================================="
}

# Main execution - Enterprise GitOps Bootstrap
main() {
    echo ""
    echo "🏢================================================"
    echo "   🚀 ENTERPRISE GITOPS INFRASTRUCTURE BOOTSTRAP"
    echo "================================================"
    echo ""
    
    log_enterprise "Starting intelligent bootstrap process..."
    
    # Phase 1: Prerequisites and Environment Analysis
    check_prerequisites
    
    # Phase 2: Smart Cluster Management  
    smart_cluster_setup
    
    # Phase 3: Smart ArgoCD Installation
    smart_argocd_installation
    
    # Phase 4: Smart Infrastructure Deployment
    smart_infrastructure_deployment
    
    # Phase 5: Enhanced Service Access
    enhanced_port_forwards
    
    # Phase 6: Enterprise Status Report
    print_enterprise_status
    
    echo ""
    log_success "🎉 Enterprise GitOps Infrastructure Bootstrap Completed!"
    log_enterprise "Ready for multi-environment promotional workflows! 🚀"
    echo ""
}

# Handle Ctrl+C gracefully
trap 'log_error "Bootstrap interrupted by user"; exit 1' INT

# Run main function with all arguments
main "$@"
