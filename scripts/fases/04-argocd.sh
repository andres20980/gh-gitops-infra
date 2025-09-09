#!/bin/bash

# ============================================================================
# FASE 4: INSTALACIÓN ARGOCD
# ============================================================================
# Instalación robusta de ArgoCD con verificación de contexto y timeouts
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


# ============================================================================
# FASE 4: ARGOCD
# ============================================================================

main() {
    log_section "🚀 FASE 4: Instalación ArgoCD"
    
    # 1. Verificar cluster disponible
    log_info "🔍 Verificando cluster..."
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    
    # 2. Instalar ArgoCD
    log_info "📦 Configurando ArgoCD..."
    if ! check_argocd_exists; then
        install_argocd
        setup_argocd_service
        wait_argocd_ready
        setup_argocd_cli
    else
        log_success "✅ ArgoCD ya está instalado y funcionando"
    fi
    
    # 3. Mostrar información de acceso
    show_argocd_access
    show_argocd_cli_status
    
    log_success "✅ Fase 4 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

