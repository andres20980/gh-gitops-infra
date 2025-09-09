#!/bin/bash

# ============================================================================
# BOOTSTRAP DRY - Sistema de Autocontención Ultra-Modular
# ============================================================================
# Responsabilidad: Punto de entrada único para sistema DRY
# Principios: Single Point of Entry, Zero Duplication, Auto-discovery
# ============================================================================

set -euo pipefail

# ============================================================================
# DETECCIÓN INTELIGENTE DE PROJECT_ROOT
# ============================================================================

# Solo detectar PROJECT_ROOT si no está definido
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    # Buscar hacia arriba hasta encontrar instalar.sh
    search_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    while [[ "$search_dir" != "/" ]]; do
        if [[ -f "$search_dir/instalar.sh" ]]; then
            export PROJECT_ROOT="$search_dir"
            break
        fi
        search_dir="$(dirname "$search_dir")"
    done
    
    # Verificar que se encontró
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        echo "❌ ERROR: No se pudo detectar PROJECT_ROOT" >&2
        echo "   Asegúrate de estar en el proyecto gh-gitops-infra" >&2
        exit 1
    fi
fi

# ============================================================================
# CARGA DEL AUTOLOADER DRY
# ============================================================================

# Cargar el autoloader inteligente (que carga todo lo demás)
readonly AUTOLOADER_PATH="$PROJECT_ROOT/scripts/comun/core/cargador-automatico.sh"

if [[ -f "$AUTOLOADER_PATH" ]]; then
    # shellcheck source=core/cargador-automatico.sh
    source "$AUTOLOADER_PATH"
else
    echo "❌ ERROR: Autoloader DRY no encontrado" >&2
    echo "   Ruta esperada: $AUTOLOADER_PATH" >&2
    exit 1
fi

# ============================================================================
# VERIFICACIÓN DE SISTEMA DRY
# ============================================================================

# Verificar que el sistema DRY está correctamente inicializado
if [[ "${DRY_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
    echo "❌ ERROR: Sistema DRY no se inicializó correctamente" >&2
    exit 1
fi

# Exportar información del bootstrap
export BOOTSTRAP_VERSION="2.0.0-DRY"
export BOOTSTRAP_LOADED="true"
