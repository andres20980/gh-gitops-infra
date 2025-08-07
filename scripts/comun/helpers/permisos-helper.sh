#!/bin/bash

# ============================================================================
# HELPER: GESTIÓN AUTOMÁTICA DE PERMISOS
# ============================================================================
# Funciones especializadas para gestión inteligente de permisos
# Principios: Autocontención, Escalado/Desescalado automático, Sin interacción
# ============================================================================

set -euo pipefail

# ============================================================================
# DETECCIÓN Y ANÁLISIS DE CONTEXTO
# ============================================================================

# Detecta el usuario real cuando se ejecuta con sudo
obtener_usuario_real() {
    echo "${SUDO_USER:-$(logname 2>/dev/null || who am i | awk '{print $1}' || echo "asanchez")}"
}

# Obtiene el home directory del usuario real
obtener_home_real() {
    local usuario="${1:-$(obtener_usuario_real)}"
    eval echo "~$usuario" 2>/dev/null || echo "/home/$usuario"
}

# Verifica disponibilidad y configuración de sudo
verificar_sudo() {
    command -v sudo >/dev/null 2>&1 || return 1
    sudo -n true 2>/dev/null
}

# Analiza qué tipo de escalado necesita una fase
analizar_requerimientos_fase() {
    local fase="$1"
    case "$fase" in
        "dependencias"|"permisos") echo "root" ;;
        "clusters"|"argocd"|"herramientas"|"aplicaciones") echo "user" ;;
        *) echo "user" ;;
    esac
}

# ============================================================================
# GESTIÓN DE ARGUMENTOS Y VARIABLES
# ============================================================================

# Preserva variables de entorno críticas
construir_env_vars() {
    local env_vars=""
    [[ "${VERBOSE:-false}" == "true" ]] && env_vars+=" VERBOSE=true"
    [[ "${DEBUG:-false}" == "true" ]] && env_vars+=" DEBUG=true"
    [[ "${DRY_RUN:-false}" == "true" ]] && env_vars+=" DRY_RUN=true"
    [[ -n "${LOG_FILE:-}" ]] && env_vars+=" LOG_FILE='$LOG_FILE'"
    [[ -n "${FASE_OBJETIVO:-}" ]] && env_vars+=" FASE_OBJETIVO='$FASE_OBJETIVO'"
    [[ -n "${INSTALLATION_MODE:-}" ]] && env_vars+=" INSTALLATION_MODE='$INSTALLATION_MODE'"
    echo "$env_vars"
}

# Construye argumentos preservando el contexto de ejecución
construir_argumentos() {
    local incluir_fase="${1:-true}"
    local args=""
    [[ "${VERBOSE:-false}" == "true" ]] && args+=" --verbose"
    [[ "${DEBUG:-false}" == "true" ]] && args+=" --debug"
    [[ "${DRY_RUN:-false}" == "true" ]] && args+=" --dry-run"
    [[ "${SOLO_DEV:-false}" == "true" ]] && args+=" --solo-dev"
    [[ -n "${LOG_FILE:-}" ]] && args+=" --log-file '$LOG_FILE'"
    
    if [[ "$incluir_fase" == "true" && "${INSTALLATION_MODE:-}" == "fase-individual" && -n "${FASE_OBJETIVO:-}" ]]; then
        args+=" fase-$FASE_OBJETIVO"
    fi
    
    echo "$args"
}

# ============================================================================
# ESCALADO/DESESCALADO AUTOMÁTICO
# ============================================================================

# Escala a usuario root cuando es necesario
escalar_a_root() {
    [[ "$EUID" -eq 0 ]] && return 0
    
    log_info "🔐 Detectado: Fase requiere privilegios sudo"
    log_info "🚀 SOLUCIÓN AUTOMÁTICA: Auto-escalando para instalación..."
    log_info "📋 Continuará automáticamente como usuario normal después"
    
    local args="$(construir_argumentos)"
    log_info "🔄 Re-ejecutando: sudo $0$args"
    
    exec sudo "$0" $args
}

# Desescala a usuario normal cuando es necesario
desescalar_a_usuario() {
    [[ "$EUID" -ne 0 ]] && return 0
    
    local usuario_real="$(obtener_usuario_real)"
    local home_real="$(obtener_home_real "$usuario_real")"
    
    log_warning "⚠️ Detectado: Ejecutándose como root pero fase necesita usuario normal"
    log_info "🔄 SOLUCIÓN AUTOMÁTICA: Re-ejecutando como usuario normal..."
    log_info "👤 Continuando como usuario: $usuario_real"
    log_info "🏠 Home directory: $home_real"
    
    # Ajustar permisos del repositorio si es necesario
    [[ "$(stat -c '%U' "$PROJECT_ROOT")" == "root" ]] && {
        log_info "🔧 Ajustando permisos del repositorio..."
        chown -R "$usuario_real:$usuario_real" "$PROJECT_ROOT" 2>/dev/null || true
    }
    
    local env_vars="$(construir_env_vars)"
    local args="$(construir_argumentos) --skip-deps"
    
    log_info "🚀 Re-ejecutando como usuario normal..."
    exec sudo -u "$usuario_real" -H bash -c "cd '$PROJECT_ROOT' &&$env_vars ./instalar.sh$args"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

# Gestiona automáticamente permisos según la fase
gestionar_permisos_automatico() {
    local fase_actual="$1"
    local requerimiento="$(analizar_requerimientos_fase "$fase_actual")"
    
    case "$requerimiento" in
        "root")
            [[ "$EUID" -ne 0 ]] && escalar_a_root
            ;;
        "user")
            [[ "$EUID" -eq 0 ]] && desescalar_a_usuario
            ;;
    esac
    
    return 0
}

# Verificar que el contexto actual es correcto para la fase
verificar_contexto_correcto() {
    local fase="$1"
    local requerimiento="$(analizar_requerimientos_fase "$fase")"
    
    case "$requerimiento" in
        "root")
            [[ "$EUID" -eq 0 ]] || return 1
            ;;
        "user")
            [[ "$EUID" -ne 0 ]] || return 1
            ;;
    esac
    
    return 0
}
