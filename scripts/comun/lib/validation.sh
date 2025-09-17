#!/bin/bash

# ============================================================================
# VALIDATION LIB - Validación y Logging Universal 
# ============================================================================
# Responsabilidad: Logging, validación, reporting, debugging
# Principios: Consistent, Structured, Performance-aware
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN DE LOGGING
# ============================================================================

readonly LOG_LEVELS=(
    "DEBUG:🔍"
    "INFO:ℹ️"
    "SUCCESS:✅" 
    "WARNING:⚠️"
    "ERROR:❌"
    "SECTION:📋"
)

# Códigos de color (usando ANSI-C quoting para emitir ESC reales)
readonly _ESC=$'\033'
readonly _CLR_DEBUG="${_ESC}[0;36m"   # Cyan
readonly _CLR_INFO="${_ESC}[0;34m"    # Blue
readonly _CLR_SUCCESS="${_ESC}[0;32m" # Green
readonly _CLR_WARNING="${_ESC}[0;33m" # Yellow
readonly _CLR_ERROR="${_ESC}[0;31m"   # Red
readonly _CLR_SECTION="${_ESC}[1;35m" # Magenta Bold
readonly _CLR_RESET="${_ESC}[0m"      # Reset

_color_for_level() {
    case "$1" in
        DEBUG) echo -n "${_CLR_DEBUG}" ;;
        INFO) echo -n "${_CLR_INFO}" ;;
        SUCCESS) echo -n "${_CLR_SUCCESS}" ;;
        WARNING) echo -n "${_CLR_WARNING}" ;;
        ERROR) echo -n "${_CLR_ERROR}" ;;
        SECTION) echo -n "${_CLR_SECTION}" ;;
        *) echo -n "" ;;
    esac
}

# Variables globales de logging
LOG_FILE="${LOG_FILE:-}"
VERBOSE="${VERBOSE:-false}"
QUIET="${QUIET:-false}"
LOG_TIMESTAMP="${LOG_TIMESTAMP:-true}"
# Control de color: auto|always|never. Respeta NO_COLOR y TERM=dumb.
LOG_COLOR_MODE="${LOG_COLOR_MODE:-auto}"
# Control de emojis y formato de hora
# LOG_EMOJI_MODE: auto|always|never (por defecto auto)
LOG_EMOJI_MODE="${LOG_EMOJI_MODE:-auto}"
# Compat: si LOG_EMOJI se define (true/false) tiene prioridad
LOG_EMOJI="${LOG_EMOJI:-}"
LOG_TIMEFMT="${LOG_TIMEFMT:-%H:%M:%S}"

# ============================================================================
# FUNCIONES DE LOGGING
# ============================================================================

# Determinar si el stream soporta color (stdout=1, stderr=2)
_supports_color() {
    local fd="${1:-1}"

    # Desactivaciones explícitas
    if [[ -n "${NO_COLOR:-}" ]] || [[ "${LOG_COLOR_MODE:-auto}" == "never" ]] || [[ "${TERM:-}" == "dumb" ]]; then
        return 1
    fi

    # Forzar color
    if [[ "${LOG_COLOR_MODE:-auto}" == "always" ]]; then
        return 0
    fi

    # Automático: depende de si el fd es un TTY
    if [[ "$fd" == "2" ]]; then
        [[ -t 2 ]]
    else
        [[ -t 1 ]]
    fi
}

# Determinar si el stream puede mostrar emojis (stdout=1, stderr=2)
_supports_emoji() {
    local fd="${1:-1}"

    # Desactivaciones explícitas
    if [[ "${LOG_EMOJI_MODE:-auto}" == "never" ]]; then
        return 1
    fi

    # Forzar emojis
    if [[ "${LOG_EMOJI_MODE:-auto}" == "always" ]]; then
        return 0
    fi

    # Automático: TTY y locale UTF-8
    local is_tty=1
    if [[ "$fd" == "2" ]]; then
        [[ -t 2 ]] && is_tty=0 || is_tty=1
    else
        [[ -t 1 ]] && is_tty=0 || is_tty=1
    fi
    if [[ $is_tty -ne 0 ]]; then
        return 1
    fi

    local locale_env="${LC_ALL:-${LANG:-}}"
    if [[ "$locale_env" =~ [Uu][Tt][Ff]-?8 ]]; then
        return 0
    fi
    return 1
}

# Detectar si el locale es UTF-8
_is_utf8_locale() {
    local locale_env="${LC_ALL:-${LANG:-}}"
    [[ "$locale_env" =~ [Uu][Tt][Ff]-?8 ]]
}

# Función base de logging
_log() {
    local level="$1"
    local message="$2"
    local emoji=""
    local color=""
    
    # Extraer emoji y color para el nivel
    for spec in "${LOG_LEVELS[@]}"; do
        if [[ "$spec" == "$level:"* ]]; then
            emoji="${spec#*:}"
            break
        fi
    done
    
    color="$(_color_for_level "$level")"
    
    # Timestamp opcional
    local timestamp=""
    if [[ "${LOG_TIMESTAMP:-true}" == "true" ]]; then
        timestamp="[$(date +"${LOG_TIMEFMT:-%H:%M:%S}")] "
    fi
    
    # Opcional: eliminar emoji duplicado al inicio del mensaje
    if [[ "${LOG_STRIP_INLINE_EMOJI:-true}" == "true" ]]; then
        # Quita marcadores comunes si van al inicio (para evitar doble emoji)
        local _markers=("✅" "❌" "⚠️" "ℹ️")
        for _m in "${_markers[@]}"; do
            if [[ "$message" == "${_m} "* ]]; then
                message="${message#"${_m} "}"
                break
            fi
        done
    fi

    # Prefijo con emoji opcional
    local prefix="${timestamp}"
    # Decidir si usar emoji: LOG_EMOJI (si está) tiene prioridad; si no, auto
    local fd="1"
    [[ "$level" == "ERROR" ]] && fd="2"
    local use_emoji="false"
    if [[ -n "${LOG_EMOJI}" ]]; then
        [[ "${LOG_EMOJI}" == "true" ]] && use_emoji="true"
    else
        _supports_emoji "$fd" && use_emoji="true"
    fi
    if [[ "$use_emoji" == "true" && -n "$emoji" ]]; then
        prefix+="${emoji} "
    fi

    # Formatear mensaje
    local formatted_message="${prefix}${message}"
    
    # Determinar fd de salida y aplicar color si procede
    if _supports_color "$fd" && [[ -n "$color" ]]; then
        formatted_message="${color}${formatted_message}${_CLR_RESET}"
    fi
    
    # Output según configuración
    if [[ "${QUIET:-false}" != "true" ]]; then
        case "$level" in
            "ERROR")
                echo "$formatted_message" >&2
                ;;
            "DEBUG")
                if [[ "${VERBOSE:-false}" == "true" ]]; then
                    echo "$formatted_message"
                fi
                ;;
            *)
                echo "$formatted_message"
                ;;
        esac
    fi
    
    # Log to file si está configurado
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
    fi
}

# Funciones de logging por nivel
log_debug() { _log "DEBUG" "$1"; }
log_info() { _log "INFO" "$1"; }
log_success() { _log "SUCCESS" "$1"; }
log_warning() { _log "WARNING" "$1"; }
log_error() { _log "ERROR" "$1"; }

# Función especial para secciones
log_section() {
    local title="$1"
    _log "SECTION" "════════════════════════════════════════"
    _log "SECTION" "$title"
    _log "SECTION" "════════════════════════════════════════"
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

# Validar comando disponible
validate_command() {
    local command="$1"
    local description="${2:-$command}"
    
    if command -v "$command" >/dev/null 2>&1; then
        log_debug "✅ Comando '$command' disponible"
        return 0
    else
        log_error "❌ Comando '$command' no encontrado ($description)"
        return 1
    fi
}

# Validar múltiples comandos
validate_commands() {
    local commands=("$@")
    local all_ok=true
    
    log_info "🔍 Validando comandos requeridos..."
    
    for cmd in "${commands[@]}"; do
        if ! validate_command "$cmd"; then
            all_ok=false
        fi
    done
    
    if $all_ok; then
        log_success "✅ Todos los comandos están disponibles"
        return 0
    else
        log_error "❌ Faltan comandos críticos"
        return 1
    fi
}

# Validar archivo existe
validate_file() {
    local file="$1"
    local description="${2:-archivo}"
    
    if [[ -f "$file" ]]; then
        log_debug "✅ Archivo '$file' existe"
        return 0
    else
        log_error "❌ $description no encontrado: $file"
        return 1
    fi
}

# Validar directorio existe
validate_directory() {
    local dir="$1"
    local description="${2:-directorio}"
    
    if [[ -d "$dir" ]]; then
        log_debug "✅ Directorio '$dir' existe"
        return 0
    else
        log_error "❌ $description no encontrado: $dir"
        return 1
    fi
}

# Validar permisos de archivo
validate_permissions() {
    local file="$1"
    local required_permissions="$2"
    local description="${3:-archivo}"
    
    if [[ ! -e "$file" ]]; then
        log_error "❌ $description no existe: $file"
        return 1
    fi
    
    local current_perms
    current_perms=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
    
    case "$required_permissions" in
        "readable")
            if [[ -r "$file" ]]; then
                log_debug "✅ $description es legible"
                return 0
            fi
            ;;
        "writable")
            if [[ -w "$file" ]]; then
                log_debug "✅ $description es escribible"
                return 0
            fi
            ;;
        "executable")
            if [[ -x "$file" ]]; then
                log_debug "✅ $description es ejecutable"
                return 0
            fi
            ;;
        *)
            # Validar permisos octales específicos
            if [[ "$current_perms" == "$required_permissions" ]]; then
                log_debug "✅ $description tiene permisos $required_permissions"
                return 0
            fi
            ;;
    esac
    
    log_error "❌ $description no tiene permisos requeridos ($required_permissions)"
    return 1
}

# Validar conectividad de red
validate_network() {
    local host="${1:-8.8.8.8}"
    local description="${2:-conectividad internet}"
    
    if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
        log_success "✅ $description disponible"
        return 0
    else
        log_error "❌ $description no disponible"
        return 1
    fi
}

# Validar puerto disponible
validate_port() {
    local port="$1"
    local description="${2:-puerto $port}"
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        log_warning "⚠️ $description ya está en uso"
        return 1
    else
        log_success "✅ $description disponible"
        return 0
    fi
}

# ============================================================================
# FUNCIONES DE SISTEMA
# ============================================================================

# Validar distribución Linux
validate_linux_distro() {
    local supported_distros=("ubuntu" "debian" "fedora" "centos" "rhel")
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "❌ No se puede determinar la distribución Linux"
        return 1
    fi
    
    local distro_id
    distro_id=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
    
    for supported in "${supported_distros[@]}"; do
        if [[ "$distro_id" == "$supported" ]]; then
            log_success "✅ Distribución soportada: $distro_id"
            return 0
        fi
    done
    
    log_warning "⚠️ Distribución no oficialmente soportada: $distro_id"
    return 1
}

# Validar recursos del sistema
validate_system_resources() {
    local min_memory_gb="${1:-4}"
    local min_disk_gb="${2:-20}"
    
    log_info "🔍 Validando recursos del sistema..."
    
    # Memoria
    local memory_gb
    memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    
    if [[ $memory_gb -ge $min_memory_gb ]]; then
        log_success "✅ Memoria suficiente: ${memory_gb}GB (mínimo: ${min_memory_gb}GB)"
    else
        log_warning "⚠️ Memoria insuficiente: ${memory_gb}GB (mínimo: ${min_memory_gb}GB)"
    fi
    
    # Disco
    local disk_gb
    disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [[ $disk_gb -ge $min_disk_gb ]]; then
        log_success "✅ Espacio suficiente: ${disk_gb}GB disponibles (mínimo: ${min_disk_gb}GB)"
    else
        log_warning "⚠️ Espacio insuficiente: ${disk_gb}GB disponibles (mínimo: ${min_disk_gb}GB)"
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE REPORTING
# ============================================================================

# Generar reporte de validación
generate_validation_report() {
    local report_file="${1:-/tmp/validation-report.txt}"
    
    log_info "📊 Generando reporte de validación..."
    
    {
        echo "======================================"
        echo "REPORTE DE VALIDACIÓN DEL SISTEMA"
        echo "======================================"
        echo "Fecha: $(date)"
        echo "Usuario: $(whoami)"
        echo "Host: $(hostname)"
        echo ""
        
        echo "DISTRIBUCIÓN:"
        if [[ -f /etc/os-release ]]; then
            grep 'PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"'
        fi
        echo ""
        
        echo "RECURSOS:"
        echo "  Memoria: $(free -h | awk '/^Mem:/{print $2}')"
        echo "  Disco (/): $(df -h / | awk 'NR==2 {print $4}')"
        echo "  CPU: $(nproc) cores"
        echo ""
        
        echo "COMANDOS CRÍTICOS:"
        local critical_commands=("docker" "kubectl" "minikube" "helm" "git")
        for cmd in "${critical_commands[@]}"; do
            if command -v "$cmd" >/dev/null 2>&1; then
                echo "  ✅ $cmd: $(command -v "$cmd")"
            else
                echo "  ❌ $cmd: No encontrado"
            fi
        done
        echo ""
        
        echo "CONECTIVIDAD:"
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            echo "  ✅ Internet: Disponible"
        else
            echo "  ❌ Internet: No disponible"
        fi
        
    } > "$report_file"
    
    log_success "✅ Reporte generado: $report_file"
    return 0
}

# Mostrar resumen del sistema
show_system_summary() {
    log_section "💻 Resumen del Sistema"
    
    # OS Info
    if [[ -f /etc/os-release ]]; then
        local os_name
        os_name=$(grep 'PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
        log_info "🖥️ OS: $os_name"
    fi
    
    # Resources
    local memory_info cpu_count disk_info
    memory_info=$(free -h | awk '/^Mem:/{print $2}')
    cpu_count=$(nproc)
    disk_info=$(df -h / | awk 'NR==2 {print $4}')
    
    log_info "💾 Memoria: $memory_info"
    log_info "🔥 CPU: $cpu_count cores"
    log_info "💽 Disco (/): $disk_info disponibles"
    
    # Network
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_info "🌐 Red: Conectado"
    else
        log_info "🌐 Red: Sin conexión"
    fi
}

# Mostrar banner bonito (adaptativo)
show_banner() {
    local title="${1:-GitOps Infra}"
    local subtitle="${2:-DRY · Modular · Automático}"

    # Determinar capacidades
    local fd="1"
    local use_color=0
    local use_emoji=0
    _supports_color "$fd" && use_color=1
    _supports_emoji "$fd" && use_emoji=1

    local flame=""
    [[ $use_emoji -eq 1 ]] && flame="🔥 "

    # Si el locale no es UTF-8, usar ASCII seguro sencillo
    if ! _is_utf8_locale; then
        subtitle="DRY - Modular - Automatico"
    fi

    if [[ $use_color -eq 1 ]]; then
        # Magenta bold para el título
        local c_title="\033[1;35m"
        local c_sub="\033[0;37m"
        local c_reset="\033[0m"
        echo -e "${c_title}${flame}${title}${c_reset}"
        echo -e "${c_sub}${subtitle}${c_reset}"
    else
        echo "${flame}${title}"
        echo "$subtitle"
    fi
}

# ============================================================================
# PERFILES DE LOGGING (atajos)
# ============================================================================

# Activa colores y emojis siempre (ideal para uso local interactivo)
use_pretty_logs() {
    export LOG_COLOR_MODE="always"
    export LOG_EMOJI_MODE="always"
    export LOG_SHOW_WELCOME="always"
    export LOG_SHOW_LIB_LOAD="always"
    export LOG_TIMESTAMP="true"
}

# Desactiva colores y emojis (ideal para CI/logs no interactivos)
use_ci_logs() {
    export LOG_COLOR_MODE="never"
    export LOG_EMOJI_MODE="never"
    export LOG_SHOW_WELCOME="never"
    export LOG_SHOW_LIB_LOAD="never"
    export LOG_TIMESTAMP="true"
}

# Exportar funciones de conveniencia
export -f use_pretty_logs use_ci_logs || true

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN
# ============================================================================

# Configurar logging
setup_logging() {
    local log_file="${1:-}"
    local verbose="${2:-false}"
    local quiet="${3:-false}"
    
    if [[ -n "$log_file" ]]; then
        LOG_FILE="$log_file"
        # Crear directorio si no existe
        local log_dir
        log_dir=$(dirname "$log_file")
        if [[ ! -d "$log_dir" ]]; then
            mkdir -p "$log_dir"
        fi
        log_info "📝 Logging habilitado: $log_file"
    fi
    
    VERBOSE="$verbose"
    QUIET="$quiet"
    
    if [[ "$verbose" == "true" ]]; then
        log_info "🔍 Modo verbose habilitado"
    fi
    
    if [[ "$quiet" == "true" ]]; then
        log_info "🤫 Modo quiet habilitado"
    fi
}

# Confirmación interactiva (compatible con modo no-interactivo)
# Uso: confirmar "Mensaje de confirmación"
confirmar() {
    local prompt="${1:-¿Continuar?}"

    # Si se fuerza asunción afirmativa por variables de entorno, devolver true
    if [[ "${ASSUME_YES:-false}" == "true" ]] || [[ "${CI:-false}" == "true" ]] || [[ "${NONINTERACTIVE:-false}" == "true" ]]; then
        log_info "Auto-confirmado: $prompt"
        return 0
    fi

    # Si no hay TTY disponible, no podemos preguntar; devolver fallo por seguridad
    if [[ ! -t 0 ]]; then
        log_warning "No hay TTY para confirmar: $prompt"
        return 1
    fi

    # Preguntar al usuario
    local reply
    read -r -p "$prompt [y/N]: " reply
    case "$reply" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

