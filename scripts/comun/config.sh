#!/bin/bash

# ============================================================================
# MÓDULO DE CONFIGURACIÓN - Configuración centralizada del sistema GitOps
# ============================================================================
# Gestiona todas las variables de configuración del sistema de forma centralizada
# Usado por todos los módulos del sistema para evitar duplicación
# ============================================================================

# Evitar redefinición si ya está cargado
if [[ -z "${GITOPS_CONFIG_LOADED:-}" ]]; then
    readonly GITOPS_CONFIG_LOADED="true"

    # ============================================================================
    # CONFIGURACIÓN DEL PROYECTO
    # ============================================================================
    
    # Metadatos del proyecto
    readonly GITOPS_VERSION="3.0.0"
    readonly GITOPS_NAME="GitOps España Infrastructure"
    readonly GITOPS_DESCRIPTION="Instalador modular para infraestructura GitOps"
    
    # Directorios del proyecto (se configuran automáticamente)
    if [[ -z "${PROJECT_ROOT:-}" ]]; then
        if [[ -f "instalar.sh" ]]; then
            # Ejecutándose desde el directorio raíz
            readonly PROJECT_ROOT="$(pwd)"
        else
            # Ejecutándose desde subdirectorio
            readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        fi
    fi
    
    readonly SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
    readonly COMUN_DIR="${SCRIPTS_DIR}/comun"
    readonly FASES_DIR="${SCRIPTS_DIR}/fases"
    readonly LOGS_DIR="${PROJECT_ROOT}/logs"
    
    # ============================================================================
    # CONFIGURACIÓN DE CLUSTERS
    # ============================================================================
    
    # Cluster de desarrollo (capacidad completa)
    readonly CLUSTER_DEV_NAME="${CLUSTER_DEV_NAME:-gitops-dev}"
    readonly CLUSTER_DEV_CPUS="${CLUSTER_DEV_CPUS:-4}"
    readonly CLUSTER_DEV_MEMORY="${CLUSTER_DEV_MEMORY:-8192}"
    readonly CLUSTER_DEV_DISK="${CLUSTER_DEV_DISK:-40g}"
    
    # Cluster de preproducción (capacidad media)
    readonly CLUSTER_PRE_NAME="${CLUSTER_PRE_NAME:-gitops-pre}"
    readonly CLUSTER_PRE_CPUS="${CLUSTER_PRE_CPUS:-2}"
    readonly CLUSTER_PRE_MEMORY="${CLUSTER_PRE_MEMORY:-4096}"
    readonly CLUSTER_PRE_DISK="${CLUSTER_PRE_DISK:-20g}"
    
    # Cluster de producción (capacidad media)
    readonly CLUSTER_PRO_NAME="${CLUSTER_PRO_NAME:-gitops-pro}"
    readonly CLUSTER_PRO_CPUS="${CLUSTER_PRO_CPUS:-2}"
    readonly CLUSTER_PRO_MEMORY="${CLUSTER_PRO_MEMORY:-4096}"
    readonly CLUSTER_PRO_DISK="${CLUSTER_PRO_DISK:-20g}"
    
    # Proveedor de clusters
    readonly CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
    
    # ============================================================================
    # CONFIGURACIÓN DE ARGOCD
    # ============================================================================
    
    readonly ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
    readonly ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"
    readonly ARGOCD_ADMIN_USER="${ARGOCD_ADMIN_USER:-admin}"
    
    # ============================================================================
    # CONFIGURACIÓN DE LOGGING
    # ============================================================================
    
    # Crear directorio de logs si no existe
    mkdir -p "$LOGS_DIR" 2>/dev/null || true
    
    # Configuración de logging por defecto
    readonly DEFAULT_LOG_LEVEL="${LOG_LEVEL:-INFO}"
    readonly DEFAULT_LOG_FILE="${LOG_FILE:-${LOGS_DIR}/instalador-$(date +%Y%m%d-%H%M%S).log}"
    
    # ============================================================================
    # CONFIGURACIÓN DE COMPORTAMIENTO
    # ============================================================================
    
    # Comportamiento por defecto
    readonly DEFAULT_DRY_RUN="${DRY_RUN:-false}"
    readonly DEFAULT_VERBOSE="${VERBOSE:-false}"
    readonly DEFAULT_DEBUG="${DEBUG:-false}"
    readonly DEFAULT_SKIP_DEPS="${SKIP_DEPS:-false}"
    readonly DEFAULT_SOLO_DEV="${SOLO_DEV:-false}"
    readonly DEFAULT_TIMEOUT="${TIMEOUT_INSTALL:-600}"
    
    # ============================================================================
    # CONFIGURACIÓN DE FASES
    # ============================================================================
    
    # Lista de fases disponibles (orden de ejecución)
    readonly FASES_DISPONIBLES=(
        "fase-01-permisos.sh"
        "fase-02-dependencias.sh"
        "fase-03-clusters.sh"
        "fase-04-argocd.sh"
        "fase-05-herramientas.sh"
        "fase-06-aplicaciones.sh"
        "fase-07-finalizacion.sh"
    )
    
    # Mapeo de nombres de fases a números
    readonly -A FASE_NOMBRES=(
        ["01"]="Gestión de Permisos"
        ["02"]="Dependencias del Sistema"
        ["03"]="Docker y Clusters"
        ["04"]="Instalación ArgoCD"
        ["05"]="Herramientas GitOps"
        ["06"]="Aplicaciones Custom"
        ["07"]="Finalización y Accesos"
    )
    
    # ============================================================================
    # FUNCIONES DE CONFIGURACIÓN
    # ============================================================================
    
    # Inicializar configuración con valores por defecto
    inicializar_configuracion() {
        # Solo configurar si no están ya definidas
        export DRY_RUN="${DRY_RUN:-$DEFAULT_DRY_RUN}"
        export VERBOSE="${VERBOSE:-$DEFAULT_VERBOSE}"
        export DEBUG="${DEBUG:-$DEFAULT_DEBUG}"
        export SKIP_DEPS="${SKIP_DEPS:-$DEFAULT_SKIP_DEPS}"
        export SOLO_DEV="${SOLO_DEV:-$DEFAULT_SOLO_DEV}"
        export TIMEOUT_INSTALL="${TIMEOUT_INSTALL:-$DEFAULT_TIMEOUT}"
        export LOG_LEVEL="${LOG_LEVEL:-$DEFAULT_LOG_LEVEL}"
        export LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"
        
        # Configurar debug automáticamente si está habilitado
        if [[ "$DEBUG" == "true" ]]; then
            export VERBOSE="true"
            export LOG_LEVEL="DEBUG"
            set -x
        fi
        
        # Configurar verbose automáticamente si está habilitado
        if [[ "$VERBOSE" == "true" ]]; then
            export LOG_LEVEL="DEBUG"
            export SHOW_TIMESTAMP="true"
        fi
    }
    
    # Validar configuración
    validar_configuracion() {
        # Validar directorios
        if [[ ! -d "$SCRIPTS_DIR" ]]; then
            echo "❌ Error: Directorio de scripts no encontrado: $SCRIPTS_DIR" >&2
            return 1
        fi
        
        if [[ ! -d "$FASES_DIR" ]]; then
            echo "❌ Error: Directorio de fases no encontrado: $FASES_DIR" >&2
            return 1
        fi
        
        # Validar fases
        for fase in "${FASES_DISPONIBLES[@]}"; do
            if [[ ! -f "$FASES_DIR/$fase" ]]; then
                echo "❌ Error: Fase no encontrada: $FASES_DIR/$fase" >&2
                return 1
            fi
        done
        
        return 0
    }
    
    # Obtener información de configuración
    obtener_info_configuracion() {
        cat << EOF
📋 Configuración GitOps España v${GITOPS_VERSION}
├─ Proyecto: $PROJECT_ROOT
├─ Scripts: $SCRIPTS_DIR
├─ Fases: ${#FASES_DISPONIBLES[@]} módulos
├─ Logs: $LOGS_DIR
├─ Dry-run: $DRY_RUN
├─ Verbose: $VERBOSE
├─ Debug: $DEBUG
├─ Skip deps: $SKIP_DEPS
├─ Solo DEV: $SOLO_DEV
└─ Log file: $LOG_FILE
EOF
    }

fi
