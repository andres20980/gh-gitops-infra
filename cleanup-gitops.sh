#!/bin/bash

# 🗑️ Enterprise GitOps Infrastructure Cleanup Script
# Intelligent cleanup with multiple options for different scenarios

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Soft cleanup - stop cluster but preserve data
soft_cleanup() {
    echo ""
    echo "� SOFT CLEANUP - PRESERVING DATA"
    echo "================================="
    
    log_info "Stopping port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    if minikube status --profile="$MINIKUBE_PROFILE" 2>/dev/null | grep -q "Running"; then
        log_info "Stopping Minikube cluster (preserving data)..."
        minikube stop --profile="$MINIKUBE_PROFILE"
        log_success "Cluster stopped - data preserved"
        echo ""
        echo "💡 To restart: minikube start --profile=$MINIKUBE_PROFILE"
        echo "💡 To resume: ./scripts/setup-port-forwards.sh"
    else
        log_info "Cluster is not running"
    fi
}

# Reset cleanup - delete applications but keep cluster
reset_cleanup() {
    echo ""
    echo "🔄 RESET CLEANUP - CLUSTER RESET"
    echo "================================"
    
    log_warning "This will delete all applications but keep the cluster"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Reset cancelled"
        return
    fi
    
    log_info "Stopping port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    if kubectl config current-context | grep -q "$MINIKUBE_PROFILE"; then
        log_info "Deleting all ArgoCD applications..."
        kubectl delete applications --all -n argocd 2>/dev/null || true
        
        log_info "Deleting application namespaces..."
        local namespaces=("kargo" "monitoring" "grafana" "jaeger" "loki" "gitea" "minio" "argo-workflows" "argo-rollouts" "ingress-nginx" "cert-manager" "external-secrets" "demo-project")
        
        for ns in "${namespaces[@]}"; do
            if kubectl get namespace "$ns" 2>/dev/null; then
                log_info "Deleting namespace: $ns"
                kubectl delete namespace "$ns" --timeout=60s 2>/dev/null || true
            fi
        done
        
        log_success "Applications reset - cluster ready for fresh deployment"
        echo ""
        echo "💡 To redeploy: ./bootstrap-gitops.sh"
    else
        log_warning "Cluster context not found - nothing to reset"
    fi
}

# Full cleanup - complete destruction
full_cleanup() {
    echo ""
    echo "💥 FULL CLEANUP - COMPLETE DESTRUCTION"
    echo "======================================"
    
    log_error "This will DELETE EVERYTHING in the GitOps environment!"
    log_warning "⚠️  This action is IRREVERSIBLE ⚠️"
    echo ""
    read -p "Are you ABSOLUTELY sure? Type 'DELETE' to confirm: " -r
    echo
    
    if [[ $REPLY != "DELETE" ]]; then
        log_info "Full cleanup cancelled"
        return
    fi
    
    log_info "Stopping all port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    log_info "Deleting Minikube profile: $MINIKUBE_PROFILE"
    minikube delete --profile="$MINIKUBE_PROFILE" || true
    
    log_info "Cleaning kubectl contexts..."
    kubectl config delete-context "$MINIKUBE_PROFILE" 2>/dev/null || true
    kubectl config delete-cluster "$MINIKUBE_PROFILE" 2>/dev/null || true
    kubectl config delete-user "$MINIKUBE_PROFILE" 2>/dev/null || true
    
    log_success "💥 Complete destruction completed"
    echo ""
    echo "💡 To rebuild: ./bootstrap-gitops.sh"
}

# Show cleanup options
show_menu() {
    echo ""
    echo "🏢================================================"
    echo "   🗑️ ENTERPRISE GITOPS CLEANUP OPTIONS"
    echo "================================================"
    echo ""
    echo "Choose cleanup level:"
    echo ""
    echo "1) 🛑 SOFT CLEANUP"
    echo "   - Stop cluster but preserve all data"
    echo "   - Quick restart capability"
    echo "   - Recommended for temporary shutdown"
    echo ""
    echo "2) 🔄 RESET CLEANUP"
    echo "   - Delete applications but keep cluster"
    echo "   - Clean slate for new deployments"
    echo "   - Faster than full rebuild"
    echo ""
    echo "3) 💥 FULL CLEANUP"
    echo "   - Complete destruction of everything"
    echo "   - Free all resources"
    echo "   - ⚠️ IRREVERSIBLE ⚠️"
    echo ""
    echo "4) ❌ CANCEL"
    echo ""
    read -p "Select option (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            soft_cleanup
            ;;
        2)
            reset_cleanup
            ;;
        3)
            full_cleanup
            ;;
        4)
            log_info "Cleanup cancelled"
            ;;
        *)
            log_error "Invalid option: $REPLY"
            exit 1
            ;;
    esac
}

# Check cluster status
check_status() {
    echo ""
    echo "🔍 CURRENT ENVIRONMENT STATUS"
    echo "============================="
    
    if minikube profile list 2>/dev/null | grep -q "$MINIKUBE_PROFILE"; then
        log_info "Minikube profile '$MINIKUBE_PROFILE' exists"
        
        if minikube status --profile="$MINIKUBE_PROFILE" 2>/dev/null | grep -q "Running"; then
            log_success "Cluster is running"
            
            # Check applications
            if kubectl config current-context | grep -q "$MINIKUBE_PROFILE" 2>/dev/null; then
                local app_count=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
                log_info "ArgoCD applications: $app_count"
                
                local pf_count=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
                log_info "Active port-forwards: $pf_count"
            else
                log_warning "Cluster context not set"
            fi
        else
            log_warning "Cluster exists but not running"
        fi
    else
        log_info "No GitOps environment found"
    fi
}

# Main execution
main() {
    case "${1:-menu}" in
        "soft")
            check_status
            soft_cleanup
            ;;
        "reset")
            check_status
            reset_cleanup
            ;;
        "full")
            check_status
            full_cleanup
            ;;
        "status")
            check_status
            ;;
        "menu"|"")
            check_status
            show_menu
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [soft|reset|full|status|menu|help]"
            echo ""
            echo "Commands:"
            echo "  soft    - Stop cluster, preserve data"
            echo "  reset   - Delete apps, keep cluster"
            echo "  full    - Complete destruction"
            echo "  status  - Show current status"
            echo "  menu    - Show interactive menu (default)"
            echo "  help    - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C
trap 'log_warning "Cleanup interrupted"; exit 1' INT
    # Handle Ctrl+C
trap 'log_warning "Cleanup interrupted"; exit 1' INT

main "$@"

main "$@"
