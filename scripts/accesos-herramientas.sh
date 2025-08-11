#!/bin/bash

# ============================================================================
# SCRIPT DE ACCESOS A HERRAMIENTAS GITOPS
# ============================================================================
# Configura port-forwards para acceder a todas las herramientas GitOps
# Uso: ./scripts/accesos-herramientas.sh [start|stop|status|list]
# ============================================================================

set -euo pipefail

# Cargar funciones base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/comun/base.sh"

# Configuración de herramientas
declare -A HERRAMIENTAS_PUERTOS=(
    ["argocd"]="8080:443"
    ["grafana"]="8081:80" 
    ["prometheus"]="8082:9090"
    ["alertmanager"]="8083:9093"
    ["jaeger"]="8084:16686"
    ["kargo"]="8085:80"
    ["loki"]="8086:3100"
    ["minio"]="8087:9000"
    ["gitea"]="8088:3000"
    ["argo-workflows"]="8089:2746"
    ["argo-events"]="8090:80"
    ["argo-rollouts"]="8091:80"
)

declare -A HERRAMIENTAS_NAMESPACES=(
    ["argocd"]="argocd"
    ["grafana"]="monitoring"
    ["prometheus"]="monitoring"
    ["alertmanager"]="monitoring"
    ["jaeger"]="jaeger"
    ["kargo"]="kargo"
    ["loki"]="loki"
    ["minio"]="minio"
    ["gitea"]="gitea"
    ["argo-workflows"]="argo-workflows"
    ["argo-events"]="argo-events"
    ["argo-rollouts"]="argo-rollouts"
)

declare -A HERRAMIENTAS_SERVICIOS=(
    ["argocd"]="argocd-server"
    ["grafana"]="prometheus-stack-grafana"
    ["prometheus"]="prometheus-stack-kube-prom-prometheus"
    ["alertmanager"]="prometheus-stack-kube-prom-alertmanager"
    ["jaeger"]="jaeger-query"
    ["kargo"]="kargo-api"
    ["loki"]="loki"
    ["minio"]="minio"
    ["gitea"]="gitea-http"
    ["argo-workflows"]="argo-workflows-server"
    ["argo-events"]="argo-events-webhook"
    ["argo-rollouts"]="argo-rollouts-dashboard"
)

# Función para iniciar port-forwards
start_port_forwards() {
    log_info "🚀 Iniciando port-forwards para herramientas GitOps..."
    
    for herramienta in "${!HERRAMIENTAS_PUERTOS[@]}"; do
        local namespace="${HERRAMIENTAS_NAMESPACES[$herramienta]}"
        local servicio="${HERRAMIENTAS_SERVICIOS[$herramienta]}"
        local puerto="${HERRAMIENTAS_PUERTOS[$herramienta]}"
        local puerto_local="${puerto%:*}"
        local puerto_remoto="${puerto#*:}"
        
        # Verificar si el namespace y servicio existen
        if kubectl get namespace "$namespace" >/dev/null 2>&1 && \
           kubectl get service "$servicio" -n "$namespace" >/dev/null 2>&1; then
            
            # Verificar si ya hay un port-forward activo
            if ! lsof -i ":$puerto_local" >/dev/null 2>&1; then
                log_info "  🔗 $herramienta: localhost:$puerto_local"
                kubectl port-forward -n "$namespace" "service/$servicio" "$puerto" >/dev/null 2>&1 &
                sleep 1
            else
                log_warning "  ⚠️ $herramienta: puerto $puerto_local ya en uso"
            fi
        else
            log_warning "  ❌ $herramienta: servicio no disponible ($namespace/$servicio)"
        fi
    done
    
    log_success "✅ Port-forwards configurados (en background)"
}

# Función para parar port-forwards
stop_port_forwards() {
    log_info "🛑 Deteniendo port-forwards de herramientas GitOps..."
    
    for herramienta in "${!HERRAMIENTAS_PUERTOS[@]}"; do
        local puerto_local="${HERRAMIENTAS_PUERTOS[$herramienta]%:*}"
        
        local pid
        pid=$(lsof -t -i ":$puerto_local" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            log_info "  🛑 $herramienta: puerto $puerto_local liberado"
        fi
    done
    
    log_success "✅ Todos los port-forwards detenidos"
}

# Función para mostrar estado
show_status() {
    log_info "📊 Estado de accesos a herramientas GitOps:"
    echo
    
    for herramienta in "${!HERRAMIENTAS_PUERTOS[@]}"; do
        local puerto_local="${HERRAMIENTAS_PUERTOS[$herramienta]%:*}"
        
        if lsof -i ":$puerto_local" >/dev/null 2>&1; then
            echo "  ✅ $herramienta: http://localhost:$puerto_local"
        else
            echo "  ❌ $herramienta: no disponible (puerto $puerto_local)"
        fi
    done
    echo
}

# Función para listar todas las herramientas
list_tools() {
    log_info "📋 Herramientas GitOps disponibles:"
    echo
    echo "🔧 INFRAESTRUCTURA BÁSICA:"
    echo "  • ArgoCD (GitOps)          : http://localhost:8080"
    echo "  • Cert-Manager (TLS)       : Automático (sin UI)"
    echo "  • Ingress-NGINX (Ingress)  : Automático (sin UI específica)"
    echo
    echo "� OBSERVABILIDAD Y MONITOREO:"
    echo "  • Grafana (Dashboards)     : http://localhost:8081"
    echo "  • Prometheus (Métricas)    : http://localhost:8082"
    echo "  • AlertManager (Alertas)   : http://localhost:8083"
    echo "  • Jaeger (Tracing)         : http://localhost:8084"
    echo "  • Loki (Logs)              : http://localhost:8086"
    echo
    echo "🚀 HERRAMIENTAS GITOPS AVANZADAS:"
    echo "  • Argo Workflows (CI/CD)   : http://localhost:8089"
    echo "  • Argo Events (Eventos)    : http://localhost:8090"
    echo "  • Argo Rollouts (Deploy)   : http://localhost:8091"
    echo "  • Kargo (Promoción)        : http://localhost:8085"
    echo
    echo "�📦 ALMACENAMIENTO Y CÓDIGO:"
    echo "  • MinIO (S3 Storage)       : http://localhost:8087"
    echo "  • Gitea (Git Server)       : http://localhost:8088"
    echo
}

# Función principal
main() {
    local action="${1:-start}"
    
    case "$action" in
        "start")
            start_port_forwards
            show_status
            ;;
        "stop")
            stop_port_forwards
            ;;
        "status")
            show_status
            ;;
        "list")
            list_tools
            ;;
        *)
            echo "Uso: $0 [start|stop|status|list]"
            echo "  start  - Iniciar port-forwards"
            echo "  stop   - Detener port-forwards" 
            echo "  status - Mostrar estado actual"
            echo "  list   - Listar todas las herramientas"
            exit 1
            ;;
    esac
}

main "$@"
