#!/bin/bash

# ============================================================================
# FASE 2: VERIFICACIÓN Y ACTUALIZACIÓN DE DEPENDENCIAS
# ============================================================================
# Verifica e instala todas las dependencias necesarias del sistema
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
        install_all_dependencies
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
