#!/bin/bash

# ============================================================================
# INSTALADOR PRINCIPAL - GitOps España Infrastructure (Versión 2.4.0)
# ============================================================================
# Instalador principal optimizado y modular para infraestructura GitOps
# Orquestador inteligente que coordina todos los módulos especializados
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN GLOBAL
# ============================================================================

# Metadatos del script
readonly SCRIPT_VERSION="2.4.0"
readonly SCRIPT_NAME="GitOps España Instalador"
readonly SCRIPT_DESCRIPTION="Instalador principal para infraestructura GitOps"

# Directorios del proyecto
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
readonly BIBLIOTECAS_DIR="${SCRIPTS_DIR}/bibliotecas"
readonly NUCLEO_DIR="${SCRIPTS_DIR}/nucleo"

# ============================================================================
# CARGA DE SISTEMA BASE
# ============================================================================

# Cargar bibliotecas fundamentales
for lib in "base" "logging" "validacion" "versiones"; do
    lib_path="$BIBLIOTECAS_DIR/${lib}.sh"
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
    else
        echo "Error crítico: Biblioteca $lib no encontrada en $lib_path" >&2
        exit 1
    fi
done

# Cargar orquestador principal
orquestador_path="$NUCLEO_DIR/orchestrador.sh"
if [[ -f "$orquestador_path" ]]; then
    # shellcheck source=scripts/nucleo/orchestrador.sh
    source "$orquestador_path"
else
    log_error "Orquestador principal no encontrado en $orquestador_path"
    exit 1
fi

# ============================================================================
# CONFIGURACIÓN DE VARIABLES
# ============================================================================

# Control de flujo (con valores por defecto seguros)
export DRY_RUN="${DRY_RUN:-false}"
export VERBOSE="${VERBOSE:-false}"
export FORCE="${FORCE:-false}"
export INTERACTIVE="${INTERACTIVE:-true}"
export DEBUG="${DEBUG:-false}"

# Configuración del cluster
export CLUSTER_NAME="${CLUSTER_NAME:-gitops-dev}"
export CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
export CREATE_CLUSTER="${CREATE_CLUSTER:-false}"

# Configuración de componentes (granular)
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
# FUNCIONES DE CONFIGURACIÓN
# ============================================================================

# Configurar modo de instalación
configurar_modo_instalacion() {
    local modo="${1:-normal}"
    
    case "$modo" in
        "dependencies"|"desde-cero")
            export INSTALLATION_MODE="dependencies"
            export CREATE_CLUSTER="true"
            export SKIP_VALIDATION="false"
            log_info "Configurado para instalación desde cero con dependencias"
            ;;
        "solo-cluster")
            export INSTALLATION_MODE="solo-cluster"
            export CREATE_CLUSTER="true"
            log_info "Configurado para solo crear cluster"
            ;;
        "solo-gitops")
            export INSTALLATION_MODE="solo-gitops"
            log_info "Configurado para solo instalar GitOps core"
            ;;
        "solo-componentes")
            export INSTALLATION_MODE="solo-componentes"
            log_info "Configurado para solo instalar componentes"
            ;;
        "normal"|*)
            export INSTALLATION_MODE="normal"
            log_info "Configurado para instalación estándar"
            ;;
    esac
}

# Configurar logging avanzado
configurar_logging_instalador() {
    local nivel="${LOG_LEVEL:-INFO}"
    local archivo="${LOG_FILE:-/tmp/gitops-instalador-$(date +%Y%m%d-%H%M%S).log}"
    
    # Configurar sistema de logging
    configurar_logging "$nivel" "$archivo"
    
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
# FUNCIONES DE PREREQUISITOS
# ============================================================================

# Ejecutar instalación de dependencias del sistema
ejecutar_instalacion_dependencias() {
    local instalador_deps="$SCRIPTS_DIR/instaladores/dependencias.sh"
    
    if [[ ! -f "$instalador_deps" ]]; then
        log_error "Instalador de dependencias no encontrado: $instalador_deps"
        return 1
    fi
    
    log_section "📦 Ejecutando Instalación de Dependencias del Sistema"
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría: bash $instalador_deps"
        return 0
    fi
    
    # Ejecutar con los mismos parámetros de verbosidad
    local args=()
    [[ "$VERBOSE" == "true" ]] && args+=("--verbose")
    [[ "$DRY_RUN" == "true" ]] && args+=("--dry-run")
    [[ "$FORCE" == "true" ]] && args+=("--force")
    
    if ! bash "$instalador_deps" "${args[@]}"; then
        log_error "Error en la instalación de dependencias del sistema"
        return 1
    fi
    
    log_success "Dependencias del sistema instaladas correctamente"
    return 0
}

# ============================================================================
# FUNCIONES DE AYUDA Y BANNER
# ============================================================================

# Mostrar ayuda completa
mostrar_ayuda() {
    cat << 'EOF'
GitOps España Infrastructure - Instalador Principal

SINTAXIS:
  ./instalador.sh [MODO] [OPCIONES]

MODOS DE INSTALACIÓN:
  dependencies            Instalación completa desde Ubuntu limpio (26k dependencias)
  desde-cero              Instalación completa desde cero (incluye dependencias del sistema)
  solo-cluster            Solo crear/configurar cluster Kubernetes
  solo-gitops             Solo instalar ArgoCD y Kargo (core GitOps)
  solo-componentes        Solo instalar componentes adicionales
  normal                  Instalación estándar (por defecto)

OPCIONES PRINCIPALES:
  --crear-cluster         Crear nuevo cluster (destruye el existente)
  --proveedor TIPO        Proveedor del cluster: minikube, kind, existente
  --cluster-name NOMBRE   Nombre del cluster (por defecto: gitops-dev)

COMPONENTES (--sin-COMPONENTE para deshabilitar):
  --sin-argocd            No instalar ArgoCD
  --sin-kargo             No instalar Kargo
  --sin-ingress-nginx     No instalar Ingress NGINX
  --sin-cert-manager      No instalar Cert Manager
  --sin-prometheus        No instalar Prometheus Stack
  --sin-grafana           No instalar Grafana
  --sin-loki              No instalar Loki
  --sin-jaeger            No instalar Jaeger
  --sin-external-secrets  No instalar External Secrets
  --sin-minio             No instalar MinIO
  --sin-gitea             No instalar Gitea
  --sin-argo-workflows    No instalar Argo Workflows
  --sin-argo-events       No instalar Argo Events
  --sin-argo-rollouts     No instalar Argo Rollouts

CONTROL DE FLUJO:
  --dry-run               Mostrar qué se haría sin ejecutar comandos
  --verbose               Salida detallada y debug
  --debug                 Modo debug completo (muy detallado)
  --no-interactivo        No solicitar confirmación
  --force                 Forzar instalación incluso si ya existe
  --skip-validation       Omitir validación de prerequisitos

CONFIGURACIÓN:
  --timeout SEGUNDOS      Timeout para operaciones (por defecto: 600)
  --log-level NIVEL       Nivel de log: ERROR, WARNING, INFO, DEBUG, TRACE
  --log-file ARCHIVO      Archivo de log personalizado

EJEMPLOS DE USO:
  ./instalador.sh                                   # Instalación estándar
  ./instalador.sh desde-cero                        # Instalación completa desde cero
  ./instalador.sh solo-cluster --proveedor kind     # Solo crear cluster con Kind
  ./instalador.sh solo-gitops --dry-run             # Ver qué instalaría GitOps core
  ./instalador.sh --crear-cluster --verbose         # Recrear cluster con salida detallada
  ./instalador.sh --sin-kargo --sin-argo-workflows  # Sin Kargo ni Argo Workflows
  ./instalador.sh desde-cero --debug --log-file mi.log  # Desde cero con debug

VARIABLES DE ENTORNO:
  CLUSTER_NAME            Nombre del cluster
  CLUSTER_PROVIDER        Proveedor del cluster
  DRY_RUN                 Modo dry-run (true/false)
  VERBOSE                 Salida detallada (true/false)
  DEBUG                   Modo debug (true/false)
  LOG_LEVEL               Nivel de log
  INTERACTIVE             Modo interactivo (true/false)
  TIMEOUT_INSTALL         Timeout de instalación en segundos

INFORMACIÓN:
  Repositorio: https://github.com/andres20980/gh-gitops-infra
  Documentación: README.md
  Versión: 2.4.0
EOF
}

# Mostrar banner inicial mejorado
mostrar_banner_inicial() {
    clear
    mostrar_banner
    
    # Información adicional del sistema
    log_info "Sistema: $(uname -s) $(uname -m)"
    log_info "Usuario: $(usuario_actual)"
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
    local modo_instalacion="normal"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Modos de instalación
            desde-cero|--desde-cero|dependencies|--dependencies)
                modo_instalacion="dependencies"
                shift
                ;;
            solo-cluster|--solo-cluster)
                modo_instalacion="solo-cluster"
                shift
                ;;
            solo-gitops|--solo-gitops)
                modo_instalacion="solo-gitops"
                shift
                ;;
            solo-componentes|--solo-componentes)
                modo_instalacion="solo-componentes"
                shift
                ;;
            normal|--normal)
                modo_instalacion="normal"
                shift
                ;;
            
            # Configuración de cluster
            --crear-cluster)
                CREATE_CLUSTER="true"
                shift
                ;;
            --proveedor|--provider)
                CLUSTER_PROVIDER="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            
            # Componentes individuales
            --sin-argocd)
                INSTALL_ARGOCD="false"
                shift
                ;;
            --sin-kargo)
                INSTALL_KARGO="false"
                shift
                ;;
            --sin-ingress-nginx)
                INSTALL_INGRESS_NGINX="false"
                shift
                ;;
            --sin-cert-manager)
                INSTALL_CERT_MANAGER="false"
                shift
                ;;
            --sin-prometheus)
                INSTALL_PROMETHEUS_STACK="false"
                shift
                ;;
            --sin-grafana)
                INSTALL_GRAFANA="false"
                shift
                ;;
            --sin-loki)
                INSTALL_LOKI="false"
                shift
                ;;
            --sin-jaeger)
                INSTALL_JAEGER="false"
                shift
                ;;
            --sin-external-secrets)
                INSTALL_EXTERNAL_SECRETS="false"
                shift
                ;;
            --sin-minio)
                INSTALL_MINIO="false"
                shift
                ;;
            --sin-gitea)
                INSTALL_GITEA="false"
                shift
                ;;
            --sin-argo-workflows)
                INSTALL_ARGO_WORKFLOWS="false"
                shift
                ;;
            --sin-argo-events)
                INSTALL_ARGO_EVENTS="false"
                shift
                ;;
            --sin-argo-rollouts)
                INSTALL_ARGO_ROLLOUTS="false"
                shift
                ;;
            
            # Control de flujo
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
            --no-interactivo|--non-interactive)
                INTERACTIVE="false"
                export INTERACTIVE
                shift
                ;;
            --force)
                FORCE="true"
                export FORCE
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION="true"
                export SKIP_VALIDATION
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
            -*)
                log_error "Opción desconocida: $1"
                log_info "Usa --ayuda para ver las opciones disponibles"
                exit 1
                ;;
            
            # Argumentos posicionales (modos sin --)
            *)
                case "$1" in
                    dependencies|desde-cero|solo-cluster|solo-gitops|solo-componentes|normal)
                        modo_instalacion="$1"
                        ;;
                    *)
                        log_error "Argumento desconocido: $1"
                        exit 1
                        ;;
                esac
                shift
                ;;
        esac
    done
    
    # Configurar modo de instalación
    configurar_modo_instalacion "$modo_instalacion"
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
    
    # Mostrar banner inicial
    mostrar_banner_inicial
    
    # Mostrar configuración
    log_section "⚙️ Configuración del Instalador"
    log_info "Versión: $SCRIPT_VERSION"
    log_info "Modo de instalación: $INSTALLATION_MODE"
    log_info "Cluster: $CLUSTER_NAME ($CLUSTER_PROVIDER)"
    log_info "Crear cluster: $CREATE_CLUSTER"
    log_info "Dry-run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    log_info "Debug: $DEBUG"
    log_info "Interactivo: $INTERACTIVE"
    log_info "Log level: ${LOG_LEVEL:-INFO}"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "Log file: $LOG_FILE"
    fi
    echo
    
    # Mostrar versiones si está en modo debug
    if [[ "$DEBUG" == "true" ]]; then
        show_all_versions
    fi
    
    # Ejecutar instalación de dependencias del sistema si es desde-cero o dependencies
    if [[ "$INSTALLATION_MODE" == "dependencies" || "$INSTALLATION_MODE" == "desde-cero" ]]; then
        if ! ejecutar_instalacion_dependencias; then
            log_error "Error en la instalación de dependencias del sistema"
            exit 1
        fi
    fi
    
    # Confirmar ejecución si es interactivo y no dry-run
    if [[ "$INTERACTIVE" == "true" && "$DRY_RUN" == "false" ]]; then
        echo
        if ! confirmar "¿Continuar con la instalación GitOps?"; then
            log_info "Instalación cancelada por el usuario"
            exit 0
        fi
    fi
    
    # Ejecutar orquestador principal
    log_section "🚀 Iniciando Orquestador GitOps"
    
    if ! run_orchestrator "$INSTALLATION_MODE"; then
        log_error "Error en la orquestación GitOps"
        exit 1
    fi
    
    # Mensaje final
    log_success "Instalación completada exitosamente"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "Log completo guardado en: $LOG_FILE"
    fi
    
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
