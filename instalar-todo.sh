#!/bin/bash

# ============================================================================
# GITOPS AUTO-UPDATING INFRASTRUCTURE - VERSIÓN 2025 INTELIGENTE Y DESATENDIDA
# ============================================================================
# Autor: Automatización GitOps
# Fecha: Enero 2025 
# Propósito: Instalación completamente automatizada de infraestructura GitOps
# Arquitectura: DEV (gestión centralizada) + PRE/PRO (despliegue automático)
# Metodología: Auto-detección + Helm Charts Oficiales + Operación Desatendida
# 
# VARIABLES DE ENTORNO:
# - MODO_DESATENDIDO=true/false (default: true) - Instalación sin prompts
# - CREAR_CLUSTERS_ADICIONALES=true/false (default: false) - Crear PRE/PRO
# 
# EJEMPLOS DE USO:
# ./instalar-todo.sh                                    # Instalación desatendida solo DEV
# MODO_DESATENDIDO=false ./instalar-todo.sh             # Instalación interactiva  
# CREAR_CLUSTERS_ADICIONALES=true ./instalar-todo.sh    # Instalar DEV + PRE + PRO
# ============================================================================

set -euo pipefail  # Salir en cualquier error, variable no definida o error en pipe

# Configuración de colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuración para instalación desatendida
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a
export ARGOCD_OPTS="--plaintext --grpc-web"
export MINIKUBE_IN_STYLE=false

# Configuración de variables globales
CLUSTER_DEV="gitops-dev"
CLUSTER_PRE="gitops-pre" 
CLUSTER_PRO="gitops-pro"

# Configuración por defecto: modo desatendido
MODO_DESATENDIDO="${MODO_DESATENDIDO:-true}"  # Por defecto desatendido
CREAR_CLUSTERS_ADICIONALES="${CREAR_CLUSTERS_ADICIONALES:-false}"  # Por defecto solo DEV

# Configuración de versiones (se auto-actualizan dinámicamente)
KUBERNETES_VERSION=""  # Se detecta automáticamente la última estable
ARGOCD_VERSION=""      # Se detecta automáticamente la última release

# Versiones de Helm Charts (se auto-actualizan dinámicamente)
CERT_MANAGER_VERSION=""
EXTERNAL_SECRETS_VERSION=""
INGRESS_NGINX_VERSION=""
GRAFANA_VERSION=""
JAEGER_VERSION=""
LOKI_VERSION=""
MINIO_VERSION=""
GITEA_VERSION=""

# Cache de versiones para evitar múltiples consultas API
declare -A VERSION_CACHE

# Configuración de recursos por cluster - OPTIMIZADA
DEV_MEMORY="8192"     # 8GB RAM - Cluster principal con toda la infraestructura
DEV_CPUS="4"          # 4 CPUs - Para manejar múltiples cargas de trabajo  
DEV_DISK="50g"        # 50GB - Almacenamiento para logs, métricas, imágenes

PRE_MEMORY="2048"     # 2GB RAM - Entorno de preproducción
PRE_CPUS="2"          # 2 CPUs - Recursos suficientes para testing
PRE_DISK="20g"        # 20GB - Almacenamiento para aplicaciones de test

PRO_MEMORY="2048"     # 2GB RAM - Simulación de producción en desarrollo
PRO_CPUS="2"          # 2 CPUs - Recursos similares a PRE
PRO_DISK="20g"        # 20GB - Almacenamiento para aplicaciones

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# URLs de las UIs accesibles - VALIDADAS Y ACTUALIZADAS
declare -A UI_URLS=(
    # GitOps Core
    ["ArgoCD"]="http://localhost:8080"
    ["Kargo"]="http://localhost:8081"
    
    # Progressive Delivery & Event-Driven GitOps
    ["Argo_Workflows"]="http://localhost:8083"
    ["Argo_Rollouts"]="http://localhost:8084"
    ["Argo_Events"]="http://localhost:8089"
    
    # Observability
    ["Grafana"]="http://localhost:8085"
    ["Prometheus"]="http://localhost:8086"
    ["AlertManager"]="http://localhost:8087"
    ["Jaeger"]="http://localhost:8088"
    
    # Storage & Tools
    ["MinIO_Console"]="http://localhost:8091"
    
    # Desarrollo & Gestión
    ["Gitea"]="http://localhost:8092"  
    ["K8s_Dashboard"]="http://localhost:8093"
)

declare -A UI_STATUS

# ============================================================================
# FUNCIONES DE AUTO-ACTUALIZACIÓN
# ============================================================================

obtener_version_kubernetes() {
    echo -e "${BLUE}🔍 Detectando última versión estable de Kubernetes compatible con minikube...${NC}"
    
    if [[ -n "${VERSION_CACHE[kubernetes]:-}" ]]; then
        KUBERNETES_VERSION="${VERSION_CACHE[kubernetes]}"
        echo -e "${GREEN}✅ Kubernetes (cache): $KUBERNETES_VERSION${NC}"
        return
    fi
    
    # Obtener versiones soportadas por minikube (limpiar el formato)
    local minikube_versions=$(minikube config defaults kubernetes-version 2>/dev/null | head -20 | grep -E "^\\* v[0-9]+\\.[0-9]+\\.[0-9]+$" | sed 's/^\* //')
    
    if [[ -n "$minikube_versions" ]]; then
        # Usar la primera versión (más reciente) soportada por minikube
        local latest_version=$(echo "$minikube_versions" | head -1)
        echo -e "${GREEN}✅ Usando versión más reciente soportada por minikube: $latest_version${NC}"
    else
        # Fallback: obtener desde GitHub y validar contra minikube
        echo "🔍 Consultando GitHub releases como fallback..."
        local github_version=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases | \
            jq -r '[.[] | select(.prerelease == false)] | .[0].tag_name' 2>/dev/null || echo "")
        
        # Validar si la versión de GitHub es compatible con minikube
        if [[ -n "$github_version" ]] && echo "$minikube_versions" | grep -q "$github_version"; then
            latest_version="$github_version"
            echo -e "${GREEN}✅ Versión de GitHub compatible con minikube: $latest_version${NC}"
        else
            echo -e "${YELLOW}⚠️ Versión de GitHub no compatible, usando v1.33.1 (máxima soportada por minikube)${NC}"
            latest_version="v1.33.1"
        fi
    fi
    
    KUBERNETES_VERSION="$latest_version"
    VERSION_CACHE[kubernetes]="$latest_version"
    echo -e "${GREEN}✅ Kubernetes detectado: $KUBERNETES_VERSION${NC}"
}

obtener_version_argocd() {
    echo -e "${BLUE}🔍 Detectando última versión de ArgoCD...${NC}"
    
    if [[ -n "${VERSION_CACHE[argocd]:-}" ]]; then
        ARGOCD_VERSION="${VERSION_CACHE[argocd]}"
        echo -e "${GREEN}✅ ArgoCD (cache): $ARGOCD_VERSION${NC}"
        return
    fi
    
    local latest_version=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | \
        jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo -e "${YELLOW}⚠️ No se pudo detectar versión automáticamente, usando versión estable conocida${NC}"
        latest_version="3.0.12"
    fi
    
    ARGOCD_VERSION="$latest_version"
    VERSION_CACHE[argocd]="$latest_version"
    echo -e "${GREEN}✅ ArgoCD detectado: $ARGOCD_VERSION${NC}"
}

obtener_version_kargo() {
    echo -e "${BLUE}🔍 Detectando última versión de Kargo...${NC}"
    
    if [[ -n "${VERSION_CACHE[kargo]:-}" ]]; then
        KARGO_VERSION="${VERSION_CACHE[kargo]}"
        echo -e "${GREEN}✅ Kargo (cache): $KARGO_VERSION${NC}"
        return
    fi
    
    local latest_version=$(curl -s https://api.github.com/repos/akuity/kargo/releases/latest | \
        jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo -e "${YELLOW}⚠️ No se pudo detectar versión automáticamente, usando versión estable conocida${NC}"
        latest_version="1.6.2"
    fi
    
    KARGO_VERSION="$latest_version"
    VERSION_CACHE[kargo]="$latest_version"
    echo -e "${GREEN}✅ Kargo detectado: $KARGO_VERSION${NC}"
}

obtener_version_argo_rollouts() {
    echo -e "${BLUE}🔍 Detectando última versión de Argo Rollouts...${NC}"
    
    if [[ -n "${VERSION_CACHE[argo-rollouts]:-}" ]]; then
        ARGO_ROLLOUTS_VERSION="${VERSION_CACHE[argo-rollouts]}"
        echo -e "${GREEN}✅ Argo Rollouts (cache): $ARGO_ROLLOUTS_VERSION${NC}"
        return
    fi
    
    local latest_version=$(curl -s https://api.github.com/repos/argoproj/argo-rollouts/releases/latest | \
        jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo -e "${YELLOW}⚠️ No se pudo detectar versión automáticamente, usando versión estable conocida${NC}"
        latest_version="1.7.2"
    fi
    
    ARGO_ROLLOUTS_VERSION="$latest_version"
    VERSION_CACHE[argo-rollouts]="$latest_version"
    echo -e "${GREEN}✅ Argo Rollouts detectado: $ARGO_ROLLOUTS_VERSION${NC}"
}

obtener_version_argo_workflows() {
    echo -e "${BLUE}🔍 Detectando última versión de Argo Workflows...${NC}"
    
    if [[ -n "${VERSION_CACHE[argo-workflows]:-}" ]]; then
        ARGO_WORKFLOWS_VERSION="${VERSION_CACHE[argo-workflows]}"
        echo -e "${GREEN}✅ Argo Workflows (cache): $ARGO_WORKFLOWS_VERSION${NC}"
        return
    fi
    
    local latest_version=$(curl -s https://api.github.com/repos/argoproj/argo-workflows/releases/latest | \
        jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo -e "${YELLOW}⚠️ No se pudo detectar versión automáticamente, usando versión estable conocida${NC}"
        latest_version="3.6.1"
    fi
    
    ARGO_WORKFLOWS_VERSION="$latest_version"
    VERSION_CACHE[argo-workflows]="$latest_version"
    echo -e "${GREEN}✅ Argo Workflows detectado: $ARGO_WORKFLOWS_VERSION${NC}"
}

obtener_version_argo_events() {
    echo -e "${BLUE}🔍 Detectando última versión de Argo Events...${NC}"
    
    if [[ -n "${VERSION_CACHE[argo-events]:-}" ]]; then
        ARGO_EVENTS_VERSION="${VERSION_CACHE[argo-events]}"
        echo -e "${GREEN}✅ Argo Events (cache): $ARGO_EVENTS_VERSION${NC}"
        return
    fi
    
    local latest_version=$(curl -s https://api.github.com/repos/argoproj/argo-events/releases/latest | \
        jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "")
    
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        echo -e "${YELLOW}⚠️ No se pudo detectar versión automáticamente, usando versión estable conocida${NC}"
        latest_version="1.9.3"
    fi
    
    ARGO_EVENTS_VERSION="$latest_version"
    VERSION_CACHE[argo-events]="$latest_version"
    echo -e "${GREEN}✅ Argo Events detectado: $ARGO_EVENTS_VERSION${NC}"
}

obtener_version_helm_chart() {
    local chart_name="$1"
    local repo_url="$2"
    local cache_key="$3"
    
    if [[ -n "${VERSION_CACHE[$cache_key]:-}" ]]; then
        echo "${VERSION_CACHE[$cache_key]}"
        return
    fi
    
    echo -e "${BLUE}🔍 Detectando última versión de $chart_name...${NC}"
    
    # Agregar repo temporalmente para consultar versiones
    local temp_repo_name="temp_${cache_key}_$(date +%s)"
    helm repo add "$temp_repo_name" "$repo_url" >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    
    # Obtener la última versión del chart
    local latest_version=$(helm search repo "$temp_repo_name/$chart_name" --versions | \
        awk 'NR==2 {print $2}' 2>/dev/null || echo "")
    
    # Limpiar repo temporal
    helm repo remove "$temp_repo_name" >/dev/null 2>&1 || true
    
    if [[ -z "$latest_version" ]]; then
        # Fallback: usar versiones conocidas estables
        case "$cache_key" in
            "cert-manager") latest_version="v1.18.2" ;;
            "external-secrets") latest_version="0.18.2" ;;
            "ingress-nginx") latest_version="4.13.0" ;;
            "grafana") latest_version="9.3.0" ;;
            "jaeger") latest_version="3.4.1" ;;
            "loki") latest_version="6.34.0" ;;
            "minio") latest_version="5.4.0" ;;
            "gitea") latest_version="12.1.2" ;;
            *) latest_version="latest" ;;
        esac
        echo -e "${YELLOW}⚠️ $chart_name: usando versión fallback $latest_version${NC}"
    else
        echo -e "${GREEN}✅ $chart_name detectado: $latest_version${NC}"
    fi
    
    VERSION_CACHE[$cache_key]="$latest_version"
    echo "$latest_version"
}

obtener_todas_las_versiones() {
    echo -e "${CYAN}🚀 DETECTANDO AUTOMÁTICAMENTE ÚLTIMAS VERSIONES...${NC}"
    echo "=================================================="
    
    # Detectar versiones principales
    obtener_version_kubernetes
    obtener_version_argocd
    
    # Detectar versiones del stack Argo GitOps completo
    obtener_version_kargo
    obtener_version_argo_rollouts  
    obtener_version_argo_workflows
    obtener_version_argo_events
    
    # Detectar versiones de Helm Charts
    CERT_MANAGER_VERSION=$(obtener_version_helm_chart "cert-manager" "https://charts.jetstack.io" "cert-manager")
    EXTERNAL_SECRETS_VERSION=$(obtener_version_helm_chart "external-secrets" "https://charts.external-secrets.io" "external-secrets")
    INGRESS_NGINX_VERSION=$(obtener_version_helm_chart "ingress-nginx" "https://kubernetes.github.io/ingress-nginx" "ingress-nginx")
    PROMETHEUS_VERSION=$(obtener_version_helm_chart "kube-prometheus-stack" "https://prometheus-community.github.io/helm-charts" "kube-prometheus-stack")
    GRAFANA_VERSION=$(obtener_version_helm_chart "grafana" "https://grafana.github.io/helm-charts" "grafana")
    JAEGER_VERSION=$(obtener_version_helm_chart "jaeger" "https://jaegertracing.github.io/helm-charts" "jaeger")
    LOKI_VERSION=$(obtener_version_helm_chart "loki" "https://grafana.github.io/helm-charts" "loki")
    MINIO_VERSION=$(obtener_version_helm_chart "minio" "https://charts.min.io" "minio")
    GITEA_VERSION=$(obtener_version_helm_chart "gitea" "https://dl.gitea.io/charts" "gitea")
    
    echo ""
    echo -e "${GREEN}🎯 STACK GITOPS COMPLETO - VERSIONES DETECTADAS:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${CYAN}🏗️ INFRAESTRUCTURA BASE:${NC}"
    echo "🔧 Kubernetes: $KUBERNETES_VERSION"
    echo ""
    echo -e "${CYAN}🔄 GITOPS CORE:${NC}"
    echo "🔄 ArgoCD: $ARGOCD_VERSION"
    echo "🚢 Kargo: $KARGO_VERSION"
    echo ""
    echo -e "${CYAN}⚡ PROGRESSIVE DELIVERY:${NC}"
    echo "⚡ Argo Rollouts: $ARGO_ROLLOUTS_VERSION"
    echo "🌊 Argo Workflows: $ARGO_WORKFLOWS_VERSION"
    echo "📡 Argo Events: $ARGO_EVENTS_VERSION"
    echo ""
    echo -e "${CYAN}🔒 SEGURIDAD Y SECRETOS:${NC}"
    echo "🔒 cert-manager: $CERT_MANAGER_VERSION"
    echo "🔐 external-secrets: $EXTERNAL_SECRETS_VERSION"
    echo ""
    echo -e "${CYAN}🌐 NETWORKING:${NC}"
    echo "🌐 ingress-nginx: $INGRESS_NGINX_VERSION"
    echo ""
    echo -e "${CYAN}📊 OBSERVABILIDAD:${NC}"
    echo "📊 Prometheus Stack: $PROMETHEUS_VERSION"
    echo "📈 Grafana: $GRAFANA_VERSION"
    echo "🔍 Jaeger: $JAEGER_VERSION"
    echo "📝 Loki: $LOKI_VERSION"
    echo ""
    echo -e "${CYAN}🏪 ALMACENAMIENTO Y REPOSITORIOS:${NC}"
    echo "🏪 MinIO: $MINIO_VERSION"
    echo "🐙 Gitea: $GITEA_VERSION"
    echo ""
}

# ============================================================================
# FUNCIONES PRINCIPALES
# ============================================================================

mostrar_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                🚀 GITOPS AUTO-UPDATING INFRASTRUCTURE 🚀                   ║"
    echo "║                           VERSIÓN 2025 - INTELIGENTE                        ║"
    echo "║                                                                              ║"
    echo "║  🏗️  Arquitectura: 3 Clusters (DEV/PRE/PRO) con ArgoCD + Kargo            ║"
    echo "║  📊  Stack: Prometheus, Grafana, Jaeger, Loki, MinIO, Gitea                ║"
    echo "║  🔄  GitOps: Continuous Deployment + Progressive Delivery                   ║"
    echo "║  📦  Metodología: Helm Charts Oficiales + Auto-Update + Exclusiones        ║"
    echo "║  🤖  Inteligencia: Detecta automáticamente últimas versiones estables      ║"
    echo "║  🎯  Objetivo: Plataforma empresarial siempre actualizada y GitOps-ready   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

mostrar_arquitectura() {
    echo -e "${YELLOW}"
    echo "🏗️ ARQUITECTURA MULTI-CLUSTER ROBUSTA:"
    echo "========================================"
    echo "🏭 Cluster ${CLUSTER_DEV} (${DEV_MEMORY}MB RAM, ${DEV_CPUS} CPU, ${DEV_DISK}): Gestión centralizada y herramientas"
    echo "🏭 Cluster ${CLUSTER_PRE} (${PRE_MEMORY}MB RAM, ${PRE_CPUS} CPU, ${PRE_DISK}): Entorno de preproducción"
    echo "🏭 Cluster ${CLUSTER_PRO} (${PRO_MEMORY}MB RAM, ${PRO_CPUS} CPU, ${PRO_DISK}): Entorno de producción"
    echo "🛠 Configuración: RECURSOS OPTIMIZADOS por componente real"
    echo "📟 Kubernetes Version: $KUBERNETES_VERSION"
    echo ""
    echo "📦 STACK GITOPS COMPLETO CON AUTO-DETECCIÓN (controlan todos los clusters):"
    echo ""
    echo -e "${GREEN}🔄 GITOPS CORE:${NC}"
    echo "├─ 🔄 ArgoCD ${ARGOCD_VERSION:-TBD}: Gestión GitOps multi-cluster"
    echo "├─ 🚢 Kargo ${KARGO_VERSION:-TBD}: Promociones automáticas entre entornos"
    echo ""
    echo -e "${GREEN}⚡ PROGRESSIVE DELIVERY:${NC}"
    echo "├─ ⚡ Argo Rollouts ${ARGO_ROLLOUTS_VERSION:-TBD}: Progressive delivery"
    echo "├─ 🌊 Argo Workflows ${ARGO_WORKFLOWS_VERSION:-TBD}: Workflow orchestration"
    echo "├─ 📡 Argo Events ${ARGO_EVENTS_VERSION:-TBD}: Event-driven GitOps automation"
    echo ""
    echo -e "${GREEN}📊 OBSERVABILIDAD:${NC}"
    echo "├─ 📊 Prometheus Stack ${PROMETHEUS_VERSION:-TBD}: Monitoreo centralizado"
    echo "├─ 📈 Grafana ${GRAFANA_VERSION:-TBD}: Dashboards y visualización"
    echo "├─ 📝 Loki ${LOKI_VERSION:-TBD}: Agregación de logs"
    echo "├─ 🔍 Jaeger ${JAEGER_VERSION:-TBD}: Distributed tracing"
    echo ""
    echo -e "${GREEN}🔒 SEGURIDAD:${NC}"
    echo "├─ 🔒 Cert-Manager ${CERT_MANAGER_VERSION:-TBD}: Gestión de certificados TLS"
    echo "├─ 🔐 External Secrets ${EXTERNAL_SECRETS_VERSION:-TBD}: Gestión de secretos"
    echo "├─ 🌐 NGINX Ingress ${INGRESS_NGINX_VERSION:-TBD}: Ingress controller"
    echo ""
    echo -e "${GREEN}🏪 ALMACENAMIENTO Y REPOSITORIOS:${NC}"
    echo "├─ 🏪 MinIO ${MINIO_VERSION:-TBD}: Object storage S3-compatible"
    echo "└─ 🐙 Gitea ${GITEA_VERSION:-TBD}: Git repository management"
    echo ""
    echo -e "${CYAN}🔄 FLUJO GITOPS OPTIMIZADO:${NC}"
    echo "Git Push → ArgoCD-DEV → Deploy dev/pre/pro → Kargo → Auto-Promote"
    echo -e "${NC}"
}

verificar_dependencias() {
    echo -e "${BLUE}🔍 Verificando dependencias del sistema...${NC}"
    
    local dependencias_requeridas=("minikube" "kubectl" "helm" "docker" "curl" "netstat" "fuser")
    local dependencias_opcionales=("jq" "yq" "argocd")
    local faltantes_requeridas=()
    local faltantes_opcionales=()
    local auto_instalables=("curl" "netstat" "jq" "yq" "fuser" "argocd")
    
    # Verificar dependencias requeridas
    for dep in "${dependencias_requeridas[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            faltantes_requeridas+=("$dep")
        else
            echo -e "${GREEN}✅ $dep encontrado${NC}"
        fi
    done
    
    # Verificar dependencias opcionales
    for dep in "${dependencias_opcionales[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            faltantes_opcionales+=("$dep")
        else
            echo -e "${GREEN}✅ $dep encontrado (opcional)${NC}"
        fi
    done
    
    # Función para instalar dependencias automáticamente
    instalar_dependencia_auto() {
        local dep="$1"
        echo -e "${YELLOW}📦 Instalando automáticamente: $dep${NC}"
        
        case $dep in
            "curl")
                if sudo apt-get update -qq && sudo apt-get install -y -qq curl; then
                    echo -e "${GREEN}✅ curl instalado exitosamente${NC}"
                    return 0
                fi
                ;;
            "netstat")
                if sudo apt-get install -y -qq net-tools; then
                    echo -e "${GREEN}✅ net-tools (netstat) instalado exitosamente${NC}"
                    return 0
                fi
                ;;
            "fuser")
                if sudo apt-get install -y -qq psmisc; then
                    echo -e "${GREEN}✅ psmisc (fuser) instalado exitosamente${NC}"
                    return 0
                fi
                ;;
            "jq")
                if sudo apt-get install -y -qq jq; then
                    echo -e "${GREEN}✅ jq instalado exitosamente${NC}"
                    return 0
                fi
                ;;
            "yq")
                echo "🔗 Instalando yq desde GitHub releases..."
                if curl -L -s "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" -o /tmp/yq && \
                   chmod +x /tmp/yq && sudo mv /tmp/yq /usr/local/bin/yq; then
                    echo -e "${GREEN}✅ yq instalado exitosamente${NC}"
                    return 0
                fi
                ;;
            "argocd")
                echo "🔗 Instalando ArgoCD CLI desde GitHub releases..."
                if curl -sSL -o /tmp/argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
                   chmod +x /tmp/argocd-linux-amd64 && sudo mv /tmp/argocd-linux-amd64 /usr/local/bin/argocd; then
                    echo -e "${GREEN}✅ ArgoCD CLI instalado exitosamente${NC}"
                    return 0
                fi
                ;;
        esac
        
        echo -e "${RED}❌ Error al instalar $dep automáticamente${NC}"
        return 1
    }
    
    # Intentar instalar dependencias automáticamente
    if [ ${#faltantes_requeridas[@]} -ne 0 ] || [ ${#faltantes_opcionales[@]} -ne 0 ]; then
        echo ""
        echo -e "${BLUE}🔧 Intentando instalar dependencias automáticamente...${NC}"
        
        # Instalar dependencias requeridas auto-instalables
        local nuevas_faltantes_requeridas=()
        for dep in "${faltantes_requeridas[@]}"; do
            if [[ " ${auto_instalables[*]} " =~ " ${dep} " ]]; then
                if ! instalar_dependencia_auto "$dep"; then
                    nuevas_faltantes_requeridas+=("$dep")
                fi
            else
                nuevas_faltantes_requeridas+=("$dep")
            fi
        done
        
        # Instalar dependencias opcionales auto-instalables
        local nuevas_faltantes_opcionales=()
        for dep in "${faltantes_opcionales[@]}"; do
            if [[ " ${auto_instalables[*]} " =~ " ${dep} " ]]; then
                instalar_dependencia_auto "$dep" || nuevas_faltantes_opcionales+=("$dep")
            else
                nuevas_faltantes_opcionales+=("$dep")
            fi
        done
        
        # Actualizar arrays de faltantes
        faltantes_requeridas=("${nuevas_faltantes_requeridas[@]}")
        faltantes_opcionales=("${nuevas_faltantes_opcionales[@]}")
    fi
    
    # Reportar dependencias que no pudieron instalarse automáticamente
    if [ ${#faltantes_requeridas[@]} -ne 0 ]; then
        echo -e "${RED}❌ Dependencias REQUERIDAS que requieren instalación manual: ${faltantes_requeridas[*]}${NC}"
        echo ""
        echo "📦 INSTRUCCIONES DE INSTALACIÓN MANUAL:"
        echo "======================================="
        for dep in "${faltantes_requeridas[@]}"; do
            case $dep in
                "minikube")
                    echo "🔗 Minikube: curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/minikube"
                    ;;
                "kubectl")
                    echo "🔗 kubectl: curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
                    ;;
                "helm")
                    echo "🔗 Helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
                    ;;
                "docker")
                    echo "🔗 Docker: sudo apt-get update && sudo apt-get install docker.io && sudo usermod -aG docker \$USER"
                    echo "   📝 Nota: Después de instalar Docker, reinicia la sesión o ejecuta 'newgrp docker'"
                    ;;
            esac
        done
        echo ""
        echo -e "${RED}Por favor instala las dependencias faltantes manualmente y ejecuta el script nuevamente.${NC}"
        exit 1
    fi
    
    if [ ${#faltantes_opcionales[@]} -ne 0 ]; then
        echo -e "${YELLOW}⚠️ Dependencias OPCIONALES faltantes: ${faltantes_opcionales[*]}${NC}"
        echo "Estas no son críticas, pero pueden mejorar la experiencia."
    fi
    
    # Verificaciones adicionales
    echo ""
    echo "🔍 Verificaciones adicionales:"
    
    # Verificar Docker daemon
    if ! docker info >&/dev/null; then
        echo -e "${RED}❌ Docker daemon no está ejecutándose${NC}"
        echo "🔧 Solución: sudo systemctl start docker"
        exit 1
    else
        echo -e "${GREEN}✅ Docker daemon activo${NC}"
    fi
    
    # Verificar permisos Docker
    if ! docker ps >&/dev/null; then
        echo -e "${YELLOW}⚠️ No tienes permisos para usar Docker sin sudo${NC}"
        echo "🔧 Solución: sudo usermod -aG docker \$USER && newgrp docker"
        echo "📝 Nota: Puede requerir reiniciar la sesión"
    else
        echo -e "${GREEN}✅ Permisos Docker configurados${NC}"
    fi
    
    # Verificar versiones con mejor manejo de errores
    echo ""
    echo "📋 Versiones instaladas:"
    echo "- Minikube: $(minikube version --short 2>/dev/null || echo 'Error al obtener versión')"
    
    # kubectl version fix - usar --client-only para evitar errores de conexión
    local kubectl_version=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || \
                           kubectl version --client=true --short=true 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' || \
                           echo 'Error al obtener versión')
    echo "- kubectl: $kubectl_version"
    
    echo "- Helm: $(helm version --short 2>/dev/null || echo 'Error al obtener versión')"
    echo "- Docker: $(docker --version 2>/dev/null || echo 'Error al obtener versión')"
    
    echo -e "${GREEN}✅ Todas las dependencias requeridas están disponibles${NC}"
}

limpiar_clusters_existentes() {
    echo -e "${YELLOW}🧹 Limpiando clusters existentes completamente...${NC}"
    
    local clusters=("$CLUSTER_DEV" "$CLUSTER_PRE" "$CLUSTER_PRO")
    local clusters_eliminados=0
    
    # Detener port-forwards previos
    echo "🔌 Deteniendo port-forwards existentes..."
    pkill -f "kubectl.*port-forward" 2>/dev/null || true
    
    # Forzar eliminación completa de clusters para evitar problemas de downgrade
    for cluster in "${clusters[@]}"; do
        echo "🗑️ Eliminando cluster: $cluster"
        # Forzar eliminación completa con --purge para evitar problemas de versión
        if minikube delete -p "$cluster" --purge --all >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Cluster $cluster eliminado exitosamente${NC}"
            clusters_eliminados=$((clusters_eliminados + 1))
        else
            echo -e "${YELLOW}⚠️ Cluster $cluster: intentando eliminación forzada${NC}"
            # Si falla, intentar eliminación más agresiva
            minikube delete -p "$cluster" --all >/dev/null 2>&1 || true
            # Limpiar directorios locales de minikube para evitar conflictos de versión
            rm -rf ~/.minikube/profiles/$cluster 2>/dev/null || true
            echo -e "${GREEN}✅ Cluster $cluster limpiado forzadamente${NC}"
            clusters_eliminados=$((clusters_eliminados + 1))
        fi
    done
    
    # Limpiar cache de Docker para liberar espacio y evitar conflictos
    echo "🧹 Limpiando cache de Docker..."
    docker system prune -f >/dev/null 2>&1 || true
    
    # Limpiar configuraciones residuales de kubectl
    echo "🧹 Limpiando configuraciones residuales..."
    for cluster in "${clusters[@]}"; do
        kubectl config delete-context "$cluster" 2>/dev/null || true
        kubectl config delete-cluster "$cluster" 2>/dev/null || true
    done
    
    if [ $clusters_eliminados -gt 0 ]; then
        echo -e "${GREEN}✅ Limpieza completada: $clusters_eliminados clusters eliminados${NC}"
        sleep 5  # Dar tiempo para que Docker limpie los recursos
    else
        echo -e "${GREEN}✅ Limpieza completada: no había clusters que eliminar${NC}"
    fi
}

crear_cluster_dev() {
    echo -e "${BLUE}🏗️ Creando cluster DEV optimizado...${NC}"
    
    # Verificar que Docker esté ejecutándose
    if ! docker info >&/dev/null; then
        echo -e "${RED}❌ Docker no está ejecutándose. Por favor, inicia Docker primero.${NC}"
        exit 1
    fi
    
    # Función auxiliar para crear un cluster con reintentos
    crear_cluster_con_reintentos() {
        local cluster_name="$1"
        local memory="$2" 
        local cpus="$3"
        local disk="$4"
        local max_intentos=3
        local intento=1
        
        while [ $intento -le $max_intentos ]; do
            echo "🏭 Creando cluster $cluster_name (${memory}MB RAM, ${cpus} CPU, ${disk}) - Intento $intento/$max_intentos"
            
            if minikube start -p "$cluster_name" \
                --memory="$memory" \
                --cpus="$cpus" \
                --disk-size="$disk" \
                --driver=docker \
                --kubernetes-version="$KUBERNETES_VERSION" \
                --wait=true \
                --wait-timeout=600s; then
                
                echo -e "${GREEN}✅ Cluster $cluster_name creado exitosamente${NC}"
                
                # Habilitar addons necesarios
                echo "🔧 Habilitando addons requeridos..."
                minikube addons enable ingress -p "$cluster_name" || echo "⚠️ Warning: No se pudo habilitar ingress addon"
                minikube addons enable metrics-server -p "$cluster_name" || echo "⚠️ Warning: No se pudo habilitar metrics-server addon"
                
                return 0
            else
                echo -e "${YELLOW}⚠️ Falló el intento $intento para crear $cluster_name${NC}"
                intento=$((intento + 1))
                
                if [ $intento -le $max_intentos ]; then
                    echo "🔄 Limpiando y reintentando en 10 segundos..."
                    minikube delete -p "$cluster_name" >/dev/null 2>&1 || true
                    sleep 10
                fi
            fi
        done
        
        echo -e "${RED}❌ No se pudo crear el cluster $cluster_name después de $max_intentos intentos${NC}"
        return 1
    }
    
    # Crear cluster DEV
    crear_cluster_con_reintentos "$CLUSTER_DEV" "$DEV_MEMORY" "$DEV_CPUS" "$DEV_DISK"
    
    # Configurar contexto
    kubectl config use-context "$CLUSTER_DEV"
    
    echo -e "${GREEN}✅ Cluster DEV creado y configurado exitosamente${NC}"
}

instalar_argocd() {
    echo -e "${BLUE}🔄 Instalando ArgoCD ${ARGOCD_VERSION} en DEV con acceso anónimo...${NC}"
    
    kubectl config use-context "$CLUSTER_DEV"
    
    # Crear namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Instalar ArgoCD
    echo "📦 Descargando e instalando ArgoCD ${ARGOCD_VERSION}..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml
    
    # Esperar a que ArgoCD esté listo con timeout aumentado
    echo "⏳ Esperando a que ArgoCD esté listo..."
    if ! kubectl wait --for=condition=available --timeout=900s deployment/argocd-server -n argocd; then
        echo -e "${YELLOW}⚠️ Timeout esperando ArgoCD, verificando manualmente...${NC}"
        # Verificación manual como fallback
        for i in {1..30}; do
            if kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}' | grep -q "1"; then
                echo -e "${GREEN}✅ ArgoCD server está listo (verificación manual)${NC}"
                break
            fi
            echo "⏳ Intento $i/30 - Esperando ArgoCD..."
            sleep 10
        done
    fi
    
    # Configurar acceso anónimo completo
    echo "🔓 Configurando acceso anónimo completo..."
    
    # 1. Configurar servidor inseguro (sin TLS)
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '{"data":{"server.insecure":"true"}}'
    
    # 2. Configurar acceso anónimo en argocd-cm
    kubectl patch configmap argocd-cm -n argocd --patch '{
      "data": {
        "url": "http://localhost:8080", 
        "users.anonymous.enabled": "true",
        "policy.default": "role:admin",
        "policy.csv": "p, role:anonymous, applications, *, */*, allow\np, role:anonymous, clusters, *, *, allow\np, role:anonymous, repositories, *, *, allow\np, role:anonymous, certificates, *, *, allow\np, role:anonymous, accounts, *, *, allow\np, role:anonymous, gpgkeys, *, *, allow\np, role:anonymous, logs, *, *, allow\np, role:anonymous, exec, *, */*, allow\ng, argocd:anonymous, role:admin"
      }
    }'
    
    # 3. Configurar deployment con argumentos anónimos
    kubectl patch deployment argocd-server -n argocd --patch '{
      "spec": {
        "template": {
          "spec": {
            "containers": [{
              "name": "argocd-server",
              "args": [
                "argocd-server",
                "--insecure",
                "--disable-auth"
              ]
            }]
          }
        }
      }
    }'
    
    # 4. Reiniciar ArgoCD server
    echo "🔄 Reiniciando ArgoCD server con configuración anónima..."
    kubectl rollout restart deployment argocd-server -n argocd
    if ! kubectl rollout status deployment argocd-server -n argocd --timeout=600s; then
        echo -e "${YELLOW}⚠️ Timeout en rollout, pero continuando...${NC}"
    fi
    
    echo -e "${GREEN}✅ ArgoCD ${ARGOCD_VERSION} instalado con acceso anónimo completo${NC}"
}

crear_configuraciones_helm() {
    echo -e "${BLUE}📦 Creando configuraciones de Helm Charts con últimas versiones...${NC}"
    
    # Crear cert-manager con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/cert-manager-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${CERT_MANAGER_VERSION}"
spec:
  project: default
  source:
    repoURL: https://charts.jetstack.io
    targetRevision: ${CERT_MANAGER_VERSION}
    chart: cert-manager
    helm:
      values: |
        installCRDs: true
        global:
          leaderElection:
            namespace: cert-manager
        securityContext:
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        containerSecurityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        webhook:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containerSecurityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop:
              - ALL
        cainjector:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containerSecurityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop:
              - ALL
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 32Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear external-secrets con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/external-secrets-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${EXTERNAL_SECRETS_VERSION}"
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    targetRevision: ${EXTERNAL_SECRETS_VERSION}
    chart: external-secrets
    helm:
      values: |
        installCRDs: true
        webhook:
          create: true
          certCheckInterval: "5m"
        securityContext:
          runAsNonRoot: true
          seccompProfile:
            type: RuntimeDefault
        containerSecurityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 32Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear ingress-nginx con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/ingress-nginx-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingress-nginx
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${INGRESS_NGINX_VERSION}"
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx
    targetRevision: ${INGRESS_NGINX_VERSION}
    chart: ingress-nginx
    helm:
      values: |
        controller:
          service:
            type: NodePort
          admissionWebhooks:
            enabled: true
            patch:
              enabled: true
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containerSecurityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: true
            capabilities:
              add:
              - NET_BIND_SERVICE
              drop:
              - ALL
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 64Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear grafana con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/grafana-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${GRAFANA_VERSION}"
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    targetRevision: ${GRAFANA_VERSION}
    chart: grafana
    helm:
      values: |
        adminUser: admin
        adminPassword: gitops2025
        persistence:
          enabled: true
          size: 1Gi
        sidecar:
          dashboards:
            enabled: true
          datasources:
            enabled: true
        securityContext:
          runAsNonRoot: true
          runAsUser: 472
          runAsGroup: 472
          fsGroup: 472
          seccompProfile:
            type: RuntimeDefault
        containerSecurityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          runAsNonRoot: true
          capabilities:
            drop:
            - ALL
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear jaeger con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/jaeger-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jaeger
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${JAEGER_VERSION}"
spec:
  project: default
  source:
    repoURL: https://jaegertracing.github.io/helm-charts
    targetRevision: ${JAEGER_VERSION}
    chart: jaeger
    helm:
      values: |
        allInOne:
          enabled: true
          image:
            repository: jaegertracing/all-in-one
            tag: "latest"
            pullPolicy: IfNotPresent
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
        provisionDataStore:
          cassandra: false
          elasticsearch: false
        storage:
          type: memory
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear loki con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/loki-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${LOKI_VERSION}"
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    targetRevision: ${LOKI_VERSION}
    chart: loki
    helm:
      values: |
        deploymentMode: SingleBinary
        loki:
          useTestSchema: true
          storage:
            type: 'filesystem'
        singleBinary:
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 64Mi
        chunksCache:
          enabled: false
        resultsCache:
          enabled: false
        lokiCanary:
          enabled: false
        test:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear minio con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/minio-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${MINIO_VERSION}"
spec:
  project: default
  source:
    repoURL: https://charts.min.io
    targetRevision: ${MINIO_VERSION}
    chart: minio
    helm:
      values: |
        mode: standalone
        rootUser: gitops
        rootPassword: gitops2025
        persistence:
          enabled: true
          size: 5Gi
        resources:
          requests:
            memory: 256Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 200m
        consoleService:
          type: ClusterIP
        service:
          type: ClusterIP
  destination:
    server: https://kubernetes.default.svc
    namespace: minio
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear gitea con chart oficial y versión auto-detectada
    cat > "${SCRIPT_DIR}/gitea-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitea
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${GITEA_VERSION}"
spec:
  project: default
  source:
    repoURL: https://dl.gitea.io/charts
    targetRevision: ${GITEA_VERSION}
    chart: gitea
    helm:
      values: |
        gitea:
          admin:
            username: gitea_admin
            password: gitops2025
            email: admin@example.com
        postgresql:
          enabled: false
        postgresql-ha:
          enabled: false
        redis-cluster:
          enabled: false
        persistence:
          enabled: true
          size: 1Gi
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        service:
          http:
            type: ClusterIP
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # Crear kargo con chart oficial OCI y versión auto-detectada
    cat > "${SCRIPT_DIR}/kargo-helm.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kargo
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/auto-generated-by: "gitops-installer"
    argocd.argoproj.io/version: "${KARGO_VERSION}"
spec:
  project: default
  source:
    chart: kargo
    repoURL: oci://ghcr.io/akuity/kargo-charts
    targetRevision: ${KARGO_VERSION}
    helm:
      releaseName: kargo
      parameters:
        - name: "api.adminAccount.passwordHash"
          value: "\$\$2a\$\$10\$\$Zrhhie4vLz5ygtVSaif6e.qN36jgs6vjtMBdM6yrU1FOeiAAMMxOm"  # admin123 (escaped)
        - name: "api.adminAccount.tokenSigningKey"
          value: "1uyxpL0en7D1cqakaYhE1NhN23CkY16F"
        - name: "controller.serviceAccount.create"
          value: "true"
        - name: "controller.serviceAccount.clusterWideSecretReadingEnabled"
          value: "true"
        - name: "controller.argocd.enabled"
          value: "true"
        - name: "controller.argocd.watchArgocdNamespaceOnly"
          value: "false"
  destination:
    server: https://kubernetes.default.svc
    namespace: kargo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    echo -e "${GREEN}✅ Configuraciones de Helm Charts con últimas versiones creadas${NC}"
}

crear_app_of_apps() {
    echo -e "${BLUE}📝 Creando App of Apps GitOps con patrón actualizado...${NC}"
    
    # Crear el App of Apps principal que gestiona todos los componentes
    cat > "${SCRIPT_DIR}/app-of-apps-gitops.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitops-infra-app-of-apps
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/andres20980/gh-gitops-infra.git
    targetRevision: main
    path: componentes
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    echo -e "${GREEN}✅ App of Apps creado con patrón GitOps moderno${NC}"
}

aplicar_infraestructura() {
    echo -e "${BLUE}📦 Aplicando infraestructura GitOps con App of Apps...${NC}"
    
    kubectl config use-context "$CLUSTER_DEV"
    
    # Limpiar ApplicationSets y aplicaciones existentes para evitar conflictos
    echo "🧹 Limpiando recursos existentes..."
    kubectl delete applicationset gitops-infra-components -n argocd --ignore-not-found=true
    kubectl delete applicationset gitops-aplicaciones -n argocd --ignore-not-found=true
    kubectl delete application gitops-infra-app-of-apps -n argocd --ignore-not-found=true
    sleep 5
    
    # Aplicar App of Apps principal
    echo "📦 Aplicando App of Apps principal..."
    if kubectl apply -f "${SCRIPT_DIR}/app-of-apps-gitops.yaml"; then
        echo -e "${GREEN}✅ App of Apps aplicado exitosamente${NC}"
    else
        echo -e "${RED}❌ Error al aplicar App of Apps${NC}"
        return 1
    fi
    
    # Esperar un momento para que el App of Apps procese los componentes
    echo "⏳ Esperando que App of Apps detecte componentes (30s)..."
    sleep 30
    
    # Verificar que las aplicaciones fueron creadas
    echo "🔍 Verificando aplicaciones creadas por App of Apps..."
    kubectl get applications -n argocd | grep -E "(cert-manager|external-secrets|ingress-nginx|grafana|jaeger|loki|minio|gitea|kargo|argo-)" || true
    
    echo -e "${GREEN}✅ Infraestructura GitOps aplicada con patrón App of Apps${NC}"
}

esperar_argocd_ready() {
    echo -e "${BLUE}⏳ Esperando a que ArgoCD esté completamente listo...${NC}"
    
    # Verificar que los deployments estén disponibles (más robusto que los pods individuales)
    echo "🔍 Verificando deployments de ArgoCD..."
    local deployments=("argocd-server" "argocd-repo-server" "argocd-dex-server" "argocd-redis" "argocd-notifications-controller" "argocd-applicationset-controller")
    
    for deployment in "${deployments[@]}"; do
        echo "⏳ Esperando deployment $deployment..."
        if kubectl wait --for=condition=available deployment/$deployment -n argocd --timeout=600s; then
            echo -e "${GREEN}✅ Deployment $deployment listo${NC}"
        else
            echo -e "${YELLOW}⚠️ Deployment $deployment tardó más de lo esperado, pero continuando...${NC}"
        fi
    done
    
    # Verificar StatefulSet por separado
    echo "⏳ Esperando StatefulSet argocd-application-controller..."
    if kubectl wait --for=condition=ready pod/argocd-application-controller-0 -n argocd --timeout=600s; then
        echo -e "${GREEN}✅ StatefulSet argocd-application-controller listo${NC}"
    else
        echo -e "${YELLOW}⚠️ StatefulSet tardó más de lo esperado, pero continuando...${NC}"
    fi
    
    # Verificación final más robusta: asegurar que todos los pods están running
    echo "🔍 Verificación final de pods..."
    local max_intentos=20
    local intento=1
    
    while [ $intento -le $max_intentos ]; do
        local pods_running=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        local pods_total=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        
        echo "📊 Pods running: $pods_running/$pods_total (intento $intento/$max_intentos)"
        
        if [ "$pods_running" -eq "$pods_total" ] && [ "$pods_total" -gt 0 ]; then
            echo -e "${GREEN}✅ Todos los pods de ArgoCD están ejecutándose correctamente${NC}"
            break
        else
            echo "⏳ Esperando que todos los pods estén listos..."
            sleep 15
            intento=$((intento + 1))
        fi
    done
    
    # Verificación opcional del API (no crítica)
    echo "🔍 Verificación opcional del API de ArgoCD..."
    kubectl port-forward -n argocd service/argocd-server 8080:80 --address=0.0.0.0 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 10
    
    if curl -s -f "http://localhost:8080/api/version" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ArgoCD API respondiendo correctamente${NC}"
    else
        echo -e "${YELLOW}⚠️ API de ArgoCD no responde aún, pero los pods están listos${NC}"
    fi
    
    kill $pf_pid 2>/dev/null || true
    
    echo -e "${GREEN}✅ ArgoCD considerado listo para continuar${NC}"
}

configurar_port_forwards() {
    echo -e "${BLUE}🌐 Configurando port-forwards optimizados...${NC}"
    
    # Matar port-forwards previos
    echo "🧹 Limpiando port-forwards previos..."
    pkill -f "kubectl.*port-forward" 2>/dev/null || true
    sleep 3
    
    # Liberar puertos específicos si están ocupados
    local puertos=(8080 8081 8083 8084 8085 8086 8087 8088 8089 8091 8092 8093)
    for puerto in "${puertos[@]}"; do
        if netstat -tuln | grep -q ":$puerto "; then
            echo "🔌 Liberando puerto $puerto..."
            fuser -k $puerto/tcp 2>/dev/null || true
        fi
    done
    sleep 2
    
    # Función para crear port-forward con reintentos
    crear_port_forward() {
        local servicio="$1"
        local namespace="$2"
        local puerto_local="$3"
        local puerto_remoto="$4"
        local max_intentos=3
        
        for intento in $(seq 1 $max_intentos); do
            echo "🔗 Configurando port-forward para $servicio ($puerto_local:$puerto_remoto) - Intento $intento"
            
            nohup kubectl port-forward -n "$namespace" "service/$servicio" "$puerto_local:$puerto_remoto" --address=0.0.0.0 >/dev/null 2>&1 &
            local pf_pid=$!
            sleep 5
            
            if kill -0 $pf_pid 2>/dev/null && netstat -tuln | grep -q ":$puerto_local "; then
                echo -e "${GREEN}✅ Port-forward activo para $servicio en puerto $puerto_local${NC}"
                return 0
            else
                kill $pf_pid 2>/dev/null || true
            fi
            
            if [ $intento -lt $max_intentos ]; then
                sleep 5
            fi
        done
        
        echo -e "${YELLOW}⚠️ No se pudo establecer port-forward para $servicio${NC}"
        return 1
    }
    
    # Cambiar al cluster DEV
    kubectl config use-context "$CLUSTER_DEV"
    
    # Esperar a que los servicios estén disponibles
    echo "⏳ Esperando a que los servicios estén disponibles..."
    sleep 30
    
    # Configurar port-forwards principales
    declare -A servicios_pf=(
        ["argocd-server argocd 8080 80"]=""
        ["kargo-api kargo 8081 80"]=""  
        ["argo-workflows-server argo-workflows 8083 2746"]=""
        ["argo-rollouts-dashboard argo-rollouts 8084 3100"]=""
        ["argo-events-webhook argo-events 8089 12000"]=""
        ["grafana monitoring 8085 80"]=""
        ["prometheus-operated monitoring 8086 9090"]=""
        ["alertmanager-operated monitoring 8087 9093"]=""
        ["jaeger-query monitoring 8088 16686"]=""
        ["minio-console minio 8091 9001"]=""
        ["gitea-http gitea 8092 3000"]=""
        ["kubernetes-dashboard-web kubernetes-dashboard 8093 8000"]=""
    )
    
    # Crear port-forwards
    local exitosos=0
    local fallidos=0
    
    for servicio_info in "${!servicios_pf[@]}"; do
        read -r servicio namespace puerto_local puerto_remoto <<< "$servicio_info"
        
        if kubectl get service "$servicio" -n "$namespace" >/dev/null 2>&1; then
            if crear_port_forward "$servicio" "$namespace" "$puerto_local" "$puerto_remoto"; then
                exitosos=$((exitosos + 1))
            else
                fallidos=$((fallidos + 1))
            fi
        else
            echo -e "${YELLOW}⚠️ Servicio $servicio no encontrado en namespace $namespace (puede estar desplegándose)${NC}"
            fallidos=$((fallidos + 1))
        fi
        sleep 1
    done
    
    echo -e "${GREEN}✅ Port-forwards configurados: $exitosos exitosos, $fallidos fallidos${NC}"
}

validar_uis() {
    echo -e "${BLUE}🔍 Validando acceso a UIs...${NC}"
    
    local uis_operativas=0
    local uis_total=${#UI_URLS[@]}
    
    for ui_name in "${!UI_URLS[@]}"; do
        url="${UI_URLS[$ui_name]}"
        echo -n "🔍 Verificando $ui_name ($url)... "
        
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --connect-timeout 10 --max-time 15 2>/dev/null || echo "000")
        
        if [[ "$response_code" =~ ^(200|301|302|401|403)$ ]]; then
            UI_STATUS[$ui_name]="✅ OPERATIVA"
            echo -e "${GREEN}✅ ($response_code)${NC}"
            uis_operativas=$((uis_operativas + 1))
        else
            UI_STATUS[$ui_name]="❌ NO DISPONIBLE"
            echo -e "${RED}❌ ($response_code)${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Validación de UIs completada: $uis_operativas/$uis_total operativas${NC}"
    
    local porcentaje=$((uis_operativas * 100 / uis_total))
    if [ $porcentaje -lt 80 ]; then
        echo -e "${YELLOW}⚠️ Solo $porcentaje% de UIs operativas. Algunas aplicaciones pueden estar desplegándose...${NC}"
    fi
}

mostrar_resumen_final() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🎉 INSTALACIÓN COMPLETADA EXITOSAMENTE 🎉                ║${NC}"
    echo -e "${CYAN}║                         CON AUTO-ACTUALIZACIÓN ACTIVADA                     ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}📊 ESTADO DE LA INFRAESTRUCTURA:${NC}"
    echo "================================="
    
    # Mostrar clusters creados
    echo ""
    echo -e "${YELLOW}🏭 CLUSTERS KUBERNETES:${NC}"
    local clusters_activos=0
    for cluster in "$CLUSTER_DEV" "$CLUSTER_PRE" "$CLUSTER_PRO"; do
        if minikube status -p "$cluster" >&/dev/null; then
            echo -e "${GREEN}✅ $cluster - ACTIVO${NC}"
            clusters_activos=$((clusters_activos + 1))
        else
            echo -e "${RED}❌ $cluster - NO DISPONIBLE${NC}"
        fi
    done
    
    # Mostrar estado de ArgoCD
    echo ""
    echo -e "${YELLOW}🔄 ARGOCD:${NC}"
    if kubectl get pods -n argocd | grep -q "argocd-server.*Running"; then
        echo -e "${GREEN}✅ ArgoCD ${ARGOCD_VERSION} - OPERATIVO${NC}"
        echo "   🌐 URL: http://localhost:8080"
        echo "   🔓 Acceso: Anónimo (sin login requerido)"
    else
        echo -e "${RED}❌ ArgoCD - NO DISPONIBLE${NC}"
    fi
    
    # Mostrar versiones auto-detectadas
    echo ""
    echo -e "${YELLOW}🤖 VERSIONES AUTO-DETECTADAS:${NC}"
    echo "   🔧 Kubernetes: $KUBERNETES_VERSION"
    echo "   🔄 ArgoCD: $ARGOCD_VERSION"
    echo "   � Kargo: $KARGO_VERSION"
    echo "   �🔒 cert-manager: $CERT_MANAGER_VERSION"
    echo "   🔐 external-secrets: $EXTERNAL_SECRETS_VERSION"
    echo "   🌐 ingress-nginx: $INGRESS_NGINX_VERSION"
    echo "   📊 Grafana: $GRAFANA_VERSION"
    echo "   🔍 Jaeger: $JAEGER_VERSION"
    echo "   📝 Loki: $LOKI_VERSION"
    echo "   🏪 MinIO: $MINIO_VERSION"
    echo "   🐙 Gitea: $GITEA_VERSION"
    
    # Mostrar aplicaciones desplegadas
    echo ""
    echo -e "${YELLOW}📦 APLICACIONES GITOPS (App of Apps):${NC}"
    local apps_sync=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Synced" || echo "0")
    local apps_total=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    echo "   📊 Aplicaciones sincronizadas: $apps_sync/$apps_total"
    echo "   🎯 Patrón: App of Apps (gitops-infra-app-of-apps)"
    echo "   📁 Componentes gestionados desde: /componentes/"
    
    # Mostrar UIs disponibles
    echo ""
    echo -e "${YELLOW}🌐 INTERFACES WEB DISPONIBLES:${NC}"
    for ui_name in "${!UI_URLS[@]}"; do
        url="${UI_URLS[$ui_name]}"
        status="${UI_STATUS[$ui_name]:-❓ NO VERIFICADA}"
        echo "   $status $ui_name: $url"
    done
    
    # Comandos útiles
    echo ""
    echo -e "${YELLOW}🛠 COMANDOS ÚTILES:${NC}"
    echo "   📋 Ver aplicaciones ArgoCD: kubectl get applications -n argocd"
    echo "   🎯 Ver App of Apps: kubectl get application gitops-infra-app-of-apps -n argocd"
    echo "   🔄 Sincronizar aplicación: kubectl patch application <app-name> -n argocd --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"now\"}}}'"
    echo "   🌐 Port-forwards: netstat -tuln | grep '808[0-9]'"
    echo "   🏭 Estado clusters: minikube status -p $CLUSTER_DEV"
    echo "   📊 Verificar actualizaciones: ./scripts/verificar-actualizaciones.sh"
    echo "   🧹 Limpiar todo: minikube delete -p $CLUSTER_DEV && minikube delete -p $CLUSTER_PRE && minikube delete -p $CLUSTER_PRO"
    echo "   🤖 Re-ejecutar con últimas versiones: ./instalar-todo.sh"
    
    echo ""
    echo -e "${GREEN}🎯 ¡Infraestructura GitOps siempre actualizada lista para usar!${NC}"
    echo -e "${CYAN}📚 Documentación: https://argo-cd.readthedocs.io/${NC}"
    echo -e "${MAGENTA}🤖 Próxima ejecución detectará automáticamente nuevas versiones${NC}"
    echo ""
}

crear_script_verificador_actualizaciones() {
    echo -e "${BLUE}📝 Creando script verificador de actualizaciones...${NC}"
    
    cat > "${SCRIPT_DIR}/verificar-actualizaciones.sh" << 'SCRIPT_EOF'
#!/bin/bash

# ============================================================================
# VERIFICADOR DE ACTUALIZACIONES GITOPS
# ============================================================================
# Propósito: Verificar si hay nuevas versiones disponibles de las herramientas
# Uso: ./verificar-actualizaciones.sh
# ============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 VERIFICANDO ACTUALIZACIONES DISPONIBLES...${NC}"
echo "=============================================="

# Función para obtener versión actual desde ArgoCD Application
obtener_version_actual() {
    local app_name="$1"
    kubectl get application "$app_name" -n argocd -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "unknown"
}

# Función para obtener última versión de GitHub
obtener_version_github() {
    local repo="$1"
    curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo "unknown"
}

# Función para obtener última versión de Helm Chart
obtener_version_helm() {
    local chart="$1"
    local repo="$2"
    helm repo add temp_repo "$repo" >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    helm search repo "temp_repo/$chart" --versions | awk 'NR==2 {print $2}' 2>/dev/null || echo "unknown"
    helm repo remove temp_repo >/dev/null 2>&1 || true
}

# Verificar ArgoCD
echo -e "${YELLOW}🔄 ArgoCD:${NC}"
current_argocd=$(obtener_version_github "argoproj/argo-cd")
installed_argocd=$(kubectl get pods -n argocd -l app.kubernetes.io/component=server -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/^v//' || echo "unknown")
if [[ "$current_argocd" != "$installed_argocd" && "$current_argocd" != "unknown" ]]; then
    echo -e "   ${RED}📦 Nueva versión disponible: $current_argocd (actual: $installed_argocd)${NC}"
else
    echo -e "   ${GREEN}✅ Actualizado: $installed_argocd${NC}"
fi

# Verificar Kargo
echo -e "${YELLOW}🚢 Kargo:${NC}"
current_kargo=$(obtener_version_github "akuity/kargo")
installed_kargo=$(obtener_version_actual "kargo" 2>/dev/null || echo "unknown")
if [[ "$current_kargo" != "$installed_kargo" && "$current_kargo" != "unknown" ]]; then
    echo -e "   ${RED}📦 Nueva versión disponible: $current_kargo (actual: $installed_kargo)${NC}"
    updates_available=$((updates_available + 1))
else
    echo -e "   ${GREEN}✅ Actualizado: $installed_kargo${NC}"
fi

# Verificar Helm Charts
charts=(
    "cert-manager:https://charts.jetstack.io"
    "external-secrets:https://charts.external-secrets.io"
    "ingress-nginx:https://kubernetes.github.io/ingress-nginx"
    "grafana:https://grafana.github.io/helm-charts"
    "jaeger:https://jaegertracing.github.io/helm-charts"
    "loki:https://grafana.github.io/helm-charts"
    "minio:https://charts.min.io"
    "gitea:https://dl.gitea.io/charts"
)

updates_available=0

for chart_info in "${charts[@]}"; do
    IFS=':' read -r chart_name repo_url <<< "$chart_info"
    echo -e "${YELLOW}📦 $chart_name:${NC}"
    
    current_version=$(obtener_version_helm "$chart_name" "$repo_url")
    installed_version=$(obtener_version_actual "$chart_name" 2>/dev/null || echo "unknown")
    
    if [[ "$current_version" != "$installed_version" && "$current_version" != "unknown" ]]; then
        echo -e "   ${RED}🔄 Nueva versión disponible: $current_version (actual: $installed_version)${NC}"
        updates_available=$((updates_available + 1))
    else
        echo -e "   ${GREEN}✅ Actualizado: $installed_version${NC}"
    fi
done

echo ""
if [ $updates_available -gt 0 ]; then
    echo -e "${YELLOW}⚠️ Hay $updates_available actualizaciones disponibles${NC}"
    echo -e "${BLUE}💡 Para actualizar, ejecuta: ./instalar-todo.sh${NC}"
else
    echo -e "${GREEN}🎉 Todas las herramientas están actualizadas${NC}"
fi

echo ""
echo -e "${BLUE}📅 Última verificación: $(date)${NC}"
SCRIPT_EOF

    chmod +x "${SCRIPT_DIR}/verificar-actualizaciones.sh"
    echo -e "${GREEN}✅ Script verificador creado: ${SCRIPT_DIR}/verificar-actualizaciones.sh${NC}"
}

crear_clusters_adicionales() {
    if [[ "$CREAR_CLUSTERS_ADICIONALES" == "true" ]]; then
        echo -e "${BLUE}🏗️ Creando clusters PRE y PRO automáticamente...${NC}"
        # Proceder directamente a crear clusters
    elif [[ "$MODO_DESATENDIDO" != "true" ]]; then
        echo -e "${BLUE}🏗️ ¿Deseas crear los clusters PRE y PRO ahora? (recomendado después de validar DEV)${NC}"
        echo "Puedes crearlos más tarde ejecutando este script con la opción --clusters-adicionales"
        
        read -p "¿Crear clusters PRE y PRO? (y/n): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}ℹ️ Clusters PRE y PRO no creados. Puedes crearlos más tarde.${NC}"
            return 0
        fi
        # Si responde y, proceder a crear clusters
    else
        echo -e "${YELLOW}🤖 MODO DESATENDIDO: Saltando creación de clusters adicionales${NC}"
        echo -e "${BLUE}💡 Para crear clusters PRE y PRO, ejecuta: CREAR_CLUSTERS_ADICIONALES=true ./instalar-todo.sh${NC}"
        return 0
    fi
    
    # Código común para crear clusters (ejecutado solo si no se retornó antes)
    echo -e "${BLUE}🏗️ Creando clusters PRE y PRO...${NC}"
        
        # Crear cluster PRE
        if minikube start -p "$CLUSTER_PRE" \
            --memory="$PRE_MEMORY" \
            --cpus="$PRE_CPUS" \
            --disk-size="$PRE_DISK" \
            --driver=docker \
            --kubernetes-version="$KUBERNETES_VERSION" \
            --wait=true \
            --wait-timeout=600s; then
            echo -e "${GREEN}✅ Cluster PRE creado exitosamente${NC}"
        else
            echo -e "${YELLOW}⚠️ Error al crear cluster PRE${NC}"
        fi
        
        # Crear cluster PRO
        if minikube start -p "$CLUSTER_PRO" \
            --memory="$PRO_MEMORY" \
            --cpus="$PRO_CPUS" \
            --disk-size="$PRO_DISK" \
            --driver=docker \
            --kubernetes-version="$KUBERNETES_VERSION" \
            --wait=true \
            --wait-timeout=600s; then
            echo -e "${GREEN}✅ Cluster PRO creado exitosamente${NC}"
        else
            echo -e "${YELLOW}⚠️ Error al crear cluster PRO${NC}"
        fi
        
        # Configurar contexto de vuelta a DEV
        kubectl config use-context "$CLUSTER_DEV"
        
        echo -e "${GREEN}✅ Clusters adicionales creados${NC}"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Verificar argumentos
    if [[ "${1:-}" == "--clusters-adicionales" ]]; then
        echo -e "${BLUE}🏗️ Creando únicamente clusters PRE y PRO...${NC}"
        obtener_todas_las_versiones  # Obtener versiones incluso para clusters adicionales
        crear_clusters_adicionales
        exit 0
    fi
    
    # Flujo principal
    mostrar_banner
    mostrar_arquitectura
    
    if [[ "$MODO_DESATENDIDO" != "true" ]]; then
        echo -e "${YELLOW}⚠️ ADVERTENCIA: Este script eliminará clusters minikube existentes.${NC}"
        read -p "¿Continuar? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Instalación cancelada."
            exit 1
        fi
    else
        echo -e "${GREEN}🤖 MODO DESATENDIDO: Iniciando instalación automática...${NC}"
        echo -e "${YELLOW}⚠️ Se eliminarán clusters minikube existentes automáticamente.${NC}"
        sleep 3  # Breve pausa para mostrar el mensaje
    fi
    
    # Ejecutar instalación paso a paso con auto-detección de versiones
    echo -e "${CYAN}🚀 INICIANDO INSTALACIÓN AUTOMATIZADA COMPLETA...${NC}"
    echo ""
    
    verificar_dependencias || { echo -e "${RED}❌ Error crítico en dependencias${NC}"; exit 1; }
    obtener_todas_las_versiones  # ⭐ NUEVA FUNCIÓN: Auto-detectar todas las versiones
    limpiar_clusters_existentes || { echo -e "${RED}❌ Error crítico limpiando clusters${NC}"; exit 1; }
    crear_cluster_dev || { echo -e "${RED}❌ Error crítico creando cluster DEV${NC}"; exit 1; }
    instalar_argocd || { echo -e "${RED}❌ Error crítico instalando ArgoCD${NC}"; exit 1; }
    
    # ArgoCD ready con manejo robusto de errores
    if ! esperar_argocd_ready; then
        echo -e "${YELLOW}⚠️ ArgoCD tardó más de lo esperado, pero continuando...${NC}"
    fi
    
    crear_configuraciones_helm || echo -e "${YELLOW}⚠️ Advertencia: Error creando configuraciones Helm${NC}"
    crear_app_of_apps || echo -e "${YELLOW}⚠️ Advertencia: Error creando App of Apps${NC}"
    aplicar_infraestructura || echo -e "${YELLOW}⚠️ Advertencia: Error aplicando infraestructura${NC}"
    
    # Esperar un momento para que las aplicaciones empiecen a desplegarse
    echo -e "${BLUE}⏳ Esperando despliegue inicial de aplicaciones (90s)...${NC}"
    sleep 90
    
    configurar_port_forwards || echo -e "${YELLOW}⚠️ Advertencia: Error configurando port-forwards${NC}"
    validar_uis || echo -e "${YELLOW}⚠️ Advertencia: Error validando UIs${NC}"
    mostrar_resumen_final
    
    # Ofrecer crear clusters adicionales
    crear_clusters_adicionales
}

# ============================================================================
# EJECUCIÓN PRINCIPAL  
# ============================================================================

# Trap para limpiar port-forwards en caso de interrupción
trap 'echo -e "\n${YELLOW}🛑 Interrumpido. Limpiando port-forwards...${NC}"; pkill -f "kubectl.*port-forward" 2>/dev/null || true; exit 1' INT TERM

# Ejecutar función principal con todos los argumentos
main "$@"
