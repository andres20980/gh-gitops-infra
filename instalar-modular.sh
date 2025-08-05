#!/bin/bash

# ============================================================================
# INSTALADOR PRINCIPAL MODULAR - GitOps España Infrastructure (Versión 3.0.0)
# ============================================================================
# Instalador principal optimizado y modular para infraestructura GitOps
# Orquestador inteligente con arquitectura por fases
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN GLOBAL
# ============================================================================

# Metadatos del script
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="GitOps España Instalador Modular"
readonly SCRIPT_DESCRIPTION="Instalador principal modular para infraestructura GitOps"

# Directorios del proyecto
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
readonly COMUN_DIR="${SCRIPTS_DIR}/comun"
readonly FASES_DIR="${SCRIPTS_DIR}/fases"

# ============================================================================
# CARGA DE SISTEMA BASE
# ============================================================================

# Verificar que existe la nueva estructura modular
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "❌ Error: No se encontró la estructura modular en $SCRIPTS_DIR"
    exit 1
fi

# Cargar módulos comunes
base_path="$COMUN_DIR/base.sh"
if [[ -f "$base_path" ]]; then
    # shellcheck source=scripts/comun/base.sh
    source "$base_path"
else
    echo "❌ Error: Módulo base no encontrado en $base_path" >&2
    exit 1
fi

# ============================================================================
# CONFIGURACIÓN DE VARIABLES
# ============================================================================

# Control de flujo (PROCESO DESATENDIDO por defecto)
export DRY_RUN="${DRY_RUN:-false}"
export VERBOSE="${VERBOSE:-true}"    # VERBOSE SIEMPRE por defecto
export INTERACTIVE="${INTERACTIVE:-false}"  # NO INTERACTIVO por defecto
export DEBUG="${DEBUG:-false}"
export SKIP_DEPS="${SKIP_DEPS:-false}"
export SOLO_DEV="${SOLO_DEV:-false}"
export FORCE="${FORCE:-false}"

# Configuración del proceso GitOps (MÚLTIPLES CLUSTERS)
export CLUSTER_DEV_NAME="${CLUSTER_DEV_NAME:-gitops-dev}"
export CLUSTER_PRE_NAME="${CLUSTER_PRE_NAME:-gitops-pre}"  
export CLUSTER_PRO_NAME="${CLUSTER_PRO_NAME:-gitops-pro}"
export CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"

# Capacidades de clusters
export CLUSTER_DEV_CPUS="${CLUSTER_DEV_CPUS:-4}"
export CLUSTER_DEV_MEMORY="${CLUSTER_DEV_MEMORY:-8192}"
export CLUSTER_DEV_DISK="${CLUSTER_DEV_DISK:-40g}"

export CLUSTER_PRE_CPUS="${CLUSTER_PRE_CPUS:-2}"
export CLUSTER_PRE_MEMORY="${CLUSTER_PRE_MEMORY:-4096}"
export CLUSTER_PRE_DISK="${CLUSTER_PRE_DISK:-20g}"

export CLUSTER_PRO_CPUS="${CLUSTER_PRO_CPUS:-2}"
export CLUSTER_PRO_MEMORY="${CLUSTER_PRO_MEMORY:-4096}"
export CLUSTER_PRO_DISK="${CLUSTER_PRO_DISK:-20g}"

# Configuración de componentes (TODO HABILITADO para entorno completo)
export INSTALL_ARGOCD="${INSTALL_ARGOCD:-true}"
export INSTALL_KARGO="${INSTALL_KARGO:-true}"
export INSTALL_INGRESS_NGINX="${INSTALL_INGRESS_NGINX:-true}"
export INSTALL_CERT_MANAGER="${INSTALL_CERT_MANAGER:-true}"
export INSTALL_PROMETHEUS_STACK="${INSTALL_PROMETHEUS_STACK:-true}"
export INSTALL_GRAFANA="${INSTALL_GRAFANA:-true}"
export INSTALL_LOKI="${INSTALL_LOKI:-true}"
export INSTALL_JAEGER="${INSTALL_JAEGER:-true}"
export INSTALL_EXTERNAL_SECRETS="${INSTALL_EXTERNAL_SECRETS:-true}"
export INSTALL_MINIO="${INSTALL_MINIO:-true}"
export INSTALL_GITEA="${INSTALL_GITEA:-true}"
export INSTALL_ARGO_WORKFLOWS="${INSTALL_ARGO_WORKFLOWS:-true}"
export INSTALL_ARGO_EVENTS="${INSTALL_ARGO_EVENTS:-true}"
export INSTALL_ARGO_ROLLOUTS="${INSTALL_ARGO_ROLLOUTS:-true}"

# Timeouts y configuración avanzada
export TIMEOUT_INSTALL="${TIMEOUT_INSTALL:-600}"
export TIMEOUT_READY="${TIMEOUT_READY:-300}"
export TIMEOUT_DELETE="${TIMEOUT_DELETE:-120}"

# ============================================================================
# CARGA DE MÓDULOS POR FASES
# ============================================================================

# Lista de fases en orden de ejecución
readonly FASES=(
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
    
    for fase in "${FASES[@]}"; do
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

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

# Verificar si está en modo dry-run
es_dry_run() {
    [[ "$DRY_RUN" == "true" ]]
}

# Configurar modo de instalación
configurar_modo_instalacion() {
    # PROCESO DESATENDIDO ÚNICO - no hay modos
    export INSTALLATION_MODE="gitops-absoluto"
    export PROCESO_DESATENDIDO="true"
    
    log_info "🚀 Configurado para PROCESO DESATENDIDO - Entorno GitOps Absoluto"
    log_info "📋 Fases: Permisos → Deps → Clusters → ArgoCD → Tools → Apps → Finalización"
}

# Configurar logging avanzado
configurar_logging_instalador() {
    local nivel="${LOG_LEVEL:-INFO}"
    local archivo="${LOG_FILE:-/tmp/gitops-instalador-$(date +%Y%m%d-%H%M%S).log}"
    
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

# ============================================================================
# FUNCIONES DE AYUDA Y BANNER
# ============================================================================

# Mostrar ayuda completa
mostrar_ayuda() {
    cat << 'EOF'
GitOps España Infrastructure - Instalador Principal Modular v3.0.0

SINTAXIS:
  ./instalar.sh                    # ← PROCESO TOTALMENTE DESATENDIDO

🚀 PROCESO AUTOMÁTICO COMPLETO:
  ./instalar.sh                    # Entorno GitOps absoluto desde Ubuntu WSL limpio

FASES DEL PROCESO DESATENDIDO:
  1. Gestión inteligente de permisos (auto-escalation/de-escalation)
  2. Verificar/actualizar dependencias del sistema (últimas versiones)
  3. Configurar Docker + cluster gitops-dev (capacidad completa)
  4. Instalar ArgoCD (última versión, controlará todos los clusters)
  5. Actualizar helm-charts y desplegar herramientas GitOps
  6. Desplegar aplicaciones custom con integración completa
  7. Crear clusters gitops-pre y gitops-pro + mostrar accesos

RESULTADO: Entorno GitOps absoluto con 3 clusters completamente funcional

OPCIONES DE DEBUG/TESTING:
  --dry-run               Mostrar qué se haría sin ejecutar comandos
  --verbose               Salida detallada y debug  
  --debug                 Modo debug completo (muy detallado)
  --skip-deps             Saltar verificación de dependencias (solo testing)
  --solo-dev              Solo crear cluster gitops-dev (testing)

CONFIGURACIÓN AVANZADA:
  --timeout SEGUNDOS      Timeout para operaciones (por defecto: 600)
  --log-level NIVEL       Nivel de log: ERROR, WARNING, INFO, DEBUG, TRACE
  --log-file ARCHIVO      Archivo de log personalizado

ARQUITECTURA MODULAR:
  scripts/fases/fase-01-permisos.sh      - Gestión inteligente de permisos
  scripts/fases/fase-02-dependencias.sh  - Dependencias del sistema
  scripts/fases/fase-03-clusters.sh      - Docker y clusters Kubernetes
  scripts/fases/fase-04-argocd.sh        - Instalación de ArgoCD
  scripts/fases/fase-05-herramientas.sh  - Herramientas GitOps
  scripts/fases/fase-06-aplicaciones.sh  - Aplicaciones custom
  scripts/fases/fase-07-finalizacion.sh  - Información final y accesos

EJEMPLOS DE USO:
  ./instalar.sh                                # Proceso completo desatendido
  ./instalar.sh --dry-run                      # Ver todo el proceso sin ejecutar
  ./instalar.sh --verbose                      # Ver progreso detallado
  ./instalar.sh --debug --log-file debug.log  # Debug completo con log

INFORMACIÓN:
  Repositorio: https://github.com/andres20980/gh-gitops-infra
  Documentación: README.md
  Versión: 3.0.0 (Arquitectura Modular)
EOF
}

# Mostrar banner inicial mejorado
mostrar_banner_inicial() {
    clear
    log_section "🚀 GitOps España - Instalador Modular v${SCRIPT_VERSION}"
    
    # Información adicional del sistema
    log_info "Sistema: $(uname -s) $(uname -m)"
    log_info "Usuario: $(whoami)"
    if es_wsl; then
        log_info "Entorno: WSL detectado"
    fi
    echo
}

# ============================================================================
# PROCESAMIENTO DE ARGUMENTOS AVANZADO
# ============================================================================

# Procesar argumentos de línea de comandos
procesar_argumentos() {
    # Si no hay argumentos, usar proceso desatendido
    if [[ $# -eq 0 ]]; then
        configurar_modo_instalacion
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Opciones de debug/testing
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
            
            # Configuración
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
            
            # Ayuda
            --ayuda|--help|-h)
                mostrar_ayuda
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            
            # Opciones desconocidas
            *)
                log_error "Opción desconocida: $1"
                log_info "Usa --ayuda para ver las opciones disponibles"
                exit 1
                ;;
        esac
    done
    
    # Configurar modo de instalación (siempre desatendido)
    configurar_modo_instalacion
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

# Función principal optimizada
main() {
    # Procesar argumentos primero (para configurar logging)
    procesar_argumentos "$@"
    
    # Configurar logging con parámetros procesados
    configurar_logging_instalador
    
    # Cargar módulos de fases
    if ! cargar_modulos_fases; then
        log_error "Error cargando módulos de fases"
        exit 1
    fi
    
    # Mostrar banner inicial
    mostrar_banner_inicial
    
    # Mostrar configuración del proceso desatendido
    log_section "⚙️ Configuración del Proceso GitOps Absoluto Modular"
    log_info "Versión: $SCRIPT_VERSION (Arquitectura Modular)"
    log_info "Modo: PROCESO DESATENDIDO (Entorno GitOps Absoluto)"
    log_info "Clusters a crear:"
    log_info "  • $CLUSTER_DEV_NAME: ${CLUSTER_DEV_CPUS} CPUs, ${CLUSTER_DEV_MEMORY}MB RAM, ${CLUSTER_DEV_DISK} disk"
    if [[ "$SOLO_DEV" != "true" ]]; then
        log_info "  • $CLUSTER_PRE_NAME: ${CLUSTER_PRE_CPUS} CPUs, ${CLUSTER_PRE_MEMORY}MB RAM, ${CLUSTER_PRE_DISK} disk"
        log_info "  • $CLUSTER_PRO_NAME: ${CLUSTER_PRO_CPUS} CPUs, ${CLUSTER_PRO_MEMORY}MB RAM, ${CLUSTER_PRO_DISK} disk"
    fi
    log_info "Proveedor: $CLUSTER_PROVIDER"
    log_info "Proceso desatendido: $PROCESO_DESATENDIDO"
    log_info "Skip dependencias: $SKIP_DEPS"
    log_info "Solo DEV: $SOLO_DEV"
    log_info "Dry-run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    log_info "Debug: $DEBUG"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "Log file: $LOG_FILE"
    fi
    echo
    
    # ========================================================================
    # FASE 1: GESTIÓN INTELIGENTE DE PERMISOS
    # ========================================================================
    log_section "🔐 FASE 1: Gestión Inteligente de Permisos"
    if [[ "$SKIP_DEPS" == "false" ]]; then
        gestionar_permisos_inteligente "dependencias"
    else
        gestionar_permisos_inteligente "clusters"
    fi
    log_success "✅ FASE 1 completada: Permisos configurados correctamente"
    
    # ========================================================================
    # FASE 2: VERIFICAR/ACTUALIZAR DEPENDENCIAS DEL SISTEMA
    # ========================================================================
    if [[ "$SKIP_DEPS" == "false" ]]; then
        log_section "📦 FASE 2: Verificar/Actualizar Dependencias del Sistema"
        if ! ejecutar_instalacion_dependencias; then
            log_error "Error en la verificación/actualización de dependencias"
            exit 1
        fi
        log_success "✅ FASE 2 completada: Dependencias actualizadas"
    else
        log_section "📦 FASE 2: Verificar Dependencias Críticas (--skip-deps)"
        if ! verificar_dependencias_criticas; then
            log_error "Faltan dependencias críticas"
            exit 1
        fi
        log_success "✅ FASE 2 completada: Dependencias verificadas"
    fi
    
    # ========================================================================
    # FASE 3: CONFIGURAR DOCKER Y CREAR CLUSTER GITOPS-DEV
    # ========================================================================
    log_section "🐳 FASE 3: Configurar Docker y Crear Cluster gitops-dev"
    
    # Configurar Docker automáticamente
    if ! configurar_docker_automatico; then
        log_error "Docker no está disponible y es requerido para $CLUSTER_PROVIDER"
        exit 1
    fi
    
    # Crear cluster gitops-dev con capacidad completa
    if ! crear_cluster_gitops_dev; then
        log_error "Error creando cluster $CLUSTER_DEV_NAME"
        exit 1
    fi
    log_success "✅ FASE 3 completada: Cluster $CLUSTER_DEV_NAME creado y configurado"
    
    # Si solo queremos DEV, parar aquí
    if [[ "$SOLO_DEV" == "true" ]]; then
        log_success "🎯 Proceso completado: Solo cluster DEV creado (--solo-dev)"
        mostrar_accesos_sistema
        return 0
    fi
    
    # ========================================================================
    # FASE 4: INSTALAR ARGOCD (ÚLTIMA VERSIÓN)
    # ========================================================================
    log_section "🔄 FASE 4: Instalar ArgoCD (Controlará todos los clusters)"
    if ! instalar_argocd_maestro; then
        log_error "Error instalando ArgoCD maestro"
        exit 1
    fi
    
    if ! verificar_argocd_healthy; then
        log_error "ArgoCD no está healthy"
        exit 1
    fi
    log_success "✅ FASE 4 completada: ArgoCD instalado y configurado"
    
    # ========================================================================
    # FASE 5: OPTIMIZAR Y DESPLEGAR HERRAMIENTAS GITOPS
    # ========================================================================
    log_section "📊 FASE 5: Optimizar Configuraciones y Desplegar Herramientas GitOps"
    if ! actualizar_y_desplegar_herramientas; then
        log_error "Error desplegando herramientas GitOps"
        exit 1
    fi
    log_success "✅ FASE 5 completada: Herramientas optimizadas y desplegadas"
    
    # ========================================================================
    # FASE 6: DESPLEGAR APLICACIONES CUSTOM
    # ========================================================================
    log_section "🚀 FASE 6: Desplegar Aplicaciones Custom"
    if ! desplegar_aplicaciones_custom; then
        log_error "Error desplegando aplicaciones custom"
        exit 1
    fi
    log_success "✅ FASE 6 completada: Aplicaciones custom desplegadas"
    
    # ========================================================================
    # FASE 7: CREAR CLUSTERS DE PROMOCIÓN Y MOSTRAR INFORMACIÓN FINAL
    # ========================================================================
    log_section "🌐 FASE 7: Crear Clusters de Promoción y Finalización"
    if ! crear_clusters_promocion; then
        log_error "Error creando clusters de promoción"
        exit 1
    fi
    
    # Mostrar información final
    mostrar_resumen_final
    log_success "✅ FASE 7 completada: Clusters de promoción creados"
    
    return 0
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Ejecutar función principal con manejo de errores
if ! main "$@"; then
    log_error "Instalación falló"
    exit 1
fi
