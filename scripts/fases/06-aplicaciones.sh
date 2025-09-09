#!/bin/bash

# ============================================================================
# FASE 6: DESPLIEGUE DE APLICACIONES
# ============================================================================
# Despliega aplicaciones demo usando ArgoCD
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


# ============================================================================
# CONFIGURACIÓN DE APLICACIONES
# ============================================================================

# Usar la raíz del proyecto detectada por el sistema DRY
readonly APLICACIONES_DIR="${PROJECT_ROOT}/aplicaciones"

# ============================================================================
# FASE 6: APLICACIONES
# ============================================================================

main() {
    log_section "📱 FASE 6: Despliegue de Aplicaciones"
    
    # 1. Verificar prerrequisitos
    log_info "🔍 Verificando prerrequisitos..."
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    
    if ! check_argocd_exists; then
        log_error "❌ ArgoCD no está instalado"
        return 1
    fi
    
    # 2. Desplegar ApplicationSets
    log_info "🚀 Desplegando ApplicationSets..."
    
    if [[ -f "$APLICACIONES_DIR/conjunto-aplicaciones.yaml" ]]; then
        kubectl apply -f "$APLICACIONES_DIR/conjunto-aplicaciones.yaml"
        log_success "✅ ApplicationSet principal desplegado"
    else
        log_warning "⚠️ ApplicationSet no encontrado en $APLICACIONES_DIR"
    fi
    
    # 3. Verificar aplicaciones
    log_info "📋 Verificando aplicaciones..."
    sleep 10
    
    local apps_count
    apps_count=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    log_info "📱 Aplicaciones detectadas: $apps_count"
    
    if [[ $apps_count -gt 0 ]]; then
        kubectl get applications -n argocd
    fi
    
    log_success "✅ Fase 6 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
