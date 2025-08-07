#!/bin/bash

# ============================================================================
# FASE 1: GESTIÓN INTELIGENTE DE PERMISOS (OPTIMIZADA)
# ============================================================================
# Gestión automática de permisos - Modular, Best Practices, Líneas minimizadas
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

# Cargar helper de permisos
[[ -f "$SCRIPT_DIR/../comun/helpers/permisos-helper.sh" ]] && source "$SCRIPT_DIR/../comun/helpers/permisos-helper.sh" || {
    log_error "❌ Helper de permisos no encontrado"; exit 1
}

# ============================================================================
# FUNCIONES OPTIMIZADAS
# ============================================================================

# Diagnóstico rápido del contexto actual
diagnosticar_contexto() {
    log_info "👤 Usuario: $(whoami) | UID: $EUID"
    log_info "🔑 Contexto: $([[ "$EUID" -eq 0 ]] && echo "root" || echo "usuario normal")"
    
    if command -v sudo >/dev/null 2>&1; then
        log_info "✅ sudo: $(verificar_sudo && echo "disponible (sin contraseña)" || echo "disponible (requiere contraseña)")"
    else
        log_warning "⚠️ sudo: no disponible"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL OPTIMIZADA
# ============================================================================

fase_01_permisos() {
    mostrar_info_fase "01" "🔐 FASE 1: Gestión Inteligente de Permisos"
    
    # Diagnóstico rápido
    diagnosticar_contexto
    
    # Gestión automática usando helper
    gestionar_permisos_automatico "permisos"
    
    log_success "✅ Fase 1 completada: Permisos verificados"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_01_permisos "$@"
fi
