#!/bin/bash

# ============================================================================
# UTILIDAD DE MANTENIMIENTO - Gestión y mantenimiento del sistema GitOps
# ============================================================================
# Consolidación de scripts de mantenimiento y sincronización
# Uso: ./scripts/utilidades/mantenimiento.sh [sync|charts|deploy|todo]
# ============================================================================

set -euo pipefail

# Directorio base del proyecto
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly BIBLIOTECAS_DIR="$SCRIPTS_DIR/bibliotecas"
readonly HERRAMIENTAS_DIR="$PROJECT_ROOT/herramientas-gitops"

# Cargar bibliotecas esenciales
for lib in "base" "logging" "versiones"; do
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
# SINCRONIZACIÓN DE APLICACIONES
# ============================================================================

sincronizar_aplicaciones() {
    log_section "🔄 Sincronización de Aplicaciones ArgoCD"
    
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD no está instalado"
        return 1
    fi
    
    log_info "Sincronizando todas las aplicaciones ArgoCD..."
    
    # Obtener lista de aplicaciones
    local apps
    if ! apps=$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); then
        log_error "❌ No se pueden obtener las aplicaciones"
        return 1
    fi
    
    if [[ -z "$apps" ]]; then
        log_warning "⚠️ No hay aplicaciones ArgoCD desplegadas"
        return 0
    fi
    
    # Sincronizar cada aplicación
    for app in $apps; do
        log_info "Sincronizando $app..."
        if kubectl patch application "$app" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' >/dev/null 2>&1; then
            log_success "✅ $app sincronizada"
        else
            log_warning "⚠️ Error sincronizando $app"
        fi
    done
    
    log_success "✅ Sincronización completada"
}

# ============================================================================
# CORRECCIÓN DE VERSIONES DE CHARTS
# ============================================================================

corregir_versiones_charts() {
    log_section "📊 Verificación y Corrección de Versiones de Charts"
    
    if [[ ! -d "$HERRAMIENTAS_DIR" ]]; then
        log_error "❌ Directorio herramientas-gitops no encontrado"
        return 1
    fi
    
    log_info "Verificando versiones en archivos YAML..."
    
    # Verificar herramientas principales
    local herramientas=("argo-rollouts" "argo-workflows" "argo-events" "grafana" "loki")
    
    for herramienta in "${herramientas[@]}"; do
        local archivo="$HERRAMIENTAS_DIR/${herramienta}.yaml"
        if [[ -f "$archivo" ]]; then
            local version
            version=$(grep "targetRevision:" "$archivo" | awk '{print $2}' | tr -d '"' || echo "N/A")
            log_check "$herramienta: $version" "info"
        else
            log_check "$herramienta: ❌ Archivo no encontrado" "warning"
        fi
    done
    
    log_info "💡 Para aplicar cambios: kubectl apply -f herramientas-gitops/"
    log_success "✅ Verificación de versiones completada"
}

# ============================================================================
# DESPLIEGUE CON DEPENDENCIAS
# ============================================================================

desplegar_con_dependencias() {
    log_section "🚀 Despliegue Ordenado con Dependencias"
    
    log_info "Desplegando aplicaciones respetando dependencias..."
    
    # Orden de despliegue respetando dependencias
    local orden_despliegue=(
        "cert-manager"
        "external-secrets" 
        "ingress-nginx"
        "prometheus-stack"
        "grafana"
        "loki"
        "jaeger"
        "argo-rollouts"
        "argo-workflows"
        "argo-events"
        "kargo"
        "gitea"
        "minio"
    )
    
    for app in "${orden_despliegue[@]}"; do
        local archivo="$HERRAMIENTAS_DIR/${app}.yaml"
        if [[ -f "$archivo" ]]; then
            log_info "Desplegando $app..."
            if kubectl apply -f "$archivo" >/dev/null 2>&1; then
                log_success "✅ $app desplegado"
                # Esperar un momento entre despliegues
                sleep 2
            else
                log_warning "⚠️ Error desplegando $app"
            fi
        else
            log_warning "⚠️ $app: archivo no encontrado"
        fi
    done
    
    log_success "✅ Despliegue con dependencias completado"
}

# ============================================================================
# OPERACIÓN COMPLETA DE MANTENIMIENTO
# ============================================================================

mantenimiento_completo() {
    log_section "🔧 Mantenimiento Completo del Sistema GitOps"
    
    corregir_versiones_charts
    echo ""
    desplegar_con_dependencias
    echo ""
    sincronizar_aplicaciones
    
    log_success "✅ Mantenimiento completo finalizado"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-todo}"
    
    case "$action" in
        "sync"|"sincronizar")
            sincronizar_aplicaciones
            ;;
        "charts"|"versiones")
            corregir_versiones_charts
            ;;
        "deploy"|"desplegar")
            desplegar_con_dependencias
            ;;
        "todo"|"completo")
            mantenimiento_completo
            ;;
        *)
            log_error "Uso: $0 [sync|charts|deploy|todo]"
            log_info "  sync     - Sincronizar aplicaciones ArgoCD"
            log_info "  charts   - Verificar versiones de charts"
            log_info "  deploy   - Desplegar con dependencias"
            log_info "  todo     - Ejecutar mantenimiento completo"
            exit 1
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
