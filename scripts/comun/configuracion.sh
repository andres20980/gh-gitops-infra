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
    readonly GITOPS_NAME="GitOps en Español Infrastructure"
    readonly GITOPS_DESCRIPTION="Instalador modular para infraestructura GitOps"
    
    # Directorios del proyecto (se configuran automáticamente)
    
    LOGS_DIR="${PROJECT_ROOT}/logs"
    
    # ============================================================================
    # CONFIGURACIÓN DE CLUSTERS
    # ============================================================================
    
    # Cluster de desarrollo (capacidad optimizada)
    readonly CLUSTER_DEV_NAME="${CLUSTER_DEV_NAME:-gitops-dev}"
    readonly CLUSTER_DEV_CPUS="${CLUSTER_DEV_CPUS:-4}"
    readonly CLUSTER_DEV_MEMORY="${CLUSTER_DEV_MEMORY:-4096}"
    readonly CLUSTER_DEV_DISK="${CLUSTER_DEV_DISK:-40g}"
    
    # Cluster de preproducción (capacidad media)
    readonly CLUSTER_PRE_NAME="${CLUSTER_PRE_NAME:-gitops-pre}"
    readonly CLUSTER_PRE_CPUS="${CLUSTER_PRE_CPUS:-2}"
    readonly CLUSTER_PRE_MEMORY="${CLUSTER_PRE_MEMORY:-2048}"
    readonly CLUSTER_PRE_DISK="${CLUSTER_PRE_DISK:-20g}"
    
    # Cluster de producción (capacidad media)
    readonly CLUSTER_PRO_NAME="${CLUSTER_PRO_NAME:-gitops-pro}"
    readonly CLUSTER_PRO_CPUS="${CLUSTER_PRO_CPUS:-2}"
    readonly CLUSTER_PRO_MEMORY="${CLUSTER_PRO_MEMORY:-2048}"
    readonly CLUSTER_PRO_DISK="${CLUSTER_PRO_DISK:-20g}"
    
    # Proveedor de clusters
    readonly CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
    
    # Configuración específica para WSL/Linux
    readonly MINIKUBE_EXTRA_ARGS="${MINIKUBE_EXTRA_ARGS:---extra-config=kubelet.cgroup-driver=systemd --extra-config=apiserver.service-node-port-range=30000-32767}"
    
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
    readonly GITOPS_MODE="${GITOPS_MODE:-online}"  # online|airgap
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
        "00-reset.sh"
        "01-permisos.sh"
        "02-dependencias.sh"
        "03-clusters.sh"
        "04-argocd.sh"
        "05-aplicaciones.sh"
        "06-finalizacion.sh"
    )
    
    # Mapeo de nombres de fases a números
    readonly -A FASE_NOMBRES=(
        ["00"]="Reset del Entorno"
        ["01"]="Gestión de Permisos"
        ["02"]="Dependencias del Sistema"
        ["03"]="Docker y Clusters"
        ["04"]="Instalación ArgoCD"
        ["05"]="Aplicaciones Custom"
        ["06"]="Finalización y Accesos"
    )
    
    # Estimaciones de tiempo por fase (en minutos)
    readonly -A FASE_TIEMPOS=(
        ["00"]="1"
        ["01"]="1-2"
        ["02"]="2-3"
        ["03"]="3-5"
        ["04"]="1-2"
        ["05"]="3-4"
        ["06"]="2-3"
    )
    
    # Dependencias de fases (qué fase debe completarse antes)
    readonly -A FASE_DEPENDENCIAS=(
        ["00"]=""           # Sin dependencias
        ["01"]="00"         # Requiere reset
        ["02"]="01"         # Requiere permisos
        ["03"]="02"         # Requiere dependencias
        ["04"]="03"         # Requiere clusters
        ["05"]="04"         # Requiere ArgoCD
        ["06"]="05"         # Requiere aplicaciones
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
📋 Configuración GitOps en Español v${GITOPS_VERSION}
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
    
    # Validar dependencias de fase
    validar_dependencia_fase() {
        local fase="$1"
        local dependencia="${FASE_DEPENDENCIAS[$fase]:-}"
        
        # Si no tiene dependencias, está OK
        if [[ -z "$dependencia" ]]; then
            return 0
        fi
        
        # Verificar si la fase dependiente fue completada
        local marca_completada="$LOGS_DIR/.fase-${dependencia}-completada"
        if [[ -f "$marca_completada" ]]; then
            return 0
        else
            echo "❌ ERROR: No puedes ejecutar la Fase $fase sin completar primero la Fase $dependencia"
            echo "💡 Solución: Ejecuta primero './instalar.sh fase-$dependencia'"
            return 1
        fi
    }
    
    # Marcar fase como completada
    marcar_fase_completada() {
        local fase="$1"
        local marca_completada="$LOGS_DIR/.fase-${fase}-completada"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Fase $fase completada exitosamente" > "$marca_completada"
    }
    
    # Obtener estimación de tiempo de fase
    obtener_estimacion_fase() {
        local fase="$1"
        echo "${FASE_TIEMPOS[$fase]:-?}"
    }
    
    # Mostrar información de fase con estimación
    mostrar_info_fase() {
        local fase="$1"
        local nombre="${FASE_NOMBRES[$fase]:-Desconocida}"
        local tiempo="${FASE_TIEMPOS[$fase]:-?}"
        local dependencia="${FASE_DEPENDENCIAS[$fase]:-}"
        
        echo "📊 FASE $fase: $nombre (⏱️ ~${tiempo}min)"
        if [[ -n "$dependencia" ]]; then
            echo "📋 Requiere: Fase $dependencia completada"
        fi
    }

fi
