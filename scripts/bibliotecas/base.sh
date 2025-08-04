#!/bin/bash

# ============================================================================
# LIBRERÍA BASE - Funciones fundamentales y variables globales
# ============================================================================
# Funciones básicas reutilizables en toda la aplicación
# Solo funciones esenciales - sin sobrecarga
# ============================================================================

# Prevenir múltiples cargas
[[ -n "${_GITOPS_BASE_LOADED:-}" ]] && return 0
readonly _GITOPS_BASE_LOADED=1

# ============================================================================
# CONSTANTES GLOBALES
# ============================================================================

# Metadatos del proyecto
readonly GITOPS_VERSION="2.3.0"
readonly GITOPS_NAME="GitOps España"
readonly GITOPS_DESCRIPTION="Infraestructura GitOps completa y modular"

# Directorios del proyecto
readonly GITOPS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly GITOPS_SCRIPTS_DIR="${GITOPS_ROOT}/scripts"
readonly GITOPS_LIB_DIR="${GITOPS_SCRIPTS_DIR}/bibliotecas"
readonly GITOPS_CORE_DIR="${GITOPS_SCRIPTS_DIR}/nucleo"
readonly GITOPS_MODULES_DIR="${GITOPS_SCRIPTS_DIR}/modulos"
readonly GITOPS_GITOPS_DIR="${GITOPS_SCRIPTS_DIR}/argocd"
readonly GITOPS_INSTALLERS_DIR="${GITOPS_SCRIPTS_DIR}/instaladores"
readonly GITOPS_UTILS_DIR="${GITOPS_SCRIPTS_DIR}/utilidades"

# Configuración de logging
export GITOPS_LOG_DIR="${GITOPS_LOG_DIR:-/tmp}"
export GITOPS_LOG_FILE="${GITOPS_LOG_FILE:-}"

# URLs y repositorios
readonly GITOPS_REPO_URL="https://github.com/andres20980/gh-gitops-infra"
readonly GITOPS_DOCS_URL="${GITOPS_REPO_URL}/blob/main/README.md"

# ============================================================================
# FUNCIONES BÁSICAS DE UTILIDAD
# ============================================================================

# Verificar si comando existe
comando_existe() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar si archivo existe y es ejecutable
script_existe() {
    [[ -f "$1" && -x "$1" ]]
}

# Verificar si estamos en modo dry-run
es_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" || "${MODO_DRY_RUN:-false}" == "true" ]]
}

# Verificar si estamos en modo debug
es_debug() {
    [[ "${DEBUG:-false}" == "true" || "${LOG_LEVEL:-}" == "DEBUG" ]]
}

# Obtener timestamp formateado
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Obtener usuario actual
usuario_actual() {
    echo "${USER:-$(whoami)}"
}

# Verificar si script se ejecuta como root
es_root() {
    [[ $EUID -eq 0 ]]
}

# Verificar si estamos en WSL
es_wsl() {
    grep -q Microsoft /proc/version 2>/dev/null
}

# Verificar si estamos en Ubuntu
es_ubuntu() {
    [[ -f /etc/os-release ]] && grep -q "Ubuntu" /etc/os-release
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

# Validar que directorio existe
validar_directorio() {
    local dir="$1"
    local descripcion="${2:-directorio}"
    
    if [[ ! -d "$dir" ]]; then
        echo "Error: $descripcion no existe: $dir" >&2
        return 1
    fi
    return 0
}

# Validar que archivo existe
validar_archivo() {
    local archivo="$1"
    local descripcion="${2:-archivo}"
    
    if [[ ! -f "$archivo" ]]; then
        echo "Error: $descripcion no existe: $archivo" >&2
        return 1
    fi
    return 0
}

# Validar dependencias críticas
validar_dependencias_criticas() {
    local dependencias=("bash" "curl" "wget" "jq")
    local faltantes=()
    
    for dep in "${dependencias[@]}"; do
        if ! comando_existe "$dep"; then
            faltantes+=("$dep")
        fi
    done
    
    if [[ ${#faltantes[@]} -gt 0 ]]; then
        echo "Error: Dependencias críticas faltantes: ${faltantes[*]}" >&2
        return 1
    fi
    return 0
}

# ============================================================================
# FUNCIONES DE CARGA DE MÓDULOS
# ============================================================================

# Cargar librería de forma segura
cargar_libreria() {
    local nombre="$1"
    local requerida="${2:-true}"
    local ruta="${GITOPS_LIB_DIR}/${nombre}.sh"
    
    if [[ -f "$ruta" ]]; then
        # shellcheck source=/dev/null
        source "$ruta"
        return 0
    elif [[ "$requerida" == "true" ]]; then
        echo "Error: Librería requerida no encontrada: $nombre" >&2
        return 1
    fi
    return 0
}

# Cargar módulo de forma segura
cargar_modulo() {
    local nombre="$1"
    local requerido="${2:-true}"
    local ruta="${GITOPS_MODULES_DIR}/${nombre}.sh"
    
    if [[ -f "$ruta" ]]; then
        # shellcheck source=/dev/null
        source "$ruta"
        return 0
    elif [[ "$requerido" == "true" ]]; then
        echo "Error: Módulo requerido no encontrado: $nombre" >&2
        return 1
    fi
    return 0
}

# Cargar script de core
cargar_core() {
    local nombre="$1"
    local requerido="${2:-true}"
    local ruta="${GITOPS_CORE_DIR}/${nombre}.sh"
    
    if [[ -f "$ruta" ]]; then
        # shellcheck source=/dev/null
        source "$ruta"
        return 0
    elif [[ "$requerido" == "true" ]]; then
        echo "Error: Script core requerido no encontrado: $nombre" >&2
        return 1
    fi
    return 0
}

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN
# ============================================================================

# Inicializar configuración por defecto
inicializar_configuracion_base() {
    # Variables de configuración global
    export GITOPS_MODE="${GITOPS_MODE:-normal}"
    export DRY_RUN="${DRY_RUN:-false}"
    export VERBOSE="${VERBOSE:-false}"
    export LOG_LEVEL="${LOG_LEVEL:-INFO}"
    export FORCE="${FORCE:-false}"
    
    # Configuración de cluster
    export CLUSTER_NAME="${CLUSTER_NAME:-gitops-local}"
    export CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
    export CLUSTER_CONTEXT="${CLUSTER_CONTEXT:-}"
    
    # Configuración de namespace
    export DEFAULT_NAMESPACE="${DEFAULT_NAMESPACE:-default}"
    export ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
    export KARGO_NAMESPACE="${KARGO_NAMESPACE:-kargo-system}"
    
    # Configuración de timeouts
    export TIMEOUT_INSTALL="${TIMEOUT_INSTALL:-600}"
    export TIMEOUT_READY="${TIMEOUT_READY:-300}"
    export TIMEOUT_DELETE="${TIMEOUT_DELETE:-120}"
}

# ============================================================================
# FUNCIONES DE LIMPIEZA
# ============================================================================

# Función de limpieza en exit
cleanup_base() {
    local exit_code=$?
    
    # Limpiar archivos temporales si existen
    if [[ -n "${GITOPS_TEMP_DIR:-}" && -d "$GITOPS_TEMP_DIR" ]]; then
        rm -rf "$GITOPS_TEMP_DIR" 2>/dev/null || true
    fi
    
    # Limpiar variables sensibles
    unset KUBECONFIG_TEMP 2>/dev/null || true
    
    exit $exit_code
}

# Configurar trap para limpieza
configurar_limpieza() {
    trap cleanup_base EXIT INT TERM
}

# ============================================================================
# INICIALIZACIÓN AUTOMÁTICA
# ============================================================================

# Auto-inicializar cuando se carga la librería
_init_base() {
    # Validar dependencias críticas
    if ! validar_dependencias_criticas; then
        echo "Error: Faltan dependencias críticas" >&2
        return 1
    fi
    
    # Inicializar configuración
    inicializar_configuracion_base
    
    # Configurar limpieza automática
    configurar_limpieza
    
    # Marcar como inicializada
    export _GITOPS_BASE_INITIALIZED=1
}

# Ejecutar inicialización
_init_base

# ============================================================================
# EXPORTS PARA COMPATIBILIDAD
# ============================================================================

# Exportar funciones principales para uso en otros scripts
export -f comando_existe
export -f script_existe
export -f es_dry_run
export -f es_debug
export -f timestamp
export -f usuario_actual
export -f es_root
export -f es_wsl
export -f es_ubuntu
export -f validar_directorio
export -f validar_archivo
export -f cargar_libreria
export -f cargar_modulo
export -f cargar_core
