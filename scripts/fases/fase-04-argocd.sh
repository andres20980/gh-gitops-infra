#!/bin/bash

# ============================================================================
# FASE 4: INSTALACIÓN ARGOCD (OPTIMIZADA)
# ============================================================================
# Instalación robusta de ArgoCD con verificación de contexto y timeouts
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN Y MÓDULOS
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar autocontención
[[ -f "$SCRIPT_DIR/../comun/autocontener.sh" ]] && source "$SCRIPT_DIR/../comun/autocontener.sh" || {
    echo "❌ Error: Módulo de autocontención no encontrado" >&2; exit 1
}

# Cargar helper de ArgoCD
[[ -f "$SCRIPT_DIR/../comun/helpers/argocd-helper.sh" ]] && source "$SCRIPT_DIR/../comun/helpers/argocd-helper.sh" || {
    log_error "❌ Helper de ArgoCD no encontrado"; exit 1
}

# ============================================================================
# FUNCIONES OPTIMIZADAS
# ============================================================================

# Verificación previa completa
verificar_prerequisitos() {
    # Verificar que no estamos como root
    [[ "$EUID" -eq 0 ]] && {
        log_error "❌ Esta fase no debe ejecutarse como root"
        log_info "💡 ArgoCD debe instalarse con usuario normal"
        return 1
    }
    
    # Verificar y corregir contexto de kubectl
    verificar_contexto_kubectl "$CLUSTER_DEV_NAME"
    
    # Verificar conectividad al cluster
    verificar_conectividad_cluster
    
    # Verificar que estamos en el cluster correcto
    verificar_cluster_correcto "$CLUSTER_DEV_NAME"
    
    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL OPTIMIZADA
# ============================================================================

fase_04_argocd() {
    mostrar_info_fase "04" "🔄 FASE 4: Instalar ArgoCD"
    
    # Verificaciones previas
    verificar_prerequisitos || return 1
    
    # Proceso principal
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría instalación de ArgoCD"
    else
        # Instalación
        instalar_argocd_robusto || return 1
        
        # Configuración de acceso
        configurar_acceso_argocd || return 1
        
        # Espera inteligente
        esperar_argocd_listo 180 || return 1  # 3 minutos máximo
        
        # Información de acceso
        obtener_info_acceso "$CLUSTER_DEV_NAME"
    fi
    
    log_success "✅ Fase 4 completada: ArgoCD instalado y configurado"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_04_argocd "$@"
fi
