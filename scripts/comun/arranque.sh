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
        source "$config_path"
    else
        echo "❌ Error: Módulo de configuración no encontrado: $config_path" >&2
        return 1
    fi
    
    # Cargar módulo base
    local base_path="$comun_dir/base.sh"
    if [[ -f "$base_path" ]]; then
        # shellcheck source=scripts/comun/base.sh
        source "$base_path"
    else
        echo "❌ Error: Módulo base no encontrado: $base_path" >&2
        return 1
    fi
    
    # Inicializar configuración
    inicializar_configuracion
    
    # Validar configuración básica
    if ! validar_configuracion; then
        echo "❌ Error: Configuración inválida" >&2
        return 1
    fi
    
    # Inicializar módulo base
    if command -v inicializar_modulo_base >/dev/null 2>&1; then
        inicializar_modulo_base
    fi
    
    return 0
}

# Función para verificar si las dependencias están cargadas
verificar_dependencias_cargadas() {
    # Verificar que están cargados los módulos esenciales
    if [[ -z "${GITOPS_CONFIG_LOADED:-}" ]]; then
        echo "❌ Error: Módulo de configuración no cargado" >&2
        return 1
    fi
    
    if [[ -z "${GITOPS_BASE_LOADED:-}" ]]; then
        echo "❌ Error: Módulo base no cargado" >&2
        return 1
    fi
    
    # Verificar que están disponibles las funciones esenciales
    if ! command -v log_info >/dev/null 2>&1; then
        echo "❌ Error: Funciones de logging no disponibles" >&2
        return 1
    fi
    
    if ! command -v es_dry_run >/dev/null 2>&1; then
        echo "❌ Error: Funciones de control no disponibles" >&2
        return 1
    fi
    
    return 0
}

# Función principal de autocontención
auto_contener() {
    # Si ya están cargadas las dependencias, no hacer nada
    if verificar_dependencias_cargadas 2>/dev/null; then
        return 0
    fi
    
    # Cargar dependencias automáticamente
    if ! auto_cargar_dependencias; then
        echo "❌ Error: No se pudieron cargar las dependencias automáticamente" >&2
        return 1
    fi
    
    # Verificar que se cargaron correctamente
    if ! verificar_dependencias_cargadas; then
        echo "❌ Error: Dependencias no se cargaron correctamente" >&2
        return 1
    fi
    
    return 0
}

# Auto-ejecutar autocontención si este script se carga directamente
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Se está cargando con source, ejecutar autocontención
    auto_contener
fi
