#!/bin/bash

# ============================================================================
# AUTOLOADER INTELIGENTE DRY - Core Framework
# ============================================================================
# Responsabilidad: Carga automática e inteligente de dependencias
# Principios: Zero-duplication, Path-agnostic, Fail-fast, Self-healing
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN GLOBAL DRY
# ============================================================================

# Detección automática de PROJECT_ROOT (funciona desde cualquier ubicación)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    # Buscar PROJECT_ROOT buscando el archivo instalar.sh hacia arriba
    current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/instalar.sh" ]]; then
            export PROJECT_ROOT="$current_dir"
            break
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        echo "❌ ERROR CRÍTICO: No se pudo detectar PROJECT_ROOT" >&2
        echo "   Asegúrate de estar en el proyecto gh-gitops-infra" >&2
        exit 1
    fi
fi

# Paths estandarizados DRY
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly COMUN_DIR="$SCRIPTS_DIR/comun"
readonly CORE_DIR="$COMUN_DIR/core"
readonly MODULES_DIR="$COMUN_DIR/modules"
readonly FASES_DIR="$SCRIPTS_DIR/fases"

# ============================================================================
# FUNCIONES ATÓMICAS DE CARGA DRY
# ============================================================================

# Cargar archivo con verificación robusta
load_required_file() {
    local file_path="$1"
    local description="${2:-archivo}"
    
    if [[ ! -f "$file_path" ]]; then
        echo "❌ ERROR: $description no encontrado" >&2
        echo "   Ruta esperada: $file_path" >&2
        return 1
    fi
    
    # shellcheck source=/dev/null
    if ! source "$file_path"; then
        echo "❌ ERROR: Falló al cargar $description" >&2
        echo "   Archivo: $file_path" >&2
        return 1
    fi
    
    return 0
}

# Cargar archivo opcional (sin error si no existe)
load_optional_file() {
    local file_path="$1"
    
    if [[ -f "$file_path" ]]; then
        # shellcheck source=/dev/null
        source "$file_path" || return 1
    fi
    
    return 0
}

# Cargar todos los archivos de un directorio
load_directory_files() {
    local dir_path="$1"
    local pattern="${2:-*.sh}"
    
    if [[ ! -d "$dir_path" ]]; then
        return 0  # No es error si el directorio no existe
    fi
    
    local file
    while IFS= read -r -d '' file; do
        load_optional_file "$file"
    done < <(find "$dir_path" -maxdepth 1 -name "$pattern" -not -name "cargador-automatico.sh" -type f -print0 2>/dev/null)
}

# ============================================================================
# AUTOLOADER PRINCIPAL
# ============================================================================

# Inicializar sistema base DRY
initialize_dry_system() {
    # 1. Cargar configuración base
    load_required_file "$COMUN_DIR/base.sh" "sistema base"
    
    # 2. Cargar configuración global
    load_required_file "$COMUN_DIR/configuracion.sh" "configuración global"
    
    # 3. Cargar framework core
    load_directory_files "$CORE_DIR"
    
    # 4. Cargar módulos especializados
    load_directory_files "$MODULES_DIR"
    
    # 5. Marcar sistema como inicializado
    export DRY_SYSTEM_INITIALIZED="true"
    export DRY_AUTOLOADER_VERSION="1.0.0"
}

# Verificar si el sistema ya está inicializado (evitar re-carga)
is_dry_system_initialized() {
    [[ "${DRY_SYSTEM_INITIALIZED:-false}" == "true" ]]
}

# Punto de entrada único para autoloader
autoload_dry_system() {
    if ! is_dry_system_initialized; then
        initialize_dry_system
    fi
}

# ============================================================================
# EJECUCIÓN AUTOMÁTICA
# ============================================================================

# Auto-ejecutar al sourced (pero no al ejecutar directamente)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    autoload_dry_system
fi
