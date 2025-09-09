#!/bin/bash

# ============================================================================
# FASE 2: VERIFICACIÓN Y ACTUALIZACIÓN DE DEPENDENCIAS
# ============================================================================
# Verifica e instala todas las dependencias necesarias del sistema
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


# ============================================================================
# FASE 2: DEPENDENCIAS
# ============================================================================

main() {
    log_section "📦 FASE 2: Verificación y Actualización de Dependencias"
    
    # Verificar dependencias actuales
    if check_all_dependencies; then
        log_success "✅ Todas las dependencias están instaladas"
        show_dependencies_summary
    else
        log_info "🔧 Instalando dependencias faltantes..."
        if ! install_all_dependencies; then
            log_error "❌ No fue posible instalar todas las dependencias"
            return 1
        fi
        # Verificación final
        if ! check_all_dependencies; then
            log_error "❌ Dependencias aún incompletas tras la instalación"
            return 1
        fi
        show_dependencies_summary
    fi
    
    log_success "✅ Fase 2 completada exitosamente"
}


# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
