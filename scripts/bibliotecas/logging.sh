#!/bin/bash

# ============================================================================
# LIBRERÍA DE LOGGING - Sistema de registro completo y optimizado
# ============================================================================
# Sistema de logging unificado con niveles, colores y formatos
# Funciones especializadas para diferentes tipos de mensajes
# ============================================================================

# Prevenir múltiples cargas
[[ -n "${_GITOPS_LOGGING_LOADED:-}" ]] && return 0
readonly _GITOPS_LOGGING_LOADED=1

# Cargar librería base si no está cargada
if [[ -z "${_GITOPS_BASE_LOADED:-}" ]]; then
    # shellcheck source=./base.sh
    source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
fi

# ============================================================================
# CONFIGURACIÓN DE COLORES
# ============================================================================

# Solo usar colores si el terminal lo soporta
if [[ -t 1 && -t 2 ]]; then
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[0;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_PURPLE='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[0;37m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_DIM='\033[2m'
else
    readonly COLOR_RESET=''
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_BLUE=''
    readonly COLOR_PURPLE=''
    readonly COLOR_CYAN=''
    readonly COLOR_WHITE=''
    readonly COLOR_BOLD=''
    readonly COLOR_DIM=''
fi

# ============================================================================
# CONFIGURACIÓN DE ICONOS
# ============================================================================

readonly ICON_SUCCESS="✅"
readonly ICON_ERROR="❌"
readonly ICON_WARNING="⚠️"
readonly ICON_INFO="ℹ️"
readonly ICON_DEBUG="🔍"
readonly ICON_PROGRESS="🔄"
readonly ICON_COMPLETE="🎉"
readonly ICON_PENDING="⏳"
readonly ICON_ARROW="→"
readonly ICON_CHECK="✓"
readonly ICON_CROSS="✗"

# ============================================================================
# CONFIGURACIÓN DE NIVELES DE LOG
# ============================================================================

readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4
readonly LOG_LEVEL_TRACE=5

# Mapeo de nombres a números
log_level_to_number() {
    case "${1^^}" in
        "ERROR"|"ERR") echo $LOG_LEVEL_ERROR ;;
        "WARNING"|"WARN") echo $LOG_LEVEL_WARNING ;;
        "INFO") echo $LOG_LEVEL_INFO ;;
        "DEBUG") echo $LOG_LEVEL_DEBUG ;;
        "TRACE") echo $LOG_LEVEL_TRACE ;;
        *) echo $LOG_LEVEL_INFO ;;
    esac
}

# Obtener nivel actual de log
get_current_log_level() {
    log_level_to_number "${LOG_LEVEL:-INFO}"
}

# ============================================================================
# FUNCIONES DE LOGGING BÁSICAS
# ============================================================================

# Función principal de logging
_log() {
    local nivel="$1"
    local mensaje="$2"
    local color="$3"
    local icono="$4"
    local timestamp_msg
    local nivel_numero
    local nivel_actual
    
    # Verificar si el nivel debe mostrarse
    nivel_numero=$(log_level_to_number "$nivel")
    nivel_actual=$(get_current_log_level)
    
    if [[ $nivel_numero -gt $nivel_actual ]]; then
        return 0
    fi
    
    # Preparar timestamp si está habilitado
    if [[ "${SHOW_TIMESTAMP:-true}" == "true" ]]; then
        timestamp_msg="[$(timestamp)] "
    else
        timestamp_msg=""
    fi
    
    # Preparar formato del mensaje
    local formato="${timestamp_msg}${icono} ${COLOR_BOLD}[${nivel}]${COLOR_RESET} ${color}${mensaje}${COLOR_RESET}"
    
    # Mostrar en terminal
    if [[ "$nivel" == "ERROR" ]]; then
        echo -e "$formato" >&2
    else
        echo -e "$formato"
    fi
    
    # Escribir a archivo de log si está configurado
    if [[ -n "${GITOPS_LOG_FILE:-}" ]]; then
        echo "[$(timestamp)] [$nivel] $mensaje" >> "$GITOPS_LOG_FILE" 2>/dev/null || true
    fi
}

# ============================================================================
# FUNCIONES DE LOGGING POR NIVEL
# ============================================================================

# Mensajes de error
log_error() {
    _log "ERROR" "$*" "$COLOR_RED" "$ICON_ERROR"
}

# Mensajes de advertencia
log_warning() {
    _log "WARNING" "$*" "$COLOR_YELLOW" "$ICON_WARNING"
}

# Mensajes informativos
log_info() {
    _log "INFO" "$*" "$COLOR_BLUE" "$ICON_INFO"
}

# Mensajes de éxito
log_success() {
    _log "INFO" "$*" "$COLOR_GREEN" "$ICON_SUCCESS"
}

# Mensajes de debug
log_debug() {
    _log "DEBUG" "$*" "$COLOR_PURPLE" "$ICON_DEBUG"
}

# Mensajes de trace
log_trace() {
    _log "TRACE" "$*" "$COLOR_DIM" "$ICON_DEBUG"
}

# ============================================================================
# FUNCIONES ESPECIALIZADAS
# ============================================================================

# Mensaje de progreso
log_progress() {
    _log "INFO" "$*" "$COLOR_CYAN" "$ICON_PROGRESS"
}

# Mensaje de finalización
log_complete() {
    _log "INFO" "$*" "$COLOR_GREEN" "$ICON_COMPLETE"
}

# Mensaje pendiente
log_pending() {
    _log "INFO" "$*" "$COLOR_YELLOW" "$ICON_PENDING"
}

# Separador visual
log_separator() {
    local caracter="${1:-=}"
    local longitud="${2:-80}"
    local linea
    
    printf -v linea "%*s" "$longitud" ""
    linea="${linea// /$caracter}"
    
    echo -e "${COLOR_DIM}$linea${COLOR_RESET}"
}

# Encabezado de sección
log_section() {
    local titulo="$1"
    local icono="${2:-$ICON_ARROW}"
    
    echo
    log_separator "="
    echo -e "${COLOR_BOLD}${COLOR_CYAN}${icono} ${titulo}${COLOR_RESET}"
    log_separator "="
    echo
}

# Sub-encabezado
log_subsection() {
    local titulo="$1"
    local icono="${2:-$ICON_ARROW}"
    
    echo
    echo -e "${COLOR_BOLD}${COLOR_BLUE}${icono} ${titulo}${COLOR_RESET}"
    log_separator "-" 40
}

# Mostrar comando antes de ejecutar
log_command() {
    local comando="$*"
    
    if es_debug || [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${COLOR_DIM}$ ${comando}${COLOR_RESET}"
    fi
}

# ============================================================================
# FUNCIONES DE LISTA Y ESTADO
# ============================================================================

# Elemento de lista con check
log_check() {
    local mensaje="$1"
    local estado="${2:-success}"
    
    case "$estado" in
        "success"|"ok"|"done")
            echo -e "  ${COLOR_GREEN}${ICON_CHECK}${COLOR_RESET} ${mensaje}"
            ;;
        "error"|"fail"|"failed")
            echo -e "  ${COLOR_RED}${ICON_CROSS}${COLOR_RESET} ${mensaje}"
            ;;
        "warning"|"warn")
            echo -e "  ${COLOR_YELLOW}${ICON_WARNING}${COLOR_RESET} ${mensaje}"
            ;;
        "pending"|"wait")
            echo -e "  ${COLOR_YELLOW}${ICON_PENDING}${COLOR_RESET} ${mensaje}"
            ;;
        *)
            echo -e "  ${COLOR_BLUE}${ICON_ARROW}${COLOR_RESET} ${mensaje}"
            ;;
    esac
}

# Lista de elementos
log_list() {
    local items=("$@")
    
    for item in "${items[@]}"; do
        echo -e "  ${COLOR_BLUE}•${COLOR_RESET} ${item}"
    done
}

# ============================================================================
# FUNCIONES DE CONFIRMACIÓN
# ============================================================================

# Solicitar confirmación
confirmar() {
    local mensaje="$1"
    local por_defecto="${2:-n}"
    local respuesta
    
    # En modo dry-run o no interactivo, usar valor por defecto
    if es_dry_run || [[ "${INTERACTIVE:-true}" != "true" ]]; then
        log_info "Modo no interactivo: usando valor por defecto '$por_defecto'"
        [[ "$por_defecto" =~ ^[Ss]|[Yy]$ ]]
        return $?
    fi
    
    # Mostrar prompt con colores
    echo -e "${COLOR_YELLOW}${ICON_WARNING} ${mensaje}${COLOR_RESET}"
    
    if [[ "$por_defecto" =~ ^[Ss]|[Yy]$ ]]; then
        echo -ne "${COLOR_BOLD}¿Continuar? [S/n]: ${COLOR_RESET}"
    else
        echo -ne "${COLOR_BOLD}¿Continuar? [s/N]: ${COLOR_RESET}"
    fi
    
    read -r respuesta
    
    # Si está vacío, usar valor por defecto
    if [[ -z "$respuesta" ]]; then
        respuesta="$por_defecto"
    fi
    
    # Verificar respuesta
    [[ "$respuesta" =~ ^[Ss]|[Yy]$ ]]
}

# ============================================================================
# FUNCIONES DE PROGRESO
# ============================================================================

# Barra de progreso simple
mostrar_progreso() {
    local actual="$1"
    local total="$2"
    local descripcion="${3:-Procesando}"
    local ancho=40
    local completado
    local restante
    local porcentaje
    
    # Calcular progreso
    porcentaje=$((actual * 100 / total))
    completado=$((actual * ancho / total))
    restante=$((ancho - completado))
    
    # Crear barra
    printf "\r${COLOR_CYAN}%s${COLOR_RESET} [" "$descripcion"
    printf "%*s" "$completado" "" | tr ' ' '█'
    printf "%*s" "$restante" "" | tr ' ' '░'
    printf "] %d%% (%d/%d)" "$porcentaje" "$actual" "$total"
    
    # Nueva línea al completar
    if [[ $actual -eq $total ]]; then
        echo
    fi
}

# ============================================================================
# FUNCIONES DE CARGA Y SPINNER
# ============================================================================

# Spinner para operaciones largas
mostrar_spinner() {
    local pid="$1"
    local mensaje="${2:-Procesando}"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    # Ocultar cursor
    tput civis 2>/dev/null || true
    
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${COLOR_CYAN}%s${COLOR_RESET} %s" "$mensaje" "${chars:$i:1}"
        i=$(((i + 1) % ${#chars}))
        sleep 0.1
    done
    
    # Mostrar cursor y limpiar línea
    tput cnorm 2>/dev/null || true
    printf "\r%*s\r" $((${#mensaje} + 3)) ""
}

# ============================================================================
# FUNCIONES DE BANNER Y PRESENTACIÓN
# ============================================================================

# Banner principal de la aplicación
mostrar_banner() {
    local version="${GITOPS_VERSION:-}"
    
    echo
    echo -e "${COLOR_BOLD}${COLOR_BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                ║"
    echo "║                          🚀 GitOps España Infrastructure                      ║"
    echo "║                                                                                ║"
    echo "║                    Infraestructura GitOps Completa y Modular                  ║"
    if [[ -n "$version" ]]; then
    echo "║                                  Versión $version                                ║"
    fi
    echo "║                                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    echo
}

# Banner de finalización
mostrar_banner_finalizacion() {
    echo
    echo -e "${COLOR_BOLD}${COLOR_GREEN}"
    echo "╔════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                ║"
    echo "║                            🎉 ¡Instalación Completada! 🎉                     ║"
    echo "║                                                                                ║"
    echo "║                        Infraestructura GitOps Lista                           ║"
    echo "║                                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${COLOR_RESET}"
    echo
}

# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================

# Configurar sistema de logging
configurar_logging() {
    local nivel="${1:-INFO}"
    local archivo="${2:-}"
    
    # Configurar nivel
    export LOG_LEVEL="$nivel"
    
    # Configurar archivo si se especifica
    if [[ -n "$archivo" ]]; then
        export GITOPS_LOG_FILE="$archivo"
        
        # Crear directorio si no existe
        local dir
        dir=$(dirname "$archivo")
        mkdir -p "$dir" 2>/dev/null || true
        
        # Inicializar archivo de log
        {
            echo "# GitOps Infrastructure Log - $(timestamp)"
            echo "# Nivel: $nivel"
            echo "# =============================================="
            echo
        } > "$archivo" 2>/dev/null || true
    fi
    
    log_debug "Sistema de logging configurado - Nivel: $nivel, Archivo: ${archivo:-'terminal únicamente'}"
}

# ============================================================================
# EXPORTS PARA COMPATIBILIDAD
# ============================================================================

# Exportar funciones principales
export -f log_error
export -f log_warning
export -f log_info
export -f log_success
export -f log_debug
export -f log_trace
export -f log_progress
export -f log_complete
export -f log_pending
export -f log_separator
export -f log_section
export -f log_subsection
export -f log_command
export -f log_check
export -f log_list
export -f confirmar
export -f mostrar_progreso
export -f mostrar_spinner
export -f mostrar_banner
export -f mostrar_banner_finalizacion
export -f configurar_logging

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

# Auto-configurar logging básico si no está configurado
if [[ -z "${_GITOPS_LOGGING_INITIALIZED:-}" ]]; then
    configurar_logging "${LOG_LEVEL:-INFO}" "${GITOPS_LOG_FILE:-}"
    export _GITOPS_LOGGING_INITIALIZED=1
fi
