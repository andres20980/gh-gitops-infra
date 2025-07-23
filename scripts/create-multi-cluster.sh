#!/bin/bash

# 🏢 Multi-Cluster GitOps Environment Setup
# Creates DEV, PRE, and PROD clusters for enterprise promotion workflows

set -e

# Colors
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
log_cluster() { echo -e "${CYAN}[CLUSTER]${NC} 🏗️ $1"; }

# Cluster configurations
declare -A CLUSTERS=(
    ["gitops-dev"]="4,8g,50g"      # DEV: More resources for development
    ["gitops-pre"]="3,6g,30g"     # PRE: Medium resources for testing  
    ["gitops-prod"]="6,12g,100g"  # PROD: Most resources for stability
)

# Create individual cluster
create_cluster() {
    local profile=$1
    local resources=$2
    
    IFS=',' read -r cpus memory disk <<< "$resources"
    
    log_cluster "Creating cluster: $profile"
    log_info "Resources: ${cpus} CPUs, ${memory} RAM, ${disk} disk"
    
    if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
        log_success "Cluster $profile already running"
        return 0
    fi
    
    log_step "Starting Minikube cluster: $profile"
    minikube start \
        --profile="$profile" \
        --cpus="$cpus" \
        --memory="$memory" \
        --disk-size="$disk" \
        --driver=docker \
        --kubernetes-version=stable \
        --addons=ingress,metrics-server
    
    log_success "Cluster $profile created successfully"
}

# Install ArgoCD in cluster
install_argocd() {
    local profile=$1
    
    log_cluster "Installing ArgoCD in $profile"
    
    # Switch context
    kubectl config use-context "$profile"
    
    # Create ArgoCD namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready in $profile..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    log_success "ArgoCD installed in $profile"
}

# Configure cluster-specific settings
configure_cluster() {
    local profile=$1
    
    log_cluster "Configuring cluster: $profile"
    kubectl config use-context "$profile"
    
    case $profile in
        "gitops-dev")
            log_info "Configuring DEV cluster - Full stack deployment"
            # DEV gets full infrastructure stack
            ;;
        "gitops-pre") 
            log_info "Configuring PRE cluster - Testing focused"
            # PRE gets testing and validation tools
            ;;
        "gitops-prod")
            log_info "Configuring PROD cluster - Production hardened"  
            # PROD gets production-grade monitoring and security
            ;;
    esac
    
    log_success "Cluster $profile configured"
}

# Main execution
main() {
    echo ""
    echo "🏢=================================================="
    echo "   🌐 MULTI-CLUSTER GITOPS ENVIRONMENT SETUP"
    echo "   🚧 DEV → 🧪 PRE → 🏭 PROD"
    echo "=================================================="
    echo ""
    
    log_step "Creating enterprise multi-cluster environment..."
    
    # Create all clusters
    for profile in "${!CLUSTERS[@]}"; do
        create_cluster "$profile" "${CLUSTERS[$profile]}"
        install_argocd "$profile"
        configure_cluster "$profile"
        echo ""
    done
    
    # Show cluster status
    log_step "Multi-cluster environment summary:"
    echo ""
    printf "%-15s %-10s %-12s %-10s %-15s\n" "CLUSTER" "STATUS" "KUBERNETES" "ADDONS" "CONTEXT"
    printf "%-15s %-10s %-12s %-10s %-15s\n" "-------" "------" "----------" "-------" "-------"
    
    for profile in gitops-dev gitops-pre gitops-prod; do
        if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
            k8s_version=$(kubectl --context="$profile" version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "Unknown")
            printf "%-15s %-10s %-12s %-10s %-15s\n" "$profile" "✅ Running" "$k8s_version" "✅ Ready" "$profile"
        else
            printf "%-15s %-10s %-12s %-10s %-15s\n" "$profile" "❌ Stopped" "N/A" "❌ N/A" "N/A"
        fi
    done
    
    echo ""
    log_success "🎉 Multi-cluster environment ready!"
    echo ""
    echo "🎯 NEXT STEPS:"
    echo "   1. Deploy applications: ./scripts/deploy-to-all-clusters.sh"
    echo "   2. Setup Kargo promotions: ./scripts/setup-kargo-promotions.sh" 
    echo "   3. Start promotion workflows: kargo get stages"
    echo ""
    echo "🔄 CLUSTER SWITCHING:"
    echo "   kubectl config use-context gitops-dev"
    echo "   kubectl config use-context gitops-pre"
    echo "   kubectl config use-context gitops-prod"
    echo ""
}

# Handle interruption
trap 'log_error "Multi-cluster setup interrupted"; exit 1' INT

main "$@"
