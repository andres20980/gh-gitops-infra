#!/bin/bash

# ============================================================================
# FASE 5: Instalación de Herramientas GitOps
# ============================================================================
# Despliega todas las herramientas GitOps usando el sistema dinámico v3.0.0
# Principios: DRY - Delegación total a gitops-helper.sh
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN Y DEPENDENCIAS
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar sistema de autocontención
if [[ -f "$SCRIPT_DIR/../comun/bootstrap.sh" ]]; then
    # shellcheck source=../comun/bootstrap.sh
    source "$SCRIPT_DIR/../comun/bootstrap.sh"
else
    echo "❌ Error: Sistema de autocontención no encontrado" >&2
    exit 1
fi

# Cargar helper especializado de GitOps
if [[ -f "$SCRIPT_DIR/../comun/helpers/gitops-helper.sh" ]]; then
    # shellcheck source=../comun/helpers/gitops-helper.sh
    source "$SCRIPT_DIR/../comun/helpers/gitops-helper.sh"
else
    log_error "❌ GitOps helper no encontrado: gitops-helper.sh"
    exit 1
fi

# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE
# ============================================================================

fase_05_herramientas() {
    log_info "🛠️ FASE 5: Instalación de Herramientas GitOps"
    log_info "═══════════════════════════════════════════════"
    log_info "🎯 Sistema dinámico v3.0.0 con autodescubrimiento"
    log_info "🎯 Configuraciones optimizadas para desarrollo"
    log_info "🎯 Preparadas para multi-cluster (DEV, PRE, PRO)"
    
    # Verificar prerequisites
    if [[ "$EUID" -eq 0 ]]; then
        log_error "❌ Esta fase no debe ejecutarse como root"
        return 1
    fi
    
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD no está instalado - ejecuta Fase 4 primero"
        return 1
    fi
    
    # Delegar todo el trabajo al gitops-helper especializado
    log_info "�� Delegando a sistema dinámico GitOps..."
    
    if ! ejecutar_optimizacion_gitops; then
        log_error "❌ Falló la instalación de herramientas GitOps"
        return 1
    fi
    
    log_success "✅ Fase 5 completada: Herramientas GitOps desplegadas y sincronizadas"
    log_info "🌐 Todas las herramientas accesibles vía localhost"
    log_info "🎯 Próximo paso: Instalar aplicaciones custom (Fase 6)"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_05_herramientas "$@"
fi
