#!/bin/bash

# ============================================================================
# INSTALADOR HELPER - Lógica de negocio del instalador
# ============================================================================
# Contiene toda la lógica de procesamiento, configuración y orquestación
# que estaba en el instalador principal (siguiendo DRY principles)
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN Y PROCESAMIENTO DE ARGUMENTOS
# ============================================================================

# Lista de fases disponibles
readonly FASES_DISPONIBLES=(
    "fase-01-permisos.sh"
    "fase-02-dependencias.sh"
    "fase-03-clusters.sh"
    "fase-04-argocd.sh"
    "fase-05-herramientas.sh"
    "fase-06-aplicaciones.sh"
    "fase-07-finalizacion.sh"
)

# Cargar todos los módulos de fases
cargar_modulos_fases() {
    log_info "📂 Cargando módulos por fases..."
    
    for fase in "${FASES_DISPONIBLES[@]}"; do
        local fase_path="$FASES_DIR/$fase"
        
        if [[ -f "$fase_path" ]]; then
            # shellcheck source=/dev/null
            source "$fase_path"
            log_debug "✅ Módulo cargado: $fase"
        else
            log_error "❌ Módulo de fase no encontrado: $fase_path"
            return 1
        fi
    done
    
    log_success "✅ Todos los módulos de fases cargados correctamente"
}

# Configurar modo de instalación
configurar_modo_instalacion() {
    export INSTALLATION_MODE="gitops-absoluto"
    export PROCESO_DESATENDIDO="true"
    
    log_info "🚀 Configurado para PROCESO DESATENDIDO - Entorno GitOps Absoluto"
    log_info "📋 Fases: Permisos → Deps → Clusters → ArgoCD → Tools → Apps → Finalización"
}

# Procesar argumentos de línea de comandos
procesar_argumentos() {
    # Establecer valores por defecto
    export DRY_RUN="${DRY_RUN:-false}"
    export VERBOSE="${VERBOSE:-false}"
    export DEBUG="${DEBUG:-false}"
    export SKIP_DEPS="${SKIP_DEPS:-false}"
    export SOLO_DEV="${SOLO_DEV:-false}"
    export SKIP_INTERACTIVE="${SKIP_INTERACTIVE:-false}"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="true"
                export DRY_RUN
                shift
                ;;
            --verbose)
                VERBOSE="true"
                export VERBOSE
                shift
                ;;
            --debug)
                DEBUG="true"
                VERBOSE="true"
                export DEBUG VERBOSE
                shift
                ;;
            --skip-deps)
                SKIP_DEPS="true"
                export SKIP_DEPS
                shift
                ;;
            --solo-dev)
                SOLO_DEV="true"
                export SOLO_DEV
                shift
                ;;
            --skip-interactive)
                SKIP_INTERACTIVE="true"
                export SKIP_INTERACTIVE
                shift
                ;;
            --timeout)
                TIMEOUT_INSTALL="$2"
                export TIMEOUT_INSTALL
                shift 2
                ;;
            --log-level)
                LOG_LEVEL="$2"
                export LOG_LEVEL
                shift 2
                ;;
            --log-file)
                LOG_FILE="$2"
                export LOG_FILE
                shift 2
                ;;
            *)
                log_error "Opción desconocida: $1"
                return 1
                ;;
        esac
    done
}

# ============================================================================
# FUNCIONES DE EJECUCIÓN
# ============================================================================

# Implementación de ejecución de fase individual
ejecutar_fase_individual_impl() {
    local fase="$1"
    shift || true
    
    # Procesar argumentos restantes
    procesar_argumentos "$@"
    
    # Configurar logging
    configurar_logging_instalador
    
    # Cargar módulos
    if ! cargar_modulos_fases; then
        log_error "Error cargando módulos de fases"
        return 1
    fi
    
    # Mostrar banner
    mostrar_banner_inicial
    
    log_section "🎯 EJECUCIÓN FASE INDIVIDUAL: $fase"
    
    # Mapear número de fase a función
    case "$fase" in
        "01"|"1")
            fase_01_permisos
            ;;
        "02"|"2")
            fase_02_dependencias
            ;;
        "03"|"3")
            fase_03_clusters
            ;;
        "04"|"4")
            fase_04_argocd
            ;;
        "05"|"5")
            fase_05_herramientas
            ;;
        "06"|"6")
            fase_06_aplicaciones
            ;;
        "07"|"7")
            fase_07_finalizacion
            ;;
        *)
            log_error "❌ Fase no reconocida: $fase"
            return 1
            ;;
    esac
}

# Implementación de ejecución de proceso completo
ejecutar_proceso_completo_impl() {
    # Procesar argumentos
    procesar_argumentos "$@"
    
    # Configurar logging
    configurar_logging_instalador
    
    # Cargar módulos
    if ! cargar_modulos_fases; then
        log_error "Error cargando módulos de fases"
        return 1
    fi
    
    # Mostrar banner
    mostrar_banner_inicial
    
    log_section "⚙️ Configuración del Proceso GitOps Absoluto Modular"
    log_info "Versión: $GITOPS_VERSION (Arquitectura Modular)"
    log_info "Modo: PROCESO DESATENDIDO (Entorno GitOps Absoluto)"
    
    # Ejecutar todas las fases en secuencia
    log_section "🔐 FASE 1: Gestión Inteligente de Permisos"
    fase_01_permisos
    
    log_section "📦 FASE 2: Verificar/Actualizar Dependencias del Sistema"
    fase_02_dependencias
    
    log_section "🐳 FASE 3: Configurar Docker y Crear Cluster gitops-dev"
    fase_03_clusters
    
    # Si solo queremos DEV, parar aquí
    if [[ "$SOLO_DEV" == "true" ]]; then
        log_success "🎯 Proceso completado: Solo cluster DEV creado (--solo-dev)"
        mostrar_accesos_sistema
        return 0
    fi
    
    log_section "🔄 FASE 4: Instalar ArgoCD"
    fase_04_argocd
    
    log_section "📊 FASE 5: Optimizar y Desplegar Herramientas GitOps"
    fase_05_herramientas
    
    log_section "🚀 FASE 6: Desplegar Aplicaciones Custom"
    fase_06_aplicaciones
    
    log_section "🌐 FASE 7: Finalización y Accesos"
    fase_07_finalizacion
    
    log_success "🎉 Proceso GitOps Absoluto completado exitosamente"
}

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

# Configurar logging avanzado
configurar_logging_instalador() {
    local nivel="${LOG_LEVEL:-INFO}"
    local archivo="${LOG_FILE:-${PROJECT_ROOT}/logs/instalador-$(date +%Y%m%d-%H%M%S).log}"
    
    # Crear directorio de logs si no existe
    mkdir -p "${PROJECT_ROOT}/logs"
    
    # Configurar variables de entorno para logging
    export LOG_LEVEL="$nivel"
    export LOG_FILE="$archivo"
    
    # Configurar debug si está habilitado
    if [[ "$DEBUG" == "true" ]]; then
        set -x
        export LOG_LEVEL="DEBUG"
    fi
    
    # Configurar verbose
    if [[ "$VERBOSE" == "true" ]]; then
        export LOG_LEVEL="DEBUG"
        export SHOW_TIMESTAMP="true"
    fi
}

# Mostrar banner inicial
mostrar_banner_inicial() {
    clear
    log_section "🚀 GitOps en Español - Instalador Modular v${GITOPS_VERSION}"
    
    # Información adicional del sistema
    log_info "Sistema: $(uname -s) $(uname -m)"
    log_info "Usuario: $(whoami)"
    if es_wsl; then
        log_info "Entorno: WSL detectado"
    fi
    echo
}

# Mostrar ayuda completa
mostrar_ayuda_completa() {
    cat << 'EOF'
GitOps en Español Infrastructure - Instalador Principal Modular v3.0.0

SINTAXIS:
  ./instalar.sh [COMANDO] [OPCIONES]

🚀 PROCESO AUTOMÁTICO COMPLETO:
  ./instalar.sh                    # Entorno GitOps absoluto desde Ubuntu WSL limpio
  ./instalar.sh completo           # Mismo que arriba (explícito)

🎯 EJECUCIÓN POR FASES INDIVIDUALES:
  ./instalar.sh fase-01            # Solo gestión inteligente de permisos
  ./instalar.sh fase-02            # Solo verificar/actualizar dependencias
  ./instalar.sh fase-03            # Solo configurar Docker + clusters
  ./instalar.sh fase-04            # Solo instalar ArgoCD
  ./instalar.sh fase-05            # Solo desplegar herramientas GitOps
  ./instalar.sh fase-06            # Solo desplegar aplicaciones custom
  ./instalar.sh fase-07            # Solo finalización + accesos

OPCIONES:
  --dry-run               Mostrar qué se haría sin ejecutar comandos
  --verbose               Salida detallada y debug  
  --debug                 Modo debug completo (muy detallado)
  --skip-deps             Saltar verificación de dependencias
  --solo-dev              Solo crear cluster gitops-dev
  --skip-interactive      Sin pausas interactivas
  --timeout SEGUNDOS      Timeout para operaciones
  --log-level NIVEL       Nivel de log: ERROR, WARNING, INFO, DEBUG
  --log-file ARCHIVO      Archivo de log personalizado

EJEMPLOS:
  ./instalar.sh                           # Proceso completo desatendido
  ./instalar.sh --dry-run                 # Ver todo sin ejecutar
  ./instalar.sh fase-03 --verbose         # Solo clusters con detalle
  ./instalar.sh --solo-dev --skip-deps   # Solo DEV sin dependencias

INFORMACIÓN:
  Repositorio: https://github.com/andres20980/gh-gitops-infra
  Versión: 3.0.0 (Arquitectura Modular Optimizada)
EOF
}
