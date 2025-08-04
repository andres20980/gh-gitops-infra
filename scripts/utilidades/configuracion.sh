#!/bin/bash

# ============================================================================
# UTILIDAD DE CONFIGURACIÓN - Configuración de entorno y port-forwards
# ============================================================================
# Consolidación de configurar-entorno.sh y configurar-port-forwards.sh
# Uso: ./scripts/utilidades/configuracion.sh [entorno|port-forwards|todo]
# ============================================================================

set -euo pipefail

# Directorio base del proyecto
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly BIBLIOTECAS_DIR="$SCRIPTS_DIR/bibliotecas"

# Cargar bibliotecas esenciales
for lib in "base" "logging"; do
    lib_path="$BIBLIOTECAS_DIR/${lib}.sh"
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
    else
        echo "Error: Biblioteca $lib no encontrada" >&2
        exit 1
    fi
done

# ============================================================================
# CONFIGURACIÓN DE ENTORNO
# ============================================================================

configurar_entorno() {
    log_section "🔧 Configuración de Entorno GitOps"
    
    log_info "Configurando permisos y estructura base..."
    
    # Hacer ejecutables todos los scripts
    find "$SCRIPTS_DIR" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$PROJECT_ROOT/instalador.sh"
    
    # Crear directorios de logs si no existen
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Verificar herramientas básicas
    local tools=("docker" "kubectl" "helm")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool: ✅ Instalado"
        else
            log_warning "$tool: ⚠️ No instalado"
        fi
    done
    
    log_success "✅ Entorno configurado correctamente"
}

# ============================================================================
# CONFIGURACIÓN DE PORT-FORWARDS
# ============================================================================

configurar_port_forwards() {
    log_section "🌐 Configuración de Port-Forwards"
    
    log_info "Configurando accesos a servicios GitOps..."
    
    # Verificar si el cluster existe
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ Cluster de Kubernetes no accesible"
        return 1
    fi
    
    # ArgoCD UI
    log_info "Configurando port-forward para ArgoCD..."
    pkill -f "kubectl.*port-forward.*argocd" || true
    kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
    log_success "ArgoCD UI: https://localhost:8080"
    
    # Grafana
    if kubectl get svc grafana -n monitoring >/dev/null 2>&1; then
        log_info "Configurando port-forward para Grafana..."
        pkill -f "kubectl.*port-forward.*grafana" || true
        kubectl port-forward svc/grafana -n monitoring 3000:80 >/dev/null 2>&1 &
        log_success "Grafana: http://localhost:3000"
    fi
    
    # Prometheus
    if kubectl get svc prometheus-server -n monitoring >/dev/null 2>&1; then
        log_info "Configurando port-forward para Prometheus..."
        pkill -f "kubectl.*port-forward.*prometheus" || true
        kubectl port-forward svc/prometheus-server -n monitoring 9090:80 >/dev/null 2>&1 &
        log_success "Prometheus: http://localhost:9090"
    fi
    
    log_success "✅ Port-forwards configurados"
    log_info "💡 Para detener: pkill -f 'kubectl.*port-forward'"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-todo}"
    
    case "$action" in
        "entorno")
            configurar_entorno
            ;;
        "port-forwards")
            configurar_port_forwards
            ;;
        "todo")
            configurar_entorno
            configurar_port_forwards
            ;;
        *)
            log_error "Uso: $0 [entorno|port-forwards|todo]"
            exit 1
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
