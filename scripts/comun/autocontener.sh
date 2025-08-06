#!/bin/bash

# ============================================================================
# MÓDULO DE AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================
# Permite que cualquier script se ejecute independientemente cargando
# automáticamente todos los módulos necesarios
# ============================================================================

# Función para cargar automáticamente las dependencias necesarias
auto_cargar_dependencias() {
    # Detectar PROJECT_ROOT automáticamente
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        if [[ -f "instalar.sh" ]]; then
            # Ejecutándose desde el directorio raíz
            PROJECT_ROOT="$(pwd)"
        elif [[ -f "../instalar.sh" ]]; then
            # Ejecutándose desde subdirectorio (scripts/)
            PROJECT_ROOT="$(cd .. && pwd)"
        elif [[ -f "../../instalar.sh" ]]; then
            # Ejecutándose desde subdirectorio profundo (scripts/fases/)
            PROJECT_ROOT="$(cd ../.. && pwd)"
        else
            # Buscar hacia arriba hasta encontrar instalar.sh
            local current_dir="$(pwd)"
            while [[ "$current_dir" != "/" ]]; do
                if [[ -f "$current_dir/instalar.sh" ]]; then
                    PROJECT_ROOT="$current_dir"
                    break
                fi
                current_dir="$(dirname "$current_dir")"
            done
            
            if [[ -z "${PROJECT_ROOT:-}" ]]; then
                echo "❌ Error: No se pudo detectar PROJECT_ROOT automáticamente" >&2
                echo "   Asegúrate de ejecutar desde el directorio del proyecto GitOps" >&2
                return 1
            fi
        fi
        export PROJECT_ROOT
    fi
    
    # Definir rutas principales
    local scripts_dir="$PROJECT_ROOT/scripts"
    local comun_dir="$scripts_dir/comun"
    
    # Cargar configuración centralizada
    local config_path="$comun_dir/config.sh"
    if [[ -f "$config_path" ]]; then
        # shellcheck source=scripts/comun/config.sh
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
