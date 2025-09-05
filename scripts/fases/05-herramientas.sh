#!/bin/bash

# ============================================================================
# FASE 5: Instalación de Herramientas GitOps
# ============================================================================
# Despliega todas las herramientas GitOps usando librerías DRY
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail

# ============================================================================
# CARGA DE LIBRERÍAS DRY
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar librerías DRY consolidadas
source "$SCRIPT_DIR/../comun/base.sh"

# ============================================================================
# FASE 5: HERRAMIENTAS GITOPS
# ============================================================================

main() {
    log_section "🛠️ FASE 5: Instalación Herramientas GitOps"
    
    # 1. Verificar prerrequisitos
    log_info "🔍 Verificando prerrequisitos..."
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    
    if ! check_argocd_exists; then
        log_error "❌ ArgoCD no está instalado (ejecutar Fase 4 primero)"
        return 1
    fi
    
    # 2. Instalar herramientas GitOps
    log_info "🚀 Instalando herramientas GitOps..."
    install_all_gitops_tools
    
    # 3. Mostrar resumen
    show_gitops_summary
    
    log_success "✅ Fase 5 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
