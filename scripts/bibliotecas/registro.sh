#!/bin/bash

# ============================================================================
# LIBRERÍA DE REGISTRO Y LOGGING - Sistema de logs en castellano
# ============================================================================

# Variables de configuración de logging
NIVEL_LOG=${NIVEL_LOG:-"INFO"}
ARCHIVO_LOG="${ARCHIVO_LOG:-/tmp/instalador-gitops.log}"
LOG_CON_TIMESTAMP=${LOG_CON_TIMESTAMP:-true}
LOG_CON_COLOR=${LOG_CON_COLOR:-true}

# Alias para compatibilidad
LOG_LEVEL="$NIVEL_LOG"
LOG_FILE="$ARCHIVO_LOG"
LOG_WITH_TIMESTAMP="$LOG_CON_TIMESTAMP"
LOG_WITH_COLOR="$LOG_CON_COLOR"

# Importar colores de librería común si existe
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/comun.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/comun.sh"
else
    # Definir colores básicos si no hay librería común
    ROJO='\033[0;31m'
    VERDE='\033[0;32m'
    AMARILLO='\033[1;33m'
    AZUL='\033[0;34m'
    CIAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    SIN_COLOR='\033[0m'
fi

# Niveles de log con prioridades
declare -A PRIORIDADES_LOG=(
    ["DEBUG"]=0
    ["INFO"]=1
    ["WARNING"]=2
    ["ERROR"]=3
    ["CRITICAL"]=4
)

# Alias para compatibilidad
declare -A LOG_PRIORITIES
for key in "${!PRIORIDADES_LOG[@]}"; do
    LOG_PRIORITIES["$key"]="${PRIORIDADES_LOG[$key]}"
done

# Función para obtener timestamp
obtener_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Alias para compatibilidad
get_timestamp() { obtener_timestamp; }

# Función para verificar si debe logear según nivel
debe_logear() {
    local nivel_mensaje=$1
    local nivel_actual=${NIVEL_LOG:-"INFO"}
    
    local prioridad_mensaje=${PRIORIDADES_LOG[$nivel_mensaje]:-1}
    local prioridad_actual=${PRIORIDADES_LOG[$nivel_actual]:-1}
    
    [[ $prioridad_mensaje -ge $prioridad_actual ]]
}

# Alias para compatibilidad
should_log() { debe_logear "$@"; }

# Función base para escribir logs
escribir_log() {
    local nivel=$1
    local mensaje=$2
    local color=${3:-""}
    local icono=${4:-""}
    
    if ! debe_logear "$nivel"; then
        return 0
    fi
    
    local timestamp=""
    if [[ "$LOG_CON_TIMESTAMP" == "true" ]]; then
        timestamp="[$(obtener_timestamp)] "
    fi
    
    local prefijo_nivel="[$nivel]"
    local mensaje_completo="${timestamp}${prefijo_nivel} ${icono}${mensaje}"
    
    # Salida a consola con color
    if [[ "$LOG_CON_COLOR" == "true" && -n "$color" ]]; then
        echo -e "${color}${mensaje_completo}${SIN_COLOR}"
    else
        echo "$mensaje_completo"
    fi
    
    # Salida a archivo sin colores
    echo "${timestamp}${prefijo_nivel} ${mensaje}" >> "$ARCHIVO_LOG"
}

# Alias para compatibilidad
write_log() { escribir_log "$@"; }

# Función para log DEBUG
log_debug() {
    local mensaje="$1"
    escribir_log "DEBUG" "$mensaje" "$CIAN" "🔍 "
}

# Función para log INFO
log_info() {
    local mensaje="$1"
    escribir_log "INFO" "$mensaje" "$AZUL" "ℹ️  "
}

# Función para log WARNING
log_warning() {
    local mensaje="$1"
    escribir_log "WARNING" "$mensaje" "$AMARILLO" "⚠️  "
}

# Alias para compatibilidad
log_warn() { log_warning "$@"; }

# Función para log ERROR
log_error() {
    local mensaje="$1"
    escribir_log "ERROR" "$mensaje" "$ROJO" "❌ "
}

# Función para log CRITICAL
log_critical() {
    local mensaje="$1"
    escribir_log "CRITICAL" "$mensaje" "$MAGENTA" "🚨 "
}

# Función para log de éxito
log_exito() {
    local mensaje="$1"
    escribir_log "INFO" "$mensaje" "$VERDE" "✅ "
}

# Alias para compatibilidad
log_success() { log_exito "$@"; }

# Función para log de inicio de operación
log_inicio_operacion() {
    local operacion="$1"
    escribir_log "INFO" "Iniciando: $operacion" "$CIAN" "🚀 "
}

# Alias para compatibilidad
log_start_operation() { log_inicio_operacion "$@"; }

# Función para log de fin de operación
log_fin_operacion() {
    local operacion="$1"
    local resultado=${2:-"éxito"}
    
    if [[ "$resultado" == "éxito" || "$resultado" == "success" ]]; then
        escribir_log "INFO" "Completado: $operacion" "$VERDE" "🎉 "
    else
        escribir_log "ERROR" "Falló: $operacion - $resultado" "$ROJO" "💥 "
    fi
}

# Alias para compatibilidad
log_end_operation() { log_fin_operacion "$@"; }

# Función para log de progreso
log_progreso() {
    local paso_actual=$1
    local total_pasos=$2
    local descripcion="$3"
    
    local porcentaje=$((paso_actual * 100 / total_pasos))
    escribir_log "INFO" "Progreso: [$paso_actual/$total_pasos] ($porcentaje%) - $descripcion" "$AZUL" "📈 "
}

# Alias para compatibilidad
log_progress() { log_progreso "$@"; }

# Función para log de comando ejecutado
log_comando() {
    local comando="$1"
    local dry_run=${2:-false}
    
    if [[ "$dry_run" == "true" ]]; then
        escribir_log "DEBUG" "[DRY-RUN] Comando: $comando" "$CIAN" "🔧 "
    else
        escribir_log "DEBUG" "Ejecutando: $comando" "$AZUL" "🔧 "
    fi
}

# Alias para compatibilidad
log_command() { log_comando "$@"; }

# Función para log de componente
log_componente() {
    local accion="$1"
    local componente="$2"
    local estado=${3:-""}
    
    local mensaje="$accion componente: $componente"
    if [[ -n "$estado" ]]; then
        mensaje="$mensaje ($estado)"
    fi
    
    case "$accion" in
        "Instalando"|"Installing")
            escribir_log "INFO" "$mensaje" "$AZUL" "📦 "
            ;;
        "Configurando"|"Configuring")
            escribir_log "INFO" "$mensaje" "$AMARILLO" "⚙️  "
            ;;
        "Validando"|"Validating")
            escribir_log "INFO" "$mensaje" "$CIAN" "🔍 "
            ;;
        *)
            escribir_log "INFO" "$mensaje" "$AZUL" "🔧 "
            ;;
    esac
}

# Alias para compatibilidad
log_component() { log_componente "$@"; }

# Función para log de separador/sección
log_seccion() {
    local titulo="$1"
    local caracter=${2:-"="}
    
    local linea=""
    for ((i=1; i<=60; i++)); do
        linea="$linea$caracter"
    done
    
    escribir_log "INFO" "$linea" "$MAGENTA"
    escribir_log "INFO" " $titulo " "$MAGENTA" "📋 "
    escribir_log "INFO" "$linea" "$MAGENTA"
}

# Alias para compatibilidad
log_section() { log_seccion "$@"; }

# Función para log de estado del sistema
log_estado_sistema() {
    local componente="$1"
    local estado="$2"
    local detalle=${3:-""}
    
    case "$estado" in
        "activo"|"running"|"ready")
            local mensaje="$componente está activo"
            [[ -n "$detalle" ]] && mensaje="$mensaje ($detalle)"
            escribir_log "INFO" "$mensaje" "$VERDE" "✅ "
            ;;
        "inactivo"|"stopped"|"not ready")
            local mensaje="$componente está inactivo"
            [[ -n "$detalle" ]] && mensaje="$mensaje ($detalle)"
            escribir_log "WARNING" "$mensaje" "$AMARILLO" "⚠️  "
            ;;
        "error"|"failed")
            local mensaje="$componente en error"
            [[ -n "$detalle" ]] && mensaje="$mensaje ($detalle)"
            escribir_log "ERROR" "$mensaje" "$ROJO" "❌ "
            ;;
        *)
            local mensaje="$componente: $estado"
            [[ -n "$detalle" ]] && mensaje="$mensaje ($detalle)"
            escribir_log "INFO" "$mensaje" "$AZUL" "ℹ️  "
            ;;
    esac
}

# Alias para compatibilidad
log_system_status() { log_estado_sistema "$@"; }

# Función para configurar logging
configurar_logging() {
    local nivel=${1:-"INFO"}
    local archivo=${2:-"/tmp/instalador-gitops.log"}
    local con_timestamp=${3:-true}
    local con_color=${4:-true}
    
    NIVEL_LOG="$nivel"
    ARCHIVO_LOG="$archivo"
    LOG_CON_TIMESTAMP="$con_timestamp"
    LOG_CON_COLOR="$con_color"
    
    # Crear directorio del archivo de log si no existe
    local directorio_log=$(dirname "$archivo")
    mkdir -p "$directorio_log" 2>/dev/null || true
    
    # Inicializar archivo de log
    echo "$(obtener_timestamp) [INFO] Iniciando sesión de logging - Nivel: $nivel" > "$archivo"
    
    log_info "Sistema de logging configurado - Nivel: $nivel, Archivo: $archivo"
}

# Alias para compatibilidad
setup_logging() { configurar_logging "$@"; }

# Función para rotar logs si son muy grandes
rotar_logs() {
    local tamaño_maximo=${1:-10485760}  # 10MB por defecto
    
    if [[ -f "$ARCHIVO_LOG" ]]; then
        local tamaño_actual=$(stat -c%s "$ARCHIVO_LOG" 2>/dev/null || echo 0)
        
        if [[ $tamaño_actual -gt $tamaño_maximo ]]; then
            local archivo_backup="${ARCHIVO_LOG}.bak"
            mv "$ARCHIVO_LOG" "$archivo_backup" 2>/dev/null || true
            log_info "Log rotado: $archivo_backup"
        fi
    fi
}

# Alias para compatibilidad
rotate_logs() { rotar_logs "$@"; }

# Función para obtener resumen de logs
resumen_logs() {
    if [[ ! -f "$ARCHIVO_LOG" ]]; then
        echo "No existe archivo de log: $ARCHIVO_LOG"
        return 1
    fi
    
    echo -e "${AZUL}📊 Resumen del archivo de log: $ARCHIVO_LOG${SIN_COLOR}"
    echo -e "${AZUL}────────────────────────────────────────${SIN_COLOR}"
    
    local total_lineas=$(wc -l < "$ARCHIVO_LOG" 2>/dev/null || echo 0)
    local errores=$(grep -c "\[ERROR\]" "$ARCHIVO_LOG" 2>/dev/null || echo 0)
    local warnings=$(grep -c "\[WARNING\]" "$ARCHIVO_LOG" 2>/dev/null || echo 0)
    local info=$(grep -c "\[INFO\]" "$ARCHIVO_LOG" 2>/dev/null || echo 0)
    
    echo -e "${AZUL}Total de líneas: $total_lineas${SIN_COLOR}"
    echo -e "${VERDE}INFO: $info${SIN_COLOR}"
    echo -e "${AMARILLO}WARNING: $warnings${SIN_COLOR}"
    echo -e "${ROJO}ERROR: $errores${SIN_COLOR}"
    
    if [[ $errores -gt 0 ]]; then
        echo -e "${ROJO}❌ Últimos errores:${SIN_COLOR}"
        grep "\[ERROR\]" "$ARCHIVO_LOG" | tail -3
    fi
    
    if [[ $warnings -gt 0 ]]; then
        echo -e "${AMARILLO}⚠️  Últimos warnings:${SIN_COLOR}"
        grep "\[WARNING\]" "$ARCHIVO_LOG" | tail -3
    fi
}

# Alias para compatibilidad
log_summary() { resumen_logs; }

# Función para limpiar logs antiguos
limpiar_logs_antiguos() {
    local dias_antiguedad=${1:-7}  # 7 días por defecto
    
    local directorio_log=$(dirname "$ARCHIVO_LOG")
    
    find "$directorio_log" -name "*.log*" -type f -mtime +$dias_antiguedad -delete 2>/dev/null || true
    
    log_info "Logs antiguos limpiados (más de $dias_antiguedad días)"
}

# Alias para compatibilidad
cleanup_old_logs() { limpiar_logs_antiguos "$@"; }

# Función para exportar logs
exportar_logs() {
    local archivo_destino="$1"
    local filtro_nivel=${2:-"INFO"}
    
    if [[ ! -f "$ARCHIVO_LOG" ]]; then
        log_error "No existe archivo de log para exportar: $ARCHIVO_LOG"
        return 1
    fi
    
    if [[ -z "$archivo_destino" ]]; then
        archivo_destino="/tmp/logs-export-$(date +%Y%m%d-%H%M%S).log"
    fi
    
    # Filtrar por nivel si se especifica
    if [[ "$filtro_nivel" != "ALL" ]]; then
        grep "\[$filtro_nivel\]" "$ARCHIVO_LOG" > "$archivo_destino" 2>/dev/null || true
    else
        cp "$ARCHIVO_LOG" "$archivo_destino"
    fi
    
    log_info "Logs exportados a: $archivo_destino"
    echo "$archivo_destino"
}

# Alias para compatibilidad
export_logs() { exportar_logs "$@"; }
