#!/bin/bash

# 📊 Mullog_step() { echo -e "${PURPLE}[STEP]${NC} 🚀 $1"; }
log_enterprise() { echo -e "${CYAN}[ENTERPRISE]${NC} 🏢 $1"; }

# Load configuration
CONFIG_FILE="config/environment.conf"

load_configuration() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        # Default configuration
        DEV_CLUSTER_PROFILE="gitops-dev"
        PRE_CLUSTER_PROFILE="gitops-pre"
        PROD_CLUSTER_PROFILE="gitops-prod"
        ARGOCD_DEV_PORT="8080"
        ARGOCD_PRE_PORT="8081"
        ARGOCD_PROD_PORT="8082"
    fi
}

# Initialize after loading config
load_configuration
CLUSTERS=("$DEV_CLUSTER_PROFILE" "$PRE_CLUSTER_PROFILE" "$PROD_CLUSTER_PROFILE")

# ArgoCD port mapping
declare -A ARGOCD_PORTS=(
    ["$DEV_CLUSTER_PROFILE"]="$ARGOCD_DEV_PORT"
    ["$PRE_CLUSTER_PROFILE"]="$ARGOCD_PRE_PORT"
    ["$PROD_CLUSTER_PROFILE"]="$ARGOCD_PROD_PORT"
) Status Check Script
# Comprehensive health check for multi-cluster GitOps infrastructure

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
log_cluster() { echo -e "${CYAN}[CLUSTER]${NC} 🏗️ $1"; }

# Multi-cluster configuration
CLUSTERS=("gitops-dev" "gitops-pre" "gitops-prod")
declare -A CLUSTER_PORTS=(
    ["gitops-dev"]="8080"
    ["gitops-pre"]="8081" 
    ["gitops-prod"]="8082"
)

# Check all clusters status
check_all_clusters_status() {
    log_step "Checking multi-cluster environment status..."
    
    local total_clusters=${#CLUSTERS[@]}
    local running_clusters=0
    local healthy_clusters=0
    
    printf "\n%-15s %-12s %-15s %-12s %-15s\n" "CLUSTER" "STATUS" "K8S VERSION" "ARGOCD" "APPLICATIONS"
    printf "%-15s %-12s %-15s %-12s %-15s\n" "-------" "------" "-----------" "------" "------------"
    
    for cluster in "${CLUSTERS[@]}"; do
        local cluster_status="❌ Stopped"
        local k8s_version="N/A"
        local argocd_status="❌ N/A"
        local app_info="N/A"
        
        # Check if cluster exists and is running
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            cluster_status="✅ Running"
            ((running_clusters++))
            
            # Get Kubernetes version
            kubectl config use-context "$cluster" 2>/dev/null || continue
            k8s_version=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "Unknown")
            
            # Check ArgoCD status
            if kubectl get namespace argocd 2>/dev/null && kubectl get deployment argocd-server -n argocd 2>/dev/null | grep -q "1/1"; then
                argocd_status="✅ Healthy"
                ((healthy_clusters++))
                
                # Get application count and health
                local app_count=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
                local synced_count=$(kubectl get applications -n argocd -o json 2>/dev/null | jq '[.items[] | select(.status.sync.status=="Synced")] | length' 2>/dev/null || echo "0")
                app_info="${synced_count}/${app_count} synced"
            else
                argocd_status="❌ Unhealthy"
            fi
        fi
        
        printf "%-15s %-12s %-15s %-12s %-15s\n" "$cluster" "$cluster_status" "$k8s_version" "$argocd_status" "$app_info"
    done
    
    echo ""
    log_info "Cluster summary: $running_clusters/$total_clusters running, $healthy_clusters/$total_clusters healthy"
    
    return $([ $running_clusters -gt 0 ] && echo 0 || echo 1)
}

# Check specific cluster detailed status
check_cluster_detail() {
    local cluster=$1
    
    log_cluster "Detailed status for: $cluster"
    
    if ! minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
        log_error "Cluster $cluster is not running"
        return 1
    fi
    
    kubectl config use-context "$cluster"
    
    # Node status and resources
    log_info "Node information:"
    kubectl get nodes -o wide 2>/dev/null || log_warning "Cannot get node info"
    
    # ArgoCD applications
    log_info "ArgoCD applications:"
    if kubectl get namespace argocd 2>/dev/null; then
        kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL" 2>/dev/null | head -10
        local total_apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        if [ "$total_apps" -gt 10 ]; then
            log_info "... and $(($total_apps - 10)) more applications"
        fi
    else
        log_warning "ArgoCD namespace not found"
    fi
    
    # Namespace overview
    log_info "Active namespaces:"
    kubectl get namespaces --no-headers | grep -v -E "(default|kube-|local-path)" | wc -l | xargs -I {} echo "  {} application namespaces"
    
    # Resource usage (if metrics available)
    log_info "Resource usage:"
    kubectl top nodes 2>/dev/null || log_warning "Metrics not available"
    
    return 0
}

# Check ArgoCD across all clusters
check_all_argocd() {
    log_step "Checking ArgoCD status across all clusters..."
    
    for cluster in "${CLUSTERS[@]}"; do
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            kubectl config use-context "$cluster"
            
            echo "📊 ArgoCD Status in $cluster:"
            if kubectl get namespace argocd 2>/dev/null; then
                kubectl get deployments -n argocd --no-headers | awk '{print "  " $1 ": " $2}'
                
                # Get ArgoCD version
                local argocd_version=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>/dev/null || echo "Unknown")
                echo "  Version: $argocd_version"
                
                # Get admin password
                local admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Not available")
                echo "  Admin password: $admin_password"
            else
                log_warning "ArgoCD not found in $cluster"
            fi
            echo ""
        fi
    done
}

# Check port forwards
check_port_forwards() {
    log_step "Checking active port-forwards..."
    
    local pf_count=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
    log_info "Active port-forwards: $pf_count"
    
    if [ "$pf_count" -gt 0 ]; then
        echo ""
        echo "🔗 Active Port-forwards:"
        ps aux | grep "kubectl port-forward" | grep -v grep | while read -r line; do
            # Extract port and service info
            local port_info=$(echo "$line" | grep -o "localhost:[0-9]*" | head -1)
            local service_info=$(echo "$line" | grep -o "svc/[^ ]*" | head -1)
            echo "  - $port_info → $service_info"
        done
    fi
    
    echo ""
    echo "🌐 Expected Access Points:"
    for cluster in "${CLUSTERS[@]}"; do
        local port="${CLUSTER_PORTS[$cluster]}"
        echo "  - $cluster ArgoCD: http://localhost:$port"
    done
    
    return 0
}

# Print comprehensive status
print_comprehensive_status() {
    echo ""
    echo "🏢========================================================="
    echo "   📊 MULTI-CLUSTER GITOPS STATUS REPORT"
    echo "   🚧 DEV → 🧪 PRE → 🏭 PROD"
    echo "========================================================="
    
    # Overall cluster health
    check_all_clusters_status
    
    echo ""
    echo "🔗 SERVICE ACCESS POINTS:"
    for cluster in "${CLUSTERS[@]}"; do
        local port="${CLUSTER_PORTS[$cluster]}"
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            echo "   $cluster: http://localhost:$port (admin/***)"
        else
            echo "   $cluster: ❌ Not available (cluster stopped)"
        fi
    done
    
    echo ""
    echo "🛠️  MANAGEMENT COMMANDS:"
    echo "   Switch cluster:    kubectl config use-context <cluster-name>"
    echo "   Start all:         ./bootstrap-multi-cluster.sh"
    echo "   Stop all:          ./cleanup-multi-cluster.sh soft"
    echo "   Full status:       ./scripts/cluster-status.sh all"
    
    echo ""
    echo "🔄 PROMOTION PIPELINE STATUS:"
    local dev_healthy=$(minikube status --profile="$DEV_CLUSTER_PROFILE" 2>/dev/null | grep -q "Running" && echo "✅" || echo "❌")
    local pre_healthy=$(minikube status --profile="$PRE_CLUSTER_PROFILE" 2>/dev/null | grep -q "Running" && echo "✅" || echo "❌")
    local prod_healthy=$(minikube status --profile="$PROD_CLUSTER_PROFILE" 2>/dev/null | grep -q "Running" && echo "✅" || echo "❌")
    
    echo "   🚧 DEV:  $dev_healthy  Development environment"
    echo "   🧪 PRE:  $pre_healthy  Pre-production/UAT"  
    echo "   🏭 PROD: $prod_healthy Production environment"
    
    echo "========================================================="
}

# Main execution
main() {
    case "${1:-summary}" in
        "cluster")
            if [ -n "$2" ]; then
                check_cluster_detail "$2"
            else
                log_error "Please specify cluster name: $DEV_CLUSTER_PROFILE, $PRE_CLUSTER_PROFILE, or $PROD_CLUSTER_PROFILE"
                exit 1
            fi
            ;;
        "clusters"|"all-clusters")
            check_all_clusters_status
            ;;
        "argocd")
            check_all_argocd
            ;;
        "ports")
            check_port_forwards
            ;;
        "summary"|"")
            print_comprehensive_status
            ;;
        "all")
            check_all_clusters_status
            echo ""
            check_all_argocd
            echo ""
            check_port_forwards
            echo ""
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [clusters|cluster <name>|argocd|ports|summary|all|help]"
            echo ""
            echo "Commands:"
            echo "  clusters       - Check all clusters status"
            echo "  cluster <name> - Detailed status for specific cluster"
            echo "  argocd         - Check ArgoCD across all clusters"
            echo "  ports          - Check active port-forwards"
            echo "  summary        - Show comprehensive status (default)"
            echo "  all            - Run all checks"
            echo "  help           - Show this help message"
            echo ""
            echo "Available clusters: $DEV_CLUSTER_PROFILE, $PRE_CLUSTER_PROFILE, $PROD_CLUSTER_PROFILE"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"
