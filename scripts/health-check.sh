#!/bin/bash

# 🏢 Enterprise GitOps Health Check Script
# Comprehensive health monitoring for the GitOps infrastructure

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

# Health check functions
check_cluster_health() {
    echo "🎯 CLUSTER HEALTH"
    echo "================="
    
    # Check minikube status
    if minikube status --profile="$MINIKUBE_PROFILE" 2>/dev/null | grep -q "Running"; then
        log_success "Minikube cluster is running"
        
        # Set context
        kubectl config use-context "$MINIKUBE_PROFILE" >/dev/null 2>&1
        
        # Check nodes
        local ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep Ready | wc -l)
        local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        
        if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$ready_nodes" -gt 0 ]; then
            log_success "All nodes ready ($ready_nodes/$total_nodes)"
        else
            log_warning "Node issues detected ($ready_nodes/$total_nodes ready)"
        fi
        
        # Check cluster resources
        log_info "Cluster resources:"
        kubectl top nodes 2>/dev/null || log_warning "Metrics not available"
        
    else
        log_error "Minikube cluster is not running"
        echo "Start with: minikube start --profile=$MINIKUBE_PROFILE"
        return 1
    fi
    echo ""
}

check_argocd_health() {
    echo "🔄 ARGOCD HEALTH"
    echo "==============="
    
    if kubectl get namespace argocd 2>/dev/null >/dev/null; then
        # Check ArgoCD components
        local components=("argocd-server" "argocd-application-controller" "argocd-repo-server" "argocd-redis")
        local healthy_components=0
        
        for component in "${components[@]}"; do
            if kubectl get deployment "$component" -n argocd 2>/dev/null >/dev/null; then
                local ready=$(kubectl get deployment "$component" -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                local desired=$(kubectl get deployment "$component" -n argocd -o jsonpath='{.status.replicas}' 2>/dev/null || echo "1")
                
                if [ "$ready" = "$desired" ] && [ "$ready" != "0" ]; then
                    log_success "$component: $ready/$desired replicas ready"
                    ((healthy_components++))
                else
                    log_warning "$component: $ready/$desired replicas ready"
                fi
            else
                log_error "$component deployment not found"
            fi
        done
        
        if [ "$healthy_components" -eq "${#components[@]}" ]; then
            log_success "ArgoCD is fully operational"
        else
            log_warning "ArgoCD has issues ($healthy_components/${#components[@]} components healthy)"
        fi
    else
        log_error "ArgoCD namespace not found"
    fi
    echo ""
}

check_applications_health() {
    echo "📱 APPLICATION HEALTH"
    echo "===================="
    
    if kubectl get applications -n argocd 2>/dev/null >/dev/null; then
        local total_apps=$(kubectl get applications -n argocd --no-headers | wc -l)
        local synced_apps=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.status.sync.status}{"\n"}{end}' 2>/dev/null | grep -c "Synced" || echo "0")
        local healthy_apps=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.status.health.status}{"\n"}{end}' 2>/dev/null | grep -c "Healthy" || echo "0")
        
        log_info "Total applications: $total_apps"
        log_info "Synced applications: $synced_apps/$total_apps"
        log_info "Healthy applications: $healthy_apps/$total_apps"
        
        # Expected count validation
        if [ "$total_apps" -eq 18 ]; then
            log_success "Expected 18 applications detected"
        else
            log_warning "Expected 18 applications, found $total_apps"
        fi
        
        echo ""
        echo "📊 Application Status Details:"
        printf "%-30s %-15s %-15s\n" "APPLICATION" "SYNC STATUS" "HEALTH STATUS"
        printf "%-30s %-15s %-15s\n" "$(printf '%.30s' "------------------------------")" "$(printf '%.15s' "---------------")" "$(printf '%.15s' "---------------")"
        
        kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}' 2>/dev/null | \
        while IFS=$'\t' read -r name sync health; do
            printf "%-30s %-15s %-15s\n" "$name" "$sync" "$health"
        done
        
        if [ "$synced_apps" -eq "$total_apps" ] && [ "$healthy_apps" -eq "$total_apps" ] && [ "$total_apps" -eq 18 ]; then
            log_success "🎉 PERFECT STATE: All 18 applications are synced and healthy!"
        elif [ "$synced_apps" -eq "$total_apps" ] && [ "$healthy_apps" -eq "$total_apps" ]; then
            log_success "All applications are synced and healthy"
        else
            log_warning "Some applications need attention"
        fi
    else
        log_warning "No ArgoCD applications found"
    fi
    echo ""
}

check_infrastructure_services() {
    echo "🛠️  INFRASTRUCTURE SERVICES"
    echo "=========================="
    
    local services=(
        "monitoring:grafana:Grafana"
        "monitoring:prometheus-stack-kube-prom-prometheus:Prometheus"
        "kargo:kargo-api:Kargo"
        "jaeger:jaeger-query:Jaeger"
        "gitea:gitea-http:Gitea"
        "loki:loki-gateway:Loki"
        "minio:minio:MinIO"
        "argo-workflows:argo-workflows-server:Argo Workflows"
    )
    
    local healthy_services=0
    local total_services=${#services[@]}
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r namespace service display_name <<< "$service_info"
        
        if kubectl get namespace "$namespace" 2>/dev/null >/dev/null; then
            if kubectl get service "$service" -n "$namespace" 2>/dev/null >/dev/null; then
                # Check if there are pods backing this service
                local pod_count=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=${service%%-*}" --no-headers 2>/dev/null | wc -l)
                if [ "$pod_count" -gt 0 ]; then
                    local running_pods=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=${service%%-*}" --no-headers 2>/dev/null | grep Running | wc -l)
                    if [ "$running_pods" -gt 0 ]; then
                        log_success "$display_name: $running_pods/$pod_count pods running"
                        ((healthy_services++))
                    else
                        log_warning "$display_name: $running_pods/$pod_count pods running"
                    fi
                else
                    log_warning "$display_name: Service exists but no pods found"
                fi
            else
                log_warning "$display_name: Service not found in $namespace"
            fi
        else
            log_warning "$display_name: Namespace $namespace not found"
        fi
    done
    
    if [ "$healthy_services" -eq "$total_services" ]; then
        log_success "All infrastructure services are operational"
    else
        log_warning "Infrastructure services status: $healthy_services/$total_services operational"
    fi
    echo ""
}

check_resource_usage() {
    echo "📊 RESOURCE USAGE"
    echo "================"
    
    # Node resources
    log_info "Node resource usage:"
    kubectl top nodes 2>/dev/null || log_warning "Node metrics not available"
    
    echo ""
    log_info "High resource consuming pods:"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -10 || log_warning "Pod metrics not available"
    
    echo ""
    log_info "Cluster storage usage:"
    kubectl get pv 2>/dev/null | grep -v "STATUS" || log_info "No persistent volumes found"
    echo ""
}

check_port_forwards() {
    echo "🌐 PORT-FORWARD STATUS"
    echo "====================="
    
    local pf_count=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
    
    if [ "$pf_count" -gt 0 ]; then
        log_success "$pf_count port-forward processes active"
        
        # Show active port-forwards
        ps aux | grep "kubectl port-forward" | grep -v grep | while read -r line; do
            echo "  $line"
        done
    else
        log_warning "No port-forwards active"
        echo "Run: ./scripts/setup-port-forwards.sh"
    fi
    echo ""
}

generate_health_summary() {
    echo "📋 HEALTH SUMMARY"
    echo "================"
    
    # Overall status
    local issues=0
    
    if ! minikube status --profile="$MINIKUBE_PROFILE" 2>/dev/null | grep -q "Running"; then
        ((issues++))
    fi
    
    if ! kubectl get deployment argocd-server -n argocd 2>/dev/null >/dev/null; then
        ((issues++))
    fi
    
    local total_apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    local healthy_apps=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.status.health.status}{"\n"}{end}' 2>/dev/null | grep -c "Healthy" || echo "0")
    
    if [ "$total_apps" -gt 0 ] && [ "$healthy_apps" -lt "$total_apps" ]; then
        ((issues++))
    fi
    
    if [ "$issues" -eq 0 ]; then
        log_success "✨ Enterprise GitOps infrastructure is fully operational!"
        echo "🏢 Ready for production workloads and promotional workflows"
    elif [ "$issues" -eq 1 ]; then
        log_warning "⚠️  Minor issues detected - infrastructure is mostly operational"
    else
        log_error "❌ Multiple issues detected - infrastructure needs attention"
    fi
    
    echo ""
    echo "🔧 Quick fixes:"
    echo "  Restart cluster:     minikube start --profile=$MINIKUBE_PROFILE"
    echo "  Restart port-fwds:   ./scripts/setup-port-forwards.sh"
    echo "  Sync applications:   kubectl patch application gitops-infra-apps -n argocd --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}'"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "🏢================================================"
    echo "   🔍 ENTERPRISE GITOPS HEALTH CHECK"
    echo "================================================"
    echo ""
    
    case "${1:-full}" in
        "cluster")
            check_cluster_health
            ;;
        "argocd")
            check_argocd_health
            ;;
        "apps")
            check_applications_health
            ;;
        "services")
            check_infrastructure_services
            ;;
        "resources")
            check_resource_usage
            ;;
        "ports")
            check_port_forwards
            ;;
        "full"|"")
            check_cluster_health
            check_argocd_health
            check_applications_health
            check_infrastructure_services
            check_resource_usage
            check_port_forwards
            generate_health_summary
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [full|cluster|argocd|apps|services|resources|ports|help]"
            echo ""
            echo "Commands:"
            echo "  full      - Complete health check (default)"
            echo "  cluster   - Check cluster health only"
            echo "  argocd    - Check ArgoCD health only"
            echo "  apps      - Check application status only"
            echo "  services  - Check infrastructure services only"
            echo "  resources - Check resource usage only"
            echo "  ports     - Check port-forward status only"
            echo "  help      - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C
trap 'log_warning "Health check interrupted"; exit 1' INT

main "$@"
