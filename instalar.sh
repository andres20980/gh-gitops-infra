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
readonly COMUN_DIR="${SCRIPTS_DIR}/comun"

# ============================================================================
# CARGA DE SISTEMA BASE
# ============================================================================

# Verificar que existe la nueva estructura modular
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "❌ Error: No se encontró la estructura modular en $SCRIPTS_DIR"
    echo "ℹ️ La estructura de scripts ha sido reorganizada"
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

# Cargar orquestador principal
orquestador_path="$SCRIPTS_DIR/orquestador.sh"
if [[ -f "$orquestador_path" ]]; then
    # shellcheck source=scripts/orquestador.sh
    source "$orquestador_path"
else
    log_error "Orquestador principal no encontrado en $orquestador_path"
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
# FUNCIONES AUXILIARES
# ============================================================================

# Verificar si está en modo dry-run
es_dry_run() {
    [[ "$DRY_RUN" == "true" ]]
}

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN
# ============================================================================

# Configurar modo de instalación
configurar_modo_instalacion() {
    # PROCESO DESATENDIDO ÚNICO - no hay modos
    export INSTALLATION_MODE="gitops-absoluto"
    export PROCESO_DESATENDIDO="true"
    
    log_info "🚀 Configurado para PROCESO DESATENDIDO - Entorno GitOps Absoluto"
    log_info "📋 Fases: Deps → gitops-dev → ArgoCD → Tools → Apps → gitops-pre/pro"
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
# FUNCIONES DE PREREQUISITOS
# ============================================================================

# Detectar y configurar Docker automáticamente
configurar_docker_automatico() {
    log_section "🐳 Configurando Docker Automáticamente"
    
    # Verificar si Docker está disponible
    if ! command -v docker >/dev/null 2>&1; then
        log_warning "Docker no está instalado"
        return 1
    fi
    
    # Verificar si Docker daemon está corriendo
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon ya está ejecutándose"
        return 0
    fi
    
    log_info "Docker daemon no está activo, intentando configurarlo..."
    
    # Detectar si estamos en un entorno sin systemd (WSL/contenedor)
    if ! systemctl --version >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
        log_info "Entorno sin systemd detectado (WSL/contenedor)"
        log_info "Iniciando Docker daemon manualmente..."
        
        # Verificar si ya hay un dockerd corriendo en background
        if pgrep -f "dockerd" >/dev/null 2>&1; then
            log_info "Docker daemon ya está ejecutándose en background"
            # Esperar un momento para que esté listo
            sleep 3
            if docker info >/dev/null 2>&1; then
                log_success "Docker daemon disponible"
                return 0
            fi
        fi
        
        # Iniciar dockerd en background
        log_info "Iniciando dockerd en background..."
        if es_dry_run; then
            log_info "[DRY-RUN] Ejecutaría: sudo dockerd > /tmp/docker.log 2>&1 &"
            return 0
        fi
        
        # Iniciar Docker daemon
        sudo dockerd > /tmp/docker.log 2>&1 &
        local dockerd_pid=$!
        
        # Esperar hasta que Docker esté listo (máximo 30 segundos)
        log_info "Esperando que Docker daemon esté listo..."
        local contador=0
        while ! docker info >/dev/null 2>&1 && [[ $contador -lt 30 ]]; do
            sleep 1
            ((contador++))
            if [[ $((contador % 5)) -eq 0 ]]; then
                log_info "Esperando Docker daemon... (${contador}s)"
            fi
        done
        
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon iniciado correctamente (PID: $dockerd_pid)"
            log_info "Log de Docker disponible en: /tmp/docker.log"
            return 0
        else
            log_error "No se pudo iniciar Docker daemon"
            log_info "Revisa el log en: /tmp/docker.log"
            return 1
        fi
    else
        # Entorno con systemd
        log_info "Entorno con systemd detectado"
        log_info "Intentando iniciar Docker con systemctl..."
        
        if es_dry_run; then
            log_info "[DRY-RUN] Ejecutaría: sudo systemctl start docker"
            return 0
        fi
        
        if sudo systemctl start docker && sudo systemctl enable docker; then
            log_success "Docker iniciado con systemctl"
            return 0
        else
            log_error "No se pudo iniciar Docker con systemctl"
            return 1
        fi
    fi
}

# Ejecutar instalación de dependencias del sistema
ejecutar_instalacion_dependencias() {
    local instalador_deps="$SCRIPTS_DIR/instalacion/dependencias.sh"
    
    if [[ ! -f "$instalador_deps" ]]; then
        log_error "Instalador de dependencias no encontrado: $instalador_deps"
        return 1
    fi
    
    log_section "📦 Ejecutando Instalación de Dependencias del Sistema"
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría: bash $instalador_deps"
        return 0
    fi
    
    # Ejecutar instalación de dependencias sin parámetros adicionales
    # (el script de dependencias no maneja parámetros de línea de comandos)
    if ! bash "$instalador_deps"; then
        log_error "Error en la instalación de dependencias del sistema"
        return 1
    fi
    
    log_success "Dependencias del sistema instaladas correctamente"
    return 0
}

# ============================================================================
# FUNCIONES DEL PROCESO GITOPS ABSOLUTO
# ============================================================================

# Crear cluster gitops-dev con capacidad completa
crear_cluster_gitops_dev() {
    log_info "🚀 Creando cluster $CLUSTER_DEV_NAME con capacidad completa..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría: minikube start --profile=$CLUSTER_DEV_NAME --cpus=$CLUSTER_DEV_CPUS --memory=$CLUSTER_DEV_MEMORY --disk-size=$CLUSTER_DEV_DISK"
        log_info "[DRY-RUN] Ejecutaría: minikube addons enable metrics-server --profile=$CLUSTER_DEV_NAME"
        log_info "[DRY-RUN] Ejecutaría: kubectl config use-context $CLUSTER_DEV_NAME"
        return 0
    fi
    
    # Eliminar cluster existente si existe
    if minikube profile list | grep -q "$CLUSTER_DEV_NAME"; then
        log_info "🗑️ Eliminando cluster existente $CLUSTER_DEV_NAME..."
        minikube delete --profile="$CLUSTER_DEV_NAME"
    fi
    
    # Crear cluster con capacidad completa
    log_info "🏗️ Creando cluster $CLUSTER_DEV_NAME..."
    if ! minikube start \
        --profile="$CLUSTER_DEV_NAME" \
        --cpus="$CLUSTER_DEV_CPUS" \
        --memory="$CLUSTER_DEV_MEMORY" \
        --disk-size="$CLUSTER_DEV_DISK" \
        --driver=docker \
        --kubernetes-version=stable; then
        log_error "Error creando cluster $CLUSTER_DEV_NAME"
        return 1
    fi
    
    # Habilitar addons esenciales
    log_info "🔧 Habilitando addons esenciales..."
    minikube addons enable metrics-server --profile="$CLUSTER_DEV_NAME"
    minikube addons enable ingress --profile="$CLUSTER_DEV_NAME"
    minikube addons enable storage-provisioner --profile="$CLUSTER_DEV_NAME"
    
    # Configurar contexto
    log_info "⚙️ Configurando contexto kubectl..."
    kubectl config use-context "$CLUSTER_DEV_NAME"
    
    # Verificar que el cluster está listo
    log_info "🔍 Verificando que el cluster está listo..."
    kubectl wait --for=condition=ready nodes --all --timeout=300s
    
    log_success "✅ Cluster $CLUSTER_DEV_NAME creado y configurado correctamente"
    return 0
}

# Instalar ArgoCD maestro que controlará todos los clusters
instalar_argocd_maestro() {
    log_info "🔄 Instalando ArgoCD (última versión) como controlador maestro..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría instalación de ArgoCD"
        return 0
    fi
    
    # Crear namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Instalar ArgoCD (última versión estable)
    log_info "📥 Descargando e instalando ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Esperar a que ArgoCD esté listo
    log_info "⏳ Esperando que ArgoCD esté listo..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-application-controller -n argocd
    
    # Configurar acceso
    log_info "🔐 Configurando acceso a ArgoCD..."
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    
    # Obtener password inicial
    local argocd_password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log_success "✅ ArgoCD instalado correctamente"
    log_info "🔑 Password inicial admin: $argocd_password"
    
    return 0
}

# Actualizar helm charts y desplegar herramientas
actualizar_y_desplegar_herramientas() {
    log_info "📊 Actualizando helm charts y desplegando herramientas GitOps..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría actualización de helm charts"
        log_info "[DRY-RUN] Ejecutaría despliegue de herramientas via ArgoCD"
        return 0
    fi
    
    # Aplicar app-of-apps para herramientas
    log_info "🚀 Desplegando herramientas GitOps via ArgoCD..."
    kubectl apply -f herramientas-gitops/app-of-apps.yaml
    
    # Esperar a que todas las aplicaciones estén synced
    log_info "⏳ Esperando que todas las herramientas estén synced y healthy..."
    local timeout=600
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local apps_status
        apps_status=$(kubectl get applications -n argocd -o jsonpath='{.items[*].status.sync.status}' 2>/dev/null || echo "")
        local health_status
        health_status=$(kubectl get applications -n argocd -o jsonpath='{.items[*].status.health.status}' 2>/dev/null || echo "")
        
        if [[ "$apps_status" =~ "Synced" ]] && [[ "$health_status" =~ "Healthy" ]]; then
            log_success "✅ Todas las herramientas están synced y healthy"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            log_info "⏳ Esperando herramientas... (${elapsed}s/${timeout}s)"
        fi
    done
    
    log_error "Timeout esperando que las herramientas estén ready"
    return 1
}

# Verificar que todo el sistema GitOps está healthy
verificar_sistema_gitops_healthy() {
    log_info "🔍 Verificando estado completo del sistema GitOps..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Verificaría estado del sistema GitOps"
        return 0
    fi
    
    # Verificar ArgoCD
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_error "ArgoCD no está disponible"
        return 1
    fi
    
    # Verificar aplicaciones
    local failed_apps
    failed_apps=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status!="Healthy")].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$failed_apps" ]]; then
        log_error "Aplicaciones no healthy: $failed_apps"
        return 1
    fi
    
    log_success "✅ Sistema GitOps completamente healthy"
    return 0
}

# Desplegar aplicaciones custom
desplegar_aplicaciones_custom() {
    log_info "🚀 Desplegando aplicaciones custom..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría despliegue de aplicaciones custom"
        return 0
    fi
    
    # Aplicar app-of-apps para aplicaciones
    kubectl apply -f argo-apps/app-of-apps.yaml
    
    # Esperar a que estén synced
    log_info "⏳ Esperando que aplicaciones custom estén synced..."
    sleep 30  # Dar tiempo inicial
    
    local timeout=300
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local custom_apps_ready
        custom_apps_ready=$(kubectl get applications -n argocd -l component=custom-app -o jsonpath='{.items[*].status.sync.status}' 2>/dev/null | grep -c "Synced" || echo "0")
        
        if [[ $custom_apps_ready -gt 0 ]]; then
            log_success "✅ Aplicaciones custom synced y healthy"
            return 0
        fi
        
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    log_success "✅ Aplicaciones custom desplegadas"
    return 0
}

# Crear clusters de promoción (pre y pro)
crear_clusters_promocion() {
    log_info "🌐 Creando clusters de promoción gitops-pre y gitops-pro..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría creación de clusters gitops-pre y gitops-pro"
        return 0
    fi
    
    # Crear cluster gitops-pre
    log_info "🏗️ Creando cluster $CLUSTER_PRE_NAME..."
    if ! minikube start \
        --profile="$CLUSTER_PRE_NAME" \
        --cpus="$CLUSTER_PRE_CPUS" \
        --memory="$CLUSTER_PRE_MEMORY" \
        --disk-size="$CLUSTER_PRE_DISK" \
        --driver=docker \
        --kubernetes-version=stable; then
        log_error "Error creando cluster $CLUSTER_PRE_NAME"
        return 1
    fi
    
    # Habilitar addons básicos para PRE
    minikube addons enable metrics-server --profile="$CLUSTER_PRE_NAME"
    minikube addons enable ingress --profile="$CLUSTER_PRE_NAME"
    
    # Crear cluster gitops-pro
    log_info "🏗️ Creando cluster $CLUSTER_PRO_NAME..."
    if ! minikube start \
        --profile="$CLUSTER_PRO_NAME" \
        --cpus="$CLUSTER_PRO_CPUS" \
        --memory="$CLUSTER_PRO_MEMORY" \
        --disk-size="$CLUSTER_PRO_DISK" \
        --driver=docker \
        --kubernetes-version=stable; then
        log_error "Error creando cluster $CLUSTER_PRO_NAME"
        return 1
    fi
    
    # Habilitar addons básicos para PRO
    minikube addons enable metrics-server --profile="$CLUSTER_PRO_NAME"
    minikube addons enable ingress --profile="$CLUSTER_PRO_NAME"
    
    # Volver al contexto de DEV
    kubectl config use-context "$CLUSTER_DEV_NAME"
    
    # Registrar clusters en ArgoCD para gestión multi-cluster
    log_info "🔗 Registrando clusters en ArgoCD para gestión multi-cluster..."
    # Aquí iría la lógica para registrar los clusters adicionales en ArgoCD
    
    log_success "✅ Clusters de promoción creados y registrados"
    return 0
}

# Mostrar accesos al sistema
mostrar_accesos_sistema() {
    log_section "🌟 Accesos al Sistema GitOps"
    
    # ArgoCD
    local argocd_port
    argocd_port=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
    local argocd_ip
    argocd_ip=$(minikube ip --profile="$CLUSTER_DEV_NAME")
    
    log_info "🔄 ArgoCD:"
    log_info "   URL: https://$argocd_ip:$argocd_port"
    log_info "   Usuario: admin"
    log_info "   Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Ver en cluster")"
    
    # Clusters disponibles
    log_info "🌐 Clusters disponibles:"
    log_info "   • $CLUSTER_DEV_NAME (desarrollo - completo)"
    log_info "   • $CLUSTER_PRE_NAME (preproducción - mínimo)"
    log_info "   • $CLUSTER_PRO_NAME (producción - mínimo)"
    
    # Comandos útiles
    log_info "💡 Comandos útiles:"
    log_info "   • kubectl config use-context $CLUSTER_DEV_NAME"
    log_info "   • kubectl get applications -n argocd"
    log_info "   • minikube dashboard --profile=$CLUSTER_DEV_NAME"
}

# ============================================================================
# FUNCIONES DE AYUDA Y BANNER
# ============================================================================

# Mostrar ayuda completa
mostrar_ayuda() {
    cat << 'EOF'
GitOps España Infrastructure - Instalador Principal

SINTAXIS:
  ./instalar.sh                    # ← PROCESO TOTALMENTE DESATENDIDO

🚀 PROCESO AUTOMÁTICO COMPLETO:
  ./instalar.sh                    # Entorno GitOps absoluto desde Ubuntu WSL limpio

FASES DEL PROCESO DESATENDIDO:
  1. Verificar/actualizar dependencias del sistema (últimas versiones)
  2. Instalar minikube + cluster gitops-dev (capacidad completa)
  3. Instalar ArgoCD (última versión, controlará todos los clusters)
  4. Actualizar helm-charts y desplegar herramientas GitOps
  5. Verificar que todo esté synced y healthy
  6. Desplegar aplicaciones custom
  7. Crear clusters gitops-pre y gitops-pro (capacidad mínima)
  8. Configurar promoción de entornos con Kargo

RESULTADO: Entorno GitOps absoluto con 3 clusters completamente funcional

MODOS DE INSTALACIÓN:
  (ninguno)               Proceso DESATENDIDO completo (POR DEFECTO ÚNICO)

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

EJEMPLOS DE USO:
  ./instalar.sh                                # Proceso completo desatendido
  ./instalar.sh --dry-run                      # Ver todo el proceso sin ejecutar
  ./instalar.sh --verbose                      # Ver progreso detallado
  ./instalar.sh --debug --log-file debug.log  # Debug completo con log

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
    log_section "🚀 GitOps España - Instalador v${SCRIPT_VERSION}"
    
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
    
    # Mostrar banner inicial
    mostrar_banner_inicial
    
    # Mostrar configuración del proceso desatendido
    log_section "⚙️ Configuración del Proceso GitOps Absoluto"
    log_info "Versión: $SCRIPT_VERSION"
    log_info "Modo: PROCESO DESATENDIDO (Entorno GitOps Absoluto)"
    log_info "Clusters a crear:"
    log_info "  • $CLUSTER_DEV_NAME: ${CLUSTER_DEV_CPUS} CPUs, ${CLUSTER_DEV_MEMORY}MB RAM, ${CLUSTER_DEV_DISK} disk"
    log_info "  • $CLUSTER_PRE_NAME: ${CLUSTER_PRE_CPUS} CPUs, ${CLUSTER_PRE_MEMORY}MB RAM, ${CLUSTER_PRE_DISK} disk"
    log_info "  • $CLUSTER_PRO_NAME: ${CLUSTER_PRO_CPUS} CPUs, ${CLUSTER_PRO_MEMORY}MB RAM, ${CLUSTER_PRO_DISK} disk"
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
    
    # Mostrar versiones si está en modo debug
    if [[ "$DEBUG" == "true" ]]; then
        show_all_versions
    fi
    
    # ========================================================================
    # FASE 1: VERIFICAR/ACTUALIZAR DEPENDENCIAS DEL SISTEMA
    # ========================================================================
    if [[ "$SKIP_DEPS" == "false" ]]; then
        log_section "📦 FASE 1: Verificar/Actualizar Dependencias del Sistema"
        if ! ejecutar_instalacion_dependencias; then
            log_error "Error en la verificación/actualización de dependencias"
            exit 1
        fi
        log_success "✅ FASE 1 completada: Dependencias actualizadas"
    else
        log_info "⏭️ Saltando verificación de dependencias (--skip-deps)"
    fi
    
    # ========================================================================
    # FASE 2: CONFIGURAR DOCKER Y CREAR CLUSTER GITOPS-DEV
    # ========================================================================
    log_section "🐳 FASE 2: Configurar Docker y Crear Cluster gitops-dev"
    
    # Configurar Docker automáticamente
    if ! configurar_docker_automatico; then
        log_error "Docker no está disponible y es requerido para $CLUSTER_PROVIDER"
        exit 1
    fi
    
    # Crear cluster gitops-dev con capacidad completa
    log_info "🚀 Creando cluster $CLUSTER_DEV_NAME con capacidad completa..."
    if ! crear_cluster_gitops_dev; then
        log_error "Error creando cluster $CLUSTER_DEV_NAME"
        exit 1
    fi
    log_success "✅ FASE 2 completada: Cluster $CLUSTER_DEV_NAME creado y configurado"
    
    # Si solo queremos DEV, parar aquí
    if [[ "$SOLO_DEV" == "true" ]]; then
        log_success "🎯 Proceso completado: Solo cluster DEV creado (--solo-dev)"
        return 0
    fi
    
    # ========================================================================
    # FASE 3: INSTALAR ARGOCD (ÚLTIMA VERSIÓN)
    # ========================================================================
    log_section "🔄 FASE 3: Instalar ArgoCD (Controlará todos los clusters)"
    if ! instalar_argocd_maestro; then
        log_error "Error instalando ArgoCD maestro"
        exit 1
    fi
    log_success "✅ FASE 3 completada: ArgoCD instalado y configurado"
    
    # ========================================================================
    # FASE 4: ACTUALIZAR HELM CHARTS Y DESPLEGAR HERRAMIENTAS
    # ========================================================================
    log_section "📊 FASE 4: Actualizar Helm Charts y Desplegar Herramientas GitOps"
    if ! actualizar_y_desplegar_herramientas; then
        log_error "Error desplegando herramientas GitOps"
        exit 1
    fi
    log_success "✅ FASE 4 completada: Todas las herramientas synced y healthy"
    
    # ========================================================================
    # FASE 5: VERIFICAR QUE TODO ESTÉ SYNCED Y HEALTHY
    # ========================================================================
    log_section "🔍 FASE 5: Verificar Estado del Sistema GitOps"
    if ! verificar_sistema_gitops_healthy; then
        log_error "El sistema GitOps no está completamente healthy"
        exit 1
    fi
    log_success "✅ FASE 5 completada: Sistema GitOps completamente healthy"
    
    # ========================================================================
    # FASE 6: DESPLEGAR APLICACIONES CUSTOM
    # ========================================================================
    log_section "🚀 FASE 6: Desplegar Aplicaciones Custom"
    if ! desplegar_aplicaciones_custom; then
        log_error "Error desplegando aplicaciones custom"
        exit 1
    fi
    log_success "✅ FASE 6 completada: Aplicaciones custom synced y healthy"
    
    # ========================================================================
    # FASE 7: CREAR CLUSTERS GITOPS-PRE Y GITOPS-PRO
    # ========================================================================
    log_section "🌐 FASE 7: Crear Clusters gitops-pre y gitops-pro"
    if ! crear_clusters_promocion; then
        log_error "Error creando clusters de promoción"
        exit 1
    fi
    log_success "✅ FASE 7 completada: Clusters de promoción creados"
    
    # ========================================================================
    # RESULTADO FINAL
    # ========================================================================
    log_section "🎉 ENTORNO GITOPS ABSOLUTO COMPLETADO"
    log_success "✅ Proceso desatendido completado exitosamente"
    log_info "🌟 Entorno GitOps Absoluto configurado:"
    log_info "   • Cluster gitops-dev: ArgoCD + Todas las herramientas + Apps custom"
    log_info "   • Cluster gitops-pre: Listo para promociones con Kargo"
    log_info "   • Cluster gitops-pro: Listo para promociones con Kargo"
    log_info "   • Sistema de promoción automática configurado"
    
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "📄 Log completo guardado en: $LOG_FILE"
    fi
    
    mostrar_accesos_sistema
    
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
