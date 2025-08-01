#!/bin/bash

# ============================================================================
# LIBRERÍA COMÚN - Funciones y variables compartidas en castellano
# ============================================================================

# Configuración de colores para output
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
MAGENTA='\033[0;35m'
SIN_COLOR='\033[0m'

# Aliases para compatibilidad
RED="$ROJO"
GREEN="$VERDE"
YELLOW="$AMARILLO"
BLUE="$AZUL"
CYAN="$CIAN"
NC="$SIN_COLOR"

# Configuración para instalación desatendida
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a
export ARGOCD_OPTS="--plaintext --grpc-web"
export MINIKUBE_IN_STYLE=false

# Configuración de clusters
CLUSTER_DESARROLLO="gitops-dev"
CLUSTER_PREPRODUCCION="gitops-pre"
CLUSTER_PRODUCCION="gitops-pro"

# Aliases para compatibilidad
CLUSTER_DEV="$CLUSTER_DESARROLLO"
CLUSTER_PRE="$CLUSTER_PREPRODUCCION"
CLUSTER_PRO="$CLUSTER_PRODUCCION"

# Configuración de namespaces
NAMESPACE_ARGOCD="argocd"
NAMESPACE_KARGO="kargo-system"
NAMESPACE_MONITORIZACION="monitoring"
NAMESPACE_INGRESS="ingress-nginx"
NAMESPACE_CERT_MANAGER="cert-manager"
NAMESPACE_EXTERNAL_SECRETS="external-secrets"

# Configuración de versiones de componentes
declare -A VERSIONES_COMPONENTES=(
    ["argocd"]="3.0.12"
    ["kargo"]="1.6.2"
    ["prometheus-stack"]="75.15.1"
    ["grafana"]="9.3.0"
    ["loki"]="6.8.0"
    ["jaeger"]="3.4.1"
    ["argo-events"]="2.4.8"
    ["argo-workflows"]="0.45.21"
    ["argo-rollouts"]="2.40.2"
    ["ingress-nginx"]="4.13.0"
    ["cert-manager"]="1.18.2"
    ["external-secrets"]="0.18.2"
    ["minio"]="5.2.0"
    ["gitea"]="12.1.2"
)

# Alias para compatibilidad
declare -A COMPONENT_VERSIONS
for key in "${!VERSIONES_COMPONENTES[@]}"; do
    COMPONENT_VERSIONS["$key"]="${VERSIONES_COMPONENTES[$key]}"
done

# Configuración de repositorios Helm
declare -A REPOSITORIOS_HELM=(
    ["argo"]="https://argoproj.github.io/argo-helm"
    ["akuity"]="https://charts.akuity.io"
    ["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
    ["grafana"]="https://grafana.github.io/helm-charts"
    ["jaegertracing"]="https://jaegertracing.github.io/helm-charts"
    ["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx"
    ["jetstack"]="https://charts.jetstack.io"
    ["external-secrets"]="https://charts.external-secrets.io"
    ["minio"]="https://charts.min.io/"
    ["gitea-charts"]="https://dl.gitea.io/charts/"
)

# Alias para compatibilidad
declare -A HELM_REPOS
for key in "${!REPOSITORIOS_HELM[@]}"; do
    HELM_REPOS["$key"]="${REPOSITORIOS_HELM[$key]}"
done

# Lista de componentes en orden de instalación (respetando dependencias)
ORDEN_INSTALACION=(
    "cert-manager"
    "ingress-nginx"
    "external-secrets"
    "argocd"
    "kargo"
    "prometheus-stack"
    "grafana"
    "loki"
    "jaeger"
    "argo-events"
    "argo-workflows"
    "argo-rollouts"
    "minio"
    "gitea"
)

# Alias para compatibilidad
INSTALL_ORDER=("${ORDEN_INSTALACION[@]}")

# Componentes críticos que deben funcionar correctamente
COMPONENTES_CRITICOS=(
    "argocd"
    "kargo"
)

# Alias para compatibilidad
CRITICAL_COMPONENTS=("${COMPONENTES_CRITICOS[@]}")

# Función para verificar si estamos en modo dry-run
es_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Alias para compatibilidad
is_dry_run() { es_dry_run; }

# Función para ejecutar comandos respetando dry-run
ejecutar_comando() {
    local comando="$1"
    local descripcion="${2:-Ejecutando comando}"
    
    if es_dry_run; then
        echo -e "${CIAN}[DRY-RUN] ${descripcion}${SIN_COLOR}"
        echo -e "${CIAN}[DRY-RUN] Comando: ${comando}${SIN_COLOR}"
        return 0
    else
        echo -e "${AZUL}${descripcion}${SIN_COLOR}"
        eval "$comando"
    fi
}

# Alias para compatibilidad
execute_command() { ejecutar_comando "$@"; }

# Función para verificar si un comando existe
comando_existe() {
    command -v "$1" >/dev/null 2>&1
}

# Alias para compatibilidad
command_exists() { comando_existe "$@"; }

# Función para verificar si un puerto está en uso
puerto_en_uso() {
    local puerto=$1
    lsof -Pi :$puerto -sTCP:LISTEN -t >/dev/null 2>&1
}

# Alias para compatibilidad
is_port_in_use() { puerto_en_uso "$@"; }

# Función para esperar hasta que un pod esté ready
esperar_pod_listo() {
    local namespace=$1
    local selector=$2
    local timeout=${3:-300}
    
    echo -e "${AMARILLO}⏳ Esperando que el pod esté listo: ${selector} en namespace ${namespace}${SIN_COLOR}"
    
    if es_dry_run; then
        echo -e "${CIAN}[DRY-RUN] kubectl wait --for=condition=ready pod -l ${selector} -n ${namespace} --timeout=${timeout}s${SIN_COLOR}"
        return 0
    fi
    
    kubectl wait --for=condition=ready pod -l "$selector" -n "$namespace" --timeout="${timeout}s" || {
        echo -e "${ROJO}❌ Timeout esperando que el pod esté listo${SIN_COLOR}"
        return 1
    }
    
    echo -e "${VERDE}✅ Pod listo${SIN_COLOR}"
}

# Alias para compatibilidad
wait_for_pod_ready() { esperar_pod_listo "$@"; }

# Función para verificar si un deployment está ready
esperar_deployment_listo() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    echo -e "${AMARILLO}⏳ Esperando deployment listo: ${deployment} en namespace ${namespace}${SIN_COLOR}"
    
    if es_dry_run; then
        echo -e "${CIAN}[DRY-RUN] kubectl rollout status deployment/${deployment} -n ${namespace} --timeout=${timeout}s${SIN_COLOR}"
        return 0
    fi
    
    kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="${timeout}s" || {
        echo -e "${ROJO}❌ Timeout esperando deployment listo${SIN_COLOR}"
        return 1
    }
    
    echo -e "${VERDE}✅ Deployment listo${SIN_COLOR}"
}

# Alias para compatibilidad
wait_for_deployment_ready() { esperar_deployment_listo "$@"; }

# Función para agregar repositorio Helm si no existe
agregar_repo_helm_si_no_existe() {
    local nombre_repo=$1
    local url_repo=$2
    
    if helm repo list 2>/dev/null | grep -q "^${nombre_repo}\s"; then
        echo -e "${VERDE}✅ Repositorio Helm ${nombre_repo} ya existe${SIN_COLOR}"
    else
        ejecutar_comando "helm repo add ${nombre_repo} ${url_repo}" "Agregando repositorio Helm: ${nombre_repo}"
    fi
}

# Alias para compatibilidad
add_helm_repo_if_not_exists() { agregar_repo_helm_si_no_existe "$@"; }

# Función para crear namespace si no existe
crear_namespace_si_no_existe() {
    local namespace=$1
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo -e "${VERDE}✅ Namespace ${namespace} ya existe${SIN_COLOR}"
    else
        ejecutar_comando "kubectl create namespace ${namespace}" "Creando namespace: ${namespace}"
    fi
}

# Alias para compatibilidad
create_namespace_if_not_exists() { crear_namespace_si_no_existe "$@"; }

# Función para verificar si un componente está instalado
componente_instalado() {
    local componente=$1
    local namespace=${2:-""}
    
    case $componente in
        "argocd")
            kubectl get deployment argocd-server -n argocd >/dev/null 2>&1
            ;;
        "kargo")
            kubectl get deployment kargo-api -n kargo-system >/dev/null 2>&1
            ;;
        *)
            if [[ -n "$namespace" ]]; then
                kubectl get deployment -n "$namespace" | grep -q "$componente" 2>/dev/null
            else
                return 1
            fi
            ;;
    esac
}

# Alias para compatibilidad
is_component_installed() { componente_instalado "$@"; }

# Función para obtener la versión de Kubernetes
obtener_version_kubernetes() {
    kubectl version --client --short 2>/dev/null | cut -d' ' -f3 | sed 's/v//'
}

# Alias para compatibilidad
get_kubernetes_version() { obtener_version_kubernetes; }

# Función para verificar recursos del cluster
verificar_recursos_cluster() {
    local min_memoria_gb=${1:-4}
    local min_cpu_cores=${2:-2}
    
    echo -e "${AMARILLO}🔍 Verificando recursos del cluster...${SIN_COLOR}"
    
    # Obtener recursos totales
    local memoria_total_ki=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum += $4} END {print sum}' | sed 's/Ki//')
    local cpu_total_cores=$(kubectl top nodes --no-headers 2>/dev/null | awk '{sum += $2} END {print sum}' | sed 's/m//')
    
    # Convertir a GB y cores
    local memoria_total_gb=$((memoria_total_ki / 1024 / 1024))
    local cpu_total=$((cpu_total_cores / 1000))
    
    echo -e "${AZUL}  Memoria total: ${memoria_total_gb}GB (mínimo: ${min_memoria_gb}GB)${SIN_COLOR}"
    echo -e "${AZUL}  CPU total: ${cpu_total} cores (mínimo: ${min_cpu_cores} cores)${SIN_COLOR}"
    
    if [[ $memoria_total_gb -lt $min_memoria_gb ]] || [[ $cpu_total -lt $min_cpu_cores ]]; then
        echo -e "${AMARILLO}⚠️  Recursos limitados - la instalación continuará con configuración optimizada${SIN_COLOR}"
        export MODO_RECURSOS_LIMITADOS=true
    else
        echo -e "${VERDE}✅ Recursos suficientes para instalación completa${SIN_COLOR}"
        export MODO_RECURSOS_LIMITADOS=false
    fi
}

# Alias para compatibilidad
check_cluster_resources() { verificar_recursos_cluster "$@"; }

# Función para cleanup en caso de error
limpiar_en_error() {
    local componente=$1
    echo -e "${ROJO}🧹 Limpiando debido a error en ${componente}...${SIN_COLOR}"
    
    # Implementar cleanup específico según componente si es necesario
    case $componente in
        "argocd")
            kubectl delete namespace argocd --ignore-not-found=true >/dev/null 2>&1 || true
            ;;
        "kargo")
            kubectl delete namespace kargo-system --ignore-not-found=true >/dev/null 2>&1 || true
            ;;
    esac
}

# Alias para compatibilidad
cleanup_on_error() { limpiar_en_error "$@"; }

# Función para generar configuración optimizada según recursos
obtener_recursos_optimizados() {
    local componente=$1
    
    if [[ "${MODO_RECURSOS_LIMITADOS:-false}" == "true" ]]; then
        case $componente in
            "argocd"|"kargo")
                echo "--set replicaCount=1 --set resources.requests.memory=256Mi --set resources.requests.cpu=100m"
                ;;
            "prometheus")
                echo "--set prometheus.prometheusSpec.resources.requests.memory=512Mi --set prometheus.prometheusSpec.resources.requests.cpu=200m"
                ;;
            *)
                echo "--set replicaCount=1 --set resources.requests.memory=128Mi --set resources.requests.cpu=50m"
                ;;
        esac
    else
        echo ""  # Sin optimizaciones especiales
    fi
}

# Alias para compatibilidad
get_optimized_resources() { obtener_recursos_optimizados "$@"; }
