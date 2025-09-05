#!/bin/bash

# ============================================================================
# FASE 02 DRY: GESTIÓN DE DEPENDENCIAS DEL SISTEMA
# ============================================================================
# Responsabilidad: Orquestación de instalación de dependencias usando framework DRY
# Principios: Single Responsibility, DRY, Delegation Pattern
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN DRY
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar sistema DRY
if [[ -f "$SCRIPT_DIR/../comun/bootstrap.sh" ]]; then
    # shellcheck source=../comun/bootstrap.sh
    source "$SCRIPT_DIR/../comun/bootstrap.sh"
else
    echo "❌ ERROR: Sistema DRY no encontrado" >&2
    exit 1
fi

# ============================================================================
# CONFIGURACIÓN DE FASE
# ============================================================================

readonly FASE_NUMERO="02"
readonly FASE_NOMBRE="Gestión de Dependencias del Sistema"
readonly FASE_ICONO="📦"

# ============================================================================
# FUNCIONES DE VALIDACIÓN DRY
# ============================================================================

# Verificar prerequisitos para Fase 02
verificar_prerequisitos_fase02() {
    log_info "🔍 Verificando prerequisitos para Fase 02..."
    
    # Verificar conectividad
    if ! check_internet_connectivity; then
        return 1
    fi
    
    # Verificar privilegios sudo
    if ! check_sudo_privileges; then
        return 1
    fi
    
    log_success "✅ Prerequisitos verificados"
    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL DRY
# ============================================================================

fase_02_dependencias() {
    # Banner informativo
    mostrar_info_fase "$FASE_NUMERO" "$FASE_ICONO FASE $FASE_NUMERO: $FASE_NOMBRE"
    
    log_info "🎯 Instalación automatizada de herramientas base"
    log_info "🎯 Docker, kubectl, minikube, helm, git"
    log_info "🎯 Usando framework DRY de instalación"
    
    # Verificar prerequisitos
    if ! verificar_prerequisitos_fase02; then
        log_error "❌ Prerequisitos no cumplidos"
        return 1
    fi
    
    # Determinar modo de operación
    if skip_deps; then
        log_info "⏭️ Modo verificación (--skip-deps activado)"
        
        if check_system_dependencies; then
            log_success "✅ Fase $FASE_NUMERO completada: Dependencias verificadas"
            show_tools_summary
            return 0
        else
            log_error "❌ Algunas dependencias no están disponibles"
            log_info "💡 Ejecuta sin --skip-deps para instalar automáticamente"
            return 1
        fi
    else
        log_info "📥 Modo instalación completa usando framework DRY"
        
        # Instalar dependencias usando framework DRY
        if install_system_dependencies; then
            log_success "✅ Fase $FASE_NUMERO completada: Dependencias instaladas"
            return 0
        else
            log_error "❌ Fase $FASE_NUMERO falló: Error en instalación"
            return 1
        fi
    fi
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_02_dependencias "$@"
fi
