#!/bin/bash

# 🏢 Enterprise Multi-Cluster GitOps Bootstrap
# Creates complete DEV → PRE → PROD environment with Kargo promotions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} 🔍 $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} ❌ $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} 🚀 $1"; }
log_enterprise() { echo -e "${CYAN}[ENTERPRISE]${NC} 🏢 $1"; }

# Load configuration
CONFIG_FILE="config/environment.conf"

load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE..."
        source "$CONFIG_FILE"
        log_success "Configuration loaded successfully"
    else
        log_warning "Configuration file not found: $CONFIG_FILE"
        log_info "Using default configuration. Run ./setup-config.sh to customize."
        
        # Default configuration
        GITHUB_REPO_URL="https://github.com/andres20980/gh-gitops-infra.git"
        GITHUB_USERNAME="andres20980"
        DEV_CLUSTER_PROFILE="gitops-dev"
        PRE_CLUSTER_PROFILE="gitops-pre"
        PROD_CLUSTER_PROFILE="gitops-prod"
        DEV_CLUSTER_RESOURCES="4,8g,50g"
        PRE_CLUSTER_RESOURCES="3,6g,30g"
        PROD_CLUSTER_RESOURCES="6,12g,100g"
        ARGOCD_DEV_PORT="8080"
        ARGOCD_PRE_PORT="8081"
        ARGOCD_PROD_PORT="8082"
        ARGOCD_VERSION="v2.12.3"
        KARGO_VERSION="v0.8.4"
        ORGANIZATION_NAME="YourOrg"
        ENABLE_MONITORING="true"
        ENABLE_GRAFANA="true"
        ENABLE_JAEGER="true"
        ENABLE_LOKI="true"
        ENABLE_MINIO="true"
    fi
}

# Cluster configurations (now loaded from config file)
declare -A CLUSTERS

# Initialize clusters array from configuration
initialize_clusters() {
    CLUSTERS["$DEV_CLUSTER_PROFILE"]="$DEV_CLUSTER_RESOURCES,$ARGOCD_DEV_PORT"
    CLUSTERS["$PRE_CLUSTER_PROFILE"]="$PRE_CLUSTER_RESOURCES,$ARGOCD_PRE_PORT"
    CLUSTERS["$PROD_CLUSTER_PROFILE"]="$PROD_CLUSTER_RESOURCES,$ARGOCD_PROD_PORT"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites for multi-cluster setup..."
    
    local tools=("minikube" "kubectl" "helm" "docker")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing tools: ${missing[*]}"
        log_info "Please install missing prerequisites or run ./install-everything.sh"
        exit 1
    fi
    
    # Check resources
    local total_cpus=$(echo "${CLUSTERS[@]}" | tr ',' '\n' | awk '{sum+=$1} END {print sum}')
    local total_memory=$(echo "${CLUSTERS[@]}" | tr ',' '\n' | sed 's/g$//' | awk '{sum+=$2} END {print sum}')
    
    log_info "Required resources: ${total_cpus} CPUs, ${total_memory}GB RAM"
    log_success "Prerequisites check completed"
}

# Create and setup individual cluster
create_cluster() {
    local profile=$1
    local resources=$2
    
    IFS=',' read -r cpus memory disk port <<< "$resources"
    
    log_enterprise "Setting up cluster: $profile"
    log_info "Configuration: ${cpus} CPUs, ${memory} RAM, ${disk} disk"
    
    # Check if cluster already exists and is healthy
    if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
        log_success "Cluster $profile already running - checking health..."
        kubectl config use-context "$profile"
        
        if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            log_success "Cluster $profile is healthy - skipping creation"
            return 0
        else
            log_warning "Cluster $profile unhealthy - recreating..."
            minikube delete --profile="$profile" 2>/dev/null || true
        fi
    fi
    
    log_step "Creating Minikube cluster: $profile"
    minikube start \
        --profile="$profile" \
        --cpus="$cpus" \
        --memory="$memory" \
        --disk-size="$disk" \
        --driver=docker \
        --kubernetes-version=stable \
        --addons=ingress,metrics-server,dashboard
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster nodes to be ready..."
    kubectl config use-context "$profile"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "Cluster $profile created successfully"
}

# Install ArgoCD with cluster-specific configuration
install_argocd() {
    local profile=$1
    local resources=$2
    
    IFS=',' read -r cpus memory disk port <<< "$resources"
    
    log_step "Installing ArgoCD in $profile (port: $port)"
    kubectl config use-context "$profile"
    
    # Create ArgoCD namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD server to be ready in $profile..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    
    log_success "ArgoCD installed in $profile"
}

# Deploy environment-specific applications
deploy_environment_apps() {
    local profile=$1
    
    log_step "Deploying applications for $profile environment"
    kubectl config use-context "$profile"
    
    case $profile in
        "$DEV_CLUSTER_PROFILE")
            log_info "Deploying full development stack..."
            # Deploy infrastructure based on enabled components
            deploy_conditional_apps
            
            # Deploy Kargo for promotion management (only in DEV)
            kubectl create namespace kargo --dry-run=client -o yaml | kubectl apply -f -
            ;;
        "$PRE_CLUSTER_PROFILE")
            log_info "Deploying UAT/testing environment..."
            # Deploy minimal infrastructure for testing
            deploy_minimal_stack "$profile"
            ;;
        "$PROD_CLUSTER_PROFILE")
            log_info "Deploying production environment..."
            # Deploy production-grade infrastructure
            deploy_production_stack "$profile"
            ;;
    esac
    
    log_success "Applications deployed for $profile"
}

# Deploy components based on configuration
deploy_conditional_apps() {
    log_info "Deploying components based on configuration..."
    
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        log_info "✅ Monitoring enabled - deploying full infrastructure"
        kubectl apply -f gitops-infra-apps.yaml 2>/dev/null || log_warning "Main apps config not found"
    else
        log_info "⚠️ Monitoring disabled - deploying minimal stack"
        deploy_minimal_stack_components
    fi
}

# Deploy minimal stack for PRE environment
deploy_minimal_stack() {
    local profile=$1
    log_info "Configuring minimal stack for $profile..."
    
    # Create essential namespaces
    for ns in monitoring demo-project; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    done
}

# Deploy minimal components when monitoring is disabled
deploy_minimal_stack_components() {
    log_info "Deploying minimal component stack..."
    
    # Create basic namespaces
    for ns in demo-project; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    done
    
    # Deploy only essential ArgoCD applications for demo project
    if [[ -f "projects/demo-project/app-of-apps.yaml" ]]; then
        kubectl apply -f projects/demo-project/app-of-apps.yaml 2>/dev/null || log_warning "Demo project config not found"
    fi
}

# Deploy production stack
deploy_production_stack() {
    local profile=$1
    log_info "Configuring production-grade stack for $profile..."
    
    # Create production namespaces with resource limits
    for ns in monitoring demo-project; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
    done
    
    # TODO: Add production-specific configurations (resource quotas, network policies, etc.)
}

# Setup port-forwards for all clusters
setup_multi_cluster_access() {
    log_step "Setting up access to all clusters..."
    
    # Stop any existing port-forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2
    
    for profile in "${!CLUSTERS[@]}"; do
        IFS=',' read -r cpus memory disk port <<< "${CLUSTERS[$profile]}"
        
        if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
            log_info "Setting up ArgoCD access for $profile on port $port..."
            
            # Switch context and start port-forward in background
            kubectl config use-context "$profile"
            nohup kubectl port-forward -n argocd svc/argocd-server $port:80 > /dev/null 2>&1 &
            
            log_success "ArgoCD $profile: http://localhost:$port"
        else
            log_warning "Cluster $profile not running - skipping port-forward"
        fi
    done
    
    log_success "Multi-cluster access configured"
}

# Get ArgoCD passwords for all clusters
get_all_argocd_passwords() {
    local passwords=()
    
    for profile in "$DEV_CLUSTER_PROFILE" "$PRE_CLUSTER_PROFILE" "$PROD_CLUSTER_PROFILE"; do
        if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
            kubectl config use-context "$profile"
            local password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Not available")
            passwords+=("$profile:$password")
        fi
    done
    
    echo "${passwords[@]}"
}

# Print comprehensive status
print_multi_cluster_status() {
    log_step "Generating multi-cluster enterprise status..."
    
    local passwords=($(get_all_argocd_passwords))
    
    echo ""
    echo "🏢============================================================="
    echo "   🌐 ENTERPRISE MULTI-CLUSTER GITOPS ENVIRONMENT READY"
    echo "   🚧 DEV → 🧪 PRE → 🏭 PROD"
    echo "   🏢 Organization: $ORGANIZATION_NAME"
    echo "============================================================="
    echo ""
    echo "🎯 CONTROL PLANES:"
    printf "%-10s %-25s %-15s %-20s\n" "CLUSTER" "ARGOCD URL" "STATUS" "PASSWORD"
    printf "%-10s %-25s %-15s %-20s\n" "-------" "----------" "------" "--------"
    
    for profile in "$DEV_CLUSTER_PROFILE" "$PRE_CLUSTER_PROFILE" "$PROD_CLUSTER_PROFILE"; do
        IFS=',' read -r cpus memory disk port <<< "${CLUSTERS[$profile]}"
        
        if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
            # Find password for this profile
            local profile_password="Not available"
            for pwd_entry in "${passwords[@]}"; do
                if [[ "$pwd_entry" == "$profile:"* ]]; then
                    profile_password="${pwd_entry#*:}"
                    break
                fi
            done
            
            printf "%-10s %-25s %-15s %-20s\n" "$profile" "http://localhost:$port" "✅ Running" "$profile_password"
        else
            printf "%-10s %-25s %-15s %-20s\n" "$profile" "http://localhost:$port" "❌ Stopped" "N/A"
        fi
    done
    
    echo ""
    echo "🔄 PROMOTION WORKFLOW:"
    echo "   1. 🚧 DEV (gitops-dev)  → Auto-deploy from main branch"
    echo "   2. 🧪 PRE (gitops-pre)  → Manual promotion from DEV" 
    echo "   3. 🏭 PROD (gitops-prod)→ Manual promotion from PRE"
    echo ""
    echo "🛠️  CLUSTER MANAGEMENT:"
    echo "   Switch context: kubectl config use-context <cluster-name>"
    echo "   Cluster status: ./scripts/cluster-status.sh"
    echo "   Stop all:       ./cleanup-multi-cluster.sh soft"
    echo ""
    echo "📊 NEXT STEPS FOR KARGO SETUP:"
    echo "   1. Deploy Kargo:     kubectl apply -f components/kargo/kargo.yaml"
    echo "   2. Setup projects:   kubectl apply -f examples/kargo-multi-env.yaml"  
    echo "   3. Access Kargo UI:  kubectl port-forward -n kargo svc/kargo-api 3000:443"
    echo ""
    echo "🔧 CONFIGURATION SUMMARY:"
    echo "   Repository:      $GITHUB_REPO_URL"
    echo "   ArgoCD Version:  $ARGOCD_VERSION"
    echo "   Kargo Version:   $KARGO_VERSION"
    echo "   Monitoring:      $([ "$ENABLE_MONITORING" == "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo "   Grafana:         $([ "$ENABLE_GRAFANA" == "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo "   Jaeger:          $([ "$ENABLE_JAEGER" == "true" ] && echo "✅ Enabled" || echo "❌ Disabled")"
    echo ""
    log_enterprise "Multi-cluster GitOps environment operational! 🎉"
    echo "============================================================="
}

# Main execution
main() {
    echo ""
    echo "🏢======================================================"
    echo "   🌐 ENTERPRISE MULTI-CLUSTER BOOTSTRAP"
    echo "   🚧 DEV + 🧪 PRE + 🏭 PROD"
    echo "======================================================"
    echo ""
    
    log_enterprise "Initializing multi-cluster GitOps environment..."
    
    # Phase 0: Load configuration
    load_configuration
    initialize_clusters
    
    # Phase 1: Prerequisites
    check_prerequisites
    
    # Phase 2: Create all clusters
    log_step "Creating enterprise cluster ecosystem..."
    for profile in "$DEV_CLUSTER_PROFILE" "$PRE_CLUSTER_PROFILE" "$PROD_CLUSTER_PROFILE"; do
        create_cluster "$profile" "${CLUSTERS[$profile]}"
        install_argocd "$profile" "${CLUSTERS[$profile]}"
        deploy_environment_apps "$profile"
        echo ""
    done
    
    # Phase 3: Setup access
    setup_multi_cluster_access
    
    # Give services time to start
    log_info "Waiting for all services to be ready (60 seconds)..."
    sleep 60
    
    # Phase 4: Status report
    print_multi_cluster_status
    
    echo ""
    log_success "🎉 Multi-cluster enterprise environment ready!"
    log_enterprise "Ready for advanced promotion workflows! 🚀"
    echo ""
}

# Handle interruption
trap 'log_error "Multi-cluster bootstrap interrupted"; exit 1' INT

main "$@"
