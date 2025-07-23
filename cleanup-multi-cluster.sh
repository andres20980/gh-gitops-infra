#!/bin/bash

# 🗑️ Multi-Cluster GitOps Cleanup Script
# Manages cleanup of DEV, PRE, and PROD clusters with multiple options

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
log_enterprise() { echo -e "${CYAN}[ENTERPRISE]${NC} 🏢 $1"; }

CLUSTERS=("gitops-dev" "gitops-pre" "gitops-prod")

# Check cluster status
check_multi_cluster_status() {
    echo ""
    echo "🔍 MULTI-CLUSTER ENVIRONMENT STATUS"
    echo "==================================="
    
    local running_clusters=0
    local total_clusters=${#CLUSTERS[@]}
    
    printf "%-15s %-10s %-15s %-12s\n" "CLUSTER" "STATUS" "K8S VERSION" "APPLICATIONS"
    printf "%-15s %-10s %-15s %-12s\n" "-------" "------" "-----------" "------------"
    
    for cluster in "${CLUSTERS[@]}"; do
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            ((running_clusters++))
            
            # Get Kubernetes version
            local k8s_version=$(kubectl --context="$cluster" version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "Unknown")
            
            # Get application count
            local app_count=$(kubectl --context="$cluster" get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
            
            printf "%-15s %-10s %-15s %-12s\n" "$cluster" "✅ Running" "$k8s_version" "${app_count} apps"
        else
            printf "%-15s %-10s %-15s %-12s\n" "$cluster" "❌ Stopped" "N/A" "N/A"
        fi
    done
    
    echo ""
    log_info "Running clusters: $running_clusters/$total_clusters"
    
    # Check port-forwards
    local pf_count=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
    log_info "Active port-forwards: $pf_count"
}

# Soft cleanup - stop clusters but preserve data
soft_cleanup() {
    echo ""
    echo "🛑 SOFT CLEANUP - PRESERVING ALL DATA"
    echo "===================================="
    
    log_info "Stopping all port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    for cluster in "${CLUSTERS[@]}"; do
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            log_info "Stopping cluster: $cluster (preserving data)..."
            minikube stop --profile="$cluster"
            log_success "Cluster $cluster stopped"
        else
            log_info "Cluster $cluster already stopped"
        fi
    done
    
    echo ""
    log_success "All clusters stopped - data preserved"
    echo ""
    echo "💡 To restart all clusters: ./bootstrap-multi-cluster.sh"
    echo "💡 To start individual cluster: minikube start --profile=<cluster-name>"
}

# Reset cleanup - delete applications but keep clusters
reset_cleanup() {
    echo ""
    echo "🔄 RESET CLEANUP - APPLICATIONS ONLY"
    echo "===================================="
    
    read -p "This will delete all applications but keep clusters. Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Reset cancelled"
        return
    fi
    
    log_info "Stopping port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    for cluster in "${CLUSTERS[@]}"; do
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            log_info "Resetting applications in: $cluster"
            kubectl config use-context "$cluster"
            
            # Delete ArgoCD applications
            kubectl delete applications --all -n argocd 2>/dev/null || true
            
            # Delete application namespaces
            local namespaces=("kargo" "monitoring" "grafana" "jaeger" "loki" "gitea" "minio" "argo-workflows" "argo-rollouts" "ingress-nginx" "cert-manager" "external-secrets" "demo-project")
            
            for ns in "${namespaces[@]}"; do
                if kubectl get namespace "$ns" 2>/dev/null; then
                    log_info "Deleting namespace: $ns in $cluster"
                    kubectl delete namespace "$ns" --timeout=60s 2>/dev/null || true
                fi
            done
            
            log_success "Applications reset in: $cluster"
        else
            log_warning "Cluster $cluster not running - skipping reset"
        fi
    done
    
    echo ""
    log_success "All applications reset - clusters ready for fresh deployment"
    echo "💡 To redeploy: ./bootstrap-multi-cluster.sh"
}

# Partial cleanup - destroy specific cluster
partial_cleanup() {
    echo ""
    echo "🎯 PARTIAL CLEANUP - SINGLE CLUSTER"
    echo "==================================="
    echo ""
    echo "Select cluster to destroy:"
    echo "1) gitops-dev  (Development)"
    echo "2) gitops-pre  (Pre-production/UAT)" 
    echo "3) gitops-prod (Production)"
    echo "4) Cancel"
    echo ""
    
    read -p "Select cluster (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1) target_cluster="gitops-dev" ;;
        2) target_cluster="gitops-pre" ;;
        3) target_cluster="gitops-prod" ;;
        4) log_info "Partial cleanup cancelled"; return ;;
        *) log_error "Invalid option: $REPLY"; return ;;
    esac
    
    echo ""
    log_warning "This will PERMANENTLY DELETE cluster: $target_cluster"
    read -p "Type 'DELETE' to confirm: " -r
    echo
    
    if [[ $REPLY != "DELETE" ]]; then
        log_info "Partial cleanup cancelled"
        return
    fi
    
    log_info "Destroying cluster: $target_cluster"
    minikube delete --profile="$target_cluster" || true
    
    # Clean kubectl contexts
    kubectl config delete-context "$target_cluster" 2>/dev/null || true
    kubectl config delete-cluster "$target_cluster" 2>/dev/null || true
    kubectl config delete-user "$target_cluster" 2>/dev/null || true
    
    log_success "Cluster $target_cluster destroyed"
}

# Full cleanup - complete destruction
full_cleanup() {
    echo ""
    echo "💥 FULL CLEANUP - COMPLETE DESTRUCTION"
    echo "======================================"
    
    log_error "This will DELETE ALL CLUSTERS in the multi-cluster environment!"
    log_warning "⚠️  This action is IRREVERSIBLE ⚠️"
    echo ""
    echo "Clusters that will be destroyed:"
    for cluster in "${CLUSTERS[@]}"; do
        echo "   🗑️  $cluster"
    done
    echo ""
    
    read -p "Are you ABSOLUTELY sure? Type 'DELETE ALL' to confirm: " -r
    echo
    
    if [[ $REPLY != "DELETE ALL" ]]; then
        log_info "Full cleanup cancelled"
        return
    fi
    
    log_info "Stopping all port-forwards..."
    pkill -f "kubectl port-forward" 2>/dev/null || true
    
    for cluster in "${CLUSTERS[@]}"; do
        log_info "Destroying cluster: $cluster"
        minikube delete --profile="$cluster" || true
        
        # Clean kubectl contexts
        kubectl config delete-context "$cluster" 2>/dev/null || true
        kubectl config delete-cluster "$cluster" 2>/dev/null || true
        kubectl config delete-user "$cluster" 2>/dev/null || true
    done
    
    log_success "💥 Complete multi-cluster destruction completed"
    echo ""
    echo "💡 To rebuild: ./bootstrap-multi-cluster.sh"
}

# Show cleanup menu
show_menu() {
    echo ""
    echo "🏢========================================================"
    echo "   🗑️ MULTI-CLUSTER GITOPS CLEANUP OPTIONS"
    echo "   🚧 DEV → 🧪 PRE → 🏭 PROD"
    echo "========================================================"
    echo ""
    echo "Choose cleanup level:"
    echo ""
    echo "1) 🛑 SOFT CLEANUP"
    echo "   - Stop all clusters but preserve data"
    echo "   - Quick restart capability"
    echo "   - All data and configurations preserved"
    echo ""
    echo "2) 🔄 RESET CLEANUP"
    echo "   - Delete applications but keep clusters"
    echo "   - Clean slate for new deployments"
    echo "   - Faster than full rebuild"
    echo ""
    echo "3) 🎯 PARTIAL CLEANUP"
    echo "   - Destroy single cluster (DEV/PRE/PROD)"
    echo "   - Selective environment management"
    echo "   - Other clusters remain intact"
    echo ""
    echo "4) 💥 FULL CLEANUP"
    echo "   - Complete destruction of ALL clusters"
    echo "   - Free all resources"
    echo "   - ⚠️ IRREVERSIBLE ⚠️"
    echo ""
    echo "5) ❌ CANCEL"
    echo ""
    read -p "Select option (1-5): " -n 1 -r
    echo
    
    case $REPLY in
        1) soft_cleanup ;;
        2) reset_cleanup ;;
        3) partial_cleanup ;;
        4) full_cleanup ;;
        5) log_info "Cleanup cancelled" ;;
        *) log_error "Invalid option: $REPLY"; exit 1 ;;
    esac
}

# Main execution
main() {
    case "${1:-menu}" in
        "soft")
            check_multi_cluster_status
            soft_cleanup
            ;;
        "reset")
            check_multi_cluster_status
            reset_cleanup
            ;;
        "partial")
            check_multi_cluster_status
            partial_cleanup
            ;;
        "full")
            check_multi_cluster_status
            full_cleanup
            ;;
        "status")
            check_multi_cluster_status
            ;;
        "menu"|"")
            check_multi_cluster_status
            show_menu
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [soft|reset|partial|full|status|menu|help]"
            echo ""
            echo "Commands:"
            echo "  soft     - Stop clusters, preserve data"
            echo "  reset    - Delete apps, keep clusters"
            echo "  partial  - Delete single cluster"
            echo "  full     - Complete destruction"
            echo "  status   - Show current status"
            echo "  menu     - Show interactive menu (default)"
            echo "  help     - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle interruption
trap 'log_warning "Multi-cluster cleanup interrupted"; exit 1' INT

main "$@"
