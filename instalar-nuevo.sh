#!/bin/bash

# ============================================================================
# INSTALADOR PRINCIPAL MODULAR - GitOps en Español Infrastructure v3.0.0
# ============================================================================
# Orquestador mínimo y modular para infraestructura GitOps
# Principios: DRY, Single Responsibility, Separación de responsabilidades
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar PROJECT_ROOT automáticamente
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

# Cargar sistema de autocontención
if [[ -f "$PROJECT_ROOT/scripts/comun/bootstrap.sh" ]]; then
    # shellcheck source=scripts/comun/bootstrap.sh
    source "$PROJECT_ROOT/scripts/comun/bootstrap.sh"
else
    echo "❌ Error: Sistema de autocontención no encontrado" >&2
    echo "   Archivo requerido: scripts/comun/bootstrap.sh" >&2
    exit 1
fi

# ============================================================================
# FUNCIONES MÍNIMAS DEL ORQUESTADOR
# ============================================================================

# Mostrar ayuda (delegada a helper)
mostrar_ayuda() {
    if [[ -f "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh" ]]; then
        source "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh"
        mostrar_ayuda_completa
    else
        echo "GitOps en Español Infrastructure v3.0.0"
        echo "Uso: ./instalar.sh [OPCIONES]"
        echo "Ver documentación completa en README.md"
    fi
}

# Función principal (solo orquestación)
main() {
    # Procesar argumentos
    local comando="${1:-completo}"
    shift || true
    
    case "$comando" in
        --ayuda|--help|-h)
            mostrar_ayuda
            exit 0
            ;;
        --version)
            echo "GitOps en Español Infrastructure v$GITOPS_VERSION"
            exit 0
            ;;
        fase-*)
            # Extraer número de fase
            local fase_num="${comando#fase-}"
            ejecutar_fase_individual "$fase_num" "$@"
            ;;
        completo|"")
            ejecutar_proceso_completo "$@"
            ;;
        *)
            log_error "Comando desconocido: $comando"
            mostrar_ayuda
            exit 1
            ;;
    esac
}

# Ejecutar fase individual (delegada a helper)
ejecutar_fase_individual() {
    local fase="$1"
    shift || true
    
    # Cargar helper de instalación
    source "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh"
    
    # Delegar ejecución
    ejecutar_fase_individual_impl "$fase" "$@"
}

# Ejecutar proceso completo (delegada a helper)
ejecutar_proceso_completo() {
    # Cargar helper de instalación
    source "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh"
    
    # Delegar ejecución
    ejecutar_proceso_completo_impl "$@"
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Ejecutar función principal con manejo de errores
if ! main "$@"; then
    log_error "Instalación falló"
    exit 1
fi
