#!/bin/bash

# ============================================================================
# MÓDULO BASE - Funciones fundamentales del sistema GitOps
# ============================================================================
# Proporciona funciones básicas para logging, validación y utilidades comunes
# Usado por todos los demás módulos del sistema
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN GLOBAL
# ============================================================================

# Evitar redefinición de variables si ya están cargadas
if [[ -z "${GITOPS_BASE_LOADED:-}" ]]; then
    readonly GITOPS_BASE_LOADED="true"

    # Colores para output
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[1;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_PURPLE='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[1;37m'

    # Símbolos para diferentes tipos de mensajes
    readonly SYMBOL_SUCCESS="✅"
    readonly SYMBOL_ERROR="❌"
    readonly SYMBOL_WARNING="⚠️"
    readonly SYMBOL_INFO="ℹ️"
    readonly SYMBOL_DEBUG="🔍"
    readonly SYMBOL_RUNNING="🔄"
    readonly SYMBOL_ROCKET="🚀"
fi

# ============================================================================
# FUNCIONES DE LOGGING
# ============================================================================

# Función principal de logging con timestamp
log_message() {
    local level="$1"
    local symbol="$2"
    local color="$3"
    local message="$4"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${color}[${timestamp}] ${symbol} [${level}] ${message}${COLOR_RESET}"
}

# Funciones específicas de logging
log_success() { log_message "INFO" "$SYMBOL_SUCCESS" "$COLOR_GREEN" "$1"; }
log_error() { log_message "ERROR" "$SYMBOL_ERROR" "$COLOR_RED" "$1"; }
log_warning() { log_message "WARNING" "$SYMBOL_WARNING" "$COLOR_YELLOW" "$1"; }
log_info() { log_message "INFO" "$SYMBOL_INFO" "$COLOR_BLUE" "$1"; }
log_debug() { 
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log_message "DEBUG" "$SYMBOL_DEBUG" "$COLOR_CYAN" "$1"
    fi
}
log_running() { log_message "INFO" "$SYMBOL_RUNNING" "$COLOR_PURPLE" "$1"; }

# Función para secciones principales con estimación de tiempo
log_section() {
    local title="$1"
    local estimated_time="${2:-}"
    echo
    echo "================================================================================"
    if [[ -n "$estimated_time" ]]; then
        echo -e "${COLOR_CYAN}→ ${title} (⏱️ ~${estimated_time})${COLOR_RESET}"
    else
        echo -e "${COLOR_CYAN}→ ${title}${COLOR_RESET}"
    fi
    echo "================================================================================"
    echo
}

# Variables para seguimiento de tiempo
FASE_START_TIME=""
FASE_NUMBER=""

# Función para iniciar medición de tiempo de fase
iniciar_fase() {
    local fase_num="$1"
    local title="$2"
    local estimated_time="$3"
    
    FASE_START_TIME=$(date +%s)
    FASE_NUMBER="$fase_num"
    
    log_section "$title" "$estimated_time"
}

# Función para finalizar medición de tiempo de fase
finalizar_fase() {
    local message="$1"
    
    if [[ -n "$FASE_START_TIME" ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - FASE_START_TIME))
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        
        if [[ $minutes -gt 0 ]]; then
            log_success "✅ FASE $FASE_NUMBER completada: $message (⏱️ ${minutes}m ${seconds}s)"
        else
            log_success "✅ FASE $FASE_NUMBER completada: $message (⏱️ ${seconds}s)"
        fi
    else
        log_success "✅ FASE $FASE_NUMBER completada: $message"
    fi
    
    # Reset variables
    FASE_START_TIME=""
    FASE_NUMBER=""
}

# ============================================================================
# FUNCIONES DE CONTROL
# ============================================================================

# Verificar si está en modo dry-run
es_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Verificar si está en modo verbose
es_verbose() {
    [[ "${VERBOSE:-false}" == "true" ]]
}

# Verificar si está en modo debug
es_debug() {
    [[ "${DEBUG:-false}" == "true" ]]
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

# Verificar si un comando existe
comando_existe() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar si estamos ejecutando como root
es_root() {
    [[ $EUID -eq 0 ]]
}

# Verificar si estamos en WSL
es_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]
}

# Verificar si systemd está disponible
tiene_systemd() {
    command -v systemctl >/dev/null 2>&1 && systemctl --version >/dev/null 2>&1
}

# Verificar conectividad a internet
verificar_internet() {
    if comando_existe curl; then
        curl -s --connect-timeout 5 https://www.google.com >/dev/null 2>&1
    elif comando_existe wget; then
        wget -q --spider --timeout=5 https://www.google.com >/dev/null 2>&1
    else
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

# Preguntar confirmación al usuario
confirmar() {
    local pregunta="$1"
    local respuesta
    
    while true; do
        echo -n "$pregunta [s/N]: "
        read -r respuesta
        case "$respuesta" in
            [Ss]|[Ss][Ii]|[Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]|"") return 1 ;;
            *) echo "Por favor responde 's' o 'n'" ;;
        esac
    done
}

# Obtener distribución de Linux
obtener_distribucion() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Obtener versión del sistema
obtener_version_sistema() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Verificar recursos del sistema
verificar_recursos() {
    local min_ram_gb="${1:-4}"
    local min_disk_gb="${2:-10}"
    
    # Verificar RAM
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -lt $min_ram_gb ]]; then
        log_error "RAM insuficiente: ${ram_gb}GB (mínimo: ${min_ram_gb}GB)"
        return 1
    fi
    
    # Verificar espacio en disco
    local disk_gb
    disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $disk_gb -lt $min_disk_gb ]]; then
        log_error "Espacio en disco insuficiente: ${disk_gb}GB (mínimo: ${min_disk_gb}GB)"
        return 1
    fi
    
    log_debug "Recursos verificados: RAM=${ram_gb}GB, Disco=${disk_gb}GB"
    return 0
}

# ============================================================================
# FUNCIONES DE RETRY
# ============================================================================

# Ejecutar comando con reintentos
ejecutar_con_retry() {
    local -a comando=("$@")
    local max_intentos="${MAX_RETRY_INTENTOS:-3}"
    local espera="${RETRY_ESPERA:-5}"
    local intento=1
    
    # Extraer parámetros opcionales si están al final
    if [[ "${!#}" =~ ^[0-9]+$ ]] && [[ $# -gt 1 ]]; then
        espera="${!#}"
        unset 'comando[-1]'
    fi
    
    if [[ "${!#}" =~ ^[0-9]+$ ]] && [[ $# -gt 2 ]]; then
        max_intentos="${comando[-1]}"
        unset 'comando[-1]'
    fi
    
    while [[ $intento -le $max_intentos ]]; do
        log_debug "Intento $intento de $max_intentos: ${comando[*]}"
        
        if "${comando[@]}"; then
            return 0
        fi
        
        if [[ $intento -lt $max_intentos ]]; then
            log_warning "Intento $intento falló, reintentando en ${espera}s..."
            sleep "$espera"
        fi
        
        ((intento++))
    done
    
    log_error "Comando falló después de $max_intentos intentos: $comando"
    return 1
}

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

# Función de inicialización del módulo
inicializar_modulo_base() {
    log_debug "Módulo base cargado - Funciones fundamentales disponibles"
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inicializar_modulo_base
fi
