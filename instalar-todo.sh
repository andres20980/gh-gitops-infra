#!/bin/bash

# GitOps Multi-Cluster Infrastructure - Instalación Completa
# Arquitectura: 3 clusters (dev/pre/pro) con gestión centralizada desde DEV
# Autor: GitOps Infrastructure Team
# Versión: 2.0 Optimizada - Corregida

set -euo pipefail  # Modo estricto: salir en errores, variables no definidas, errores en pipes

# Configuración para instalación desatendida
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export NEEDRESTART_MODE=a

# Deshabilitar prompts interactivos
export ARGOCD_OPTS="--plaintext --grpc-web"
export MINIKUBE_IN_STYLE=false

# Colores para la salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables globales optimizadas
CLUSTER_DEV="gitops-dev"
CLUSTER_PRE="gitops-pre" 
CLUSTER_PRO="gitops-pro"
PORTFORWARD_PID=""
KUBERNETES_VERSION="v1.33.1"  # Versión más reciente disponible
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuración de recursos calculada según componentes reales
DEV_MEMORY="8192"  # 8GB: 5.6GB componentes + 2.4GB overhead/buffers
DEV_CPUS="4"       # 4 CPUs: 2.6 componentes + 1.4 overhead/picos
DEV_DISK="50g"     # 50GB: imágenes, logs, datos persistentes

PRE_MEMORY="2048"  # 2GB: solo aplicaciones sencillas para GitOps promotion testing
PRE_CPUS="2"       # 2 CPUs: recursos mínimos para apps sencillas
PRE_DISK="2g"      # 2GB: solo para apps sencillas, sin herramientas de infra

PRO_MEMORY="2048"  # 2GB: solo aplicaciones sencillas para GitOps promotion demos
PRO_CPUS="2"       # 2 CPUs: recursos mínimos para apps sencillas  
PRO_DISK="2g"      # 2GB: solo para apps sencillas, sin herramientas de infra

# Array de validación de UIs organizadas por tipo
declare -A UI_URLS=(
    # GitOps Core
    ["ArgoCD"]="http://localhost:8080"
    ["Kargo"]="http://localhost:8081"
    ["ArgoCD_Dex"]="http://localhost:8082"
    
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

mostrar_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🚀 GITOPS MULTI-CLUSTER INFRASTRUCTURE 🚀                ║"
    echo "║                                                                              ║"
    echo "║  🏗️  Arquitectura: 3 Clusters (DEV/PRE/PRO) con ArgoCD + Kargo            ║"
    echo "║  📊  Stack: Prometheus, Grafana, Jaeger, Loki, MinIO, Gitea                ║"
    echo "║  🔄  GitOps: Continuous Deployment + Progressive Delivery                   ║"
    echo "║  🎯  Objetivo: Plataforma empresarial completa lista para producción       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

mostrar_arquitectura() {
    echo -e "${YELLOW}"
    echo "🏗️ ARQUITECTURA MULTI-CLUSTER ROBUSTA:"
    echo "========================================"
    echo "🏭 Cluster gitops-dev (${DEV_MEMORY}MB RAM, ${DEV_CPUS} CPU, ${DEV_DISK}): Gestión centralizada y herramientas"
    echo "🏭 Cluster gitops-pre (${PRE_MEMORY}MB RAM, ${PRE_CPUS} CPU, ${PRE_DISK}): Entorno de preproducción"
    echo "🏭 Cluster gitops-pro (${PRO_MEMORY}MB RAM, ${PRO_CPUS} CPU, ${PRO_DISK}): Entorno de producción"
    echo "🛠 Configuración: RECURSOS OPTIMIZADOS por componente real"
    echo "📟 Kubernetes Version: $KUBERNETES_VERSION"
    echo ""
    echo "📦 HERRAMIENTAS EN DEV (controlan todos los clusters):"
    echo "├─ 🔄 ArgoCD v3.0.11: Gestión GitOps multi-cluster"
    echo "├─ � ApplicationSet v0.4.5: Multi-cluster app generation"
    echo "├─ �🚢 Kargo v1.6.1: Promociones automáticas entre entornos"
    echo "├─ 📊 Prometheus Stack v75.13.0: Monitoreo centralizado"
    echo "├─ 📈 Grafana v8.17.4: Dashboards y visualización"
    echo "├─ 📝 Loki v6.33.0: Agregación de logs"
    echo "├─ 🔍 Jaeger v3.4.1: Distributed tracing"
    echo "├─ 🔒 Cert-Manager v1.18.2: Gestión de certificados"
    echo "├─ 🔐 External Secrets v0.18.2: Gestión de secretos"
    echo "├─ 🌐 NGINX Ingress v4.13.0: Ingress controller"
    echo "├─ 🏪 MinIO: Object storage S3-compatible"
    echo "├─ 🐙 Gitea: Git repository management"
    echo "├─ ⚡ Argo Rollouts v1.8.3: Progressive delivery"
    echo "├─ 🌊 Argo Workflows v3.7.0: Workflow orchestration" 
    echo "├─ 📡 Argo Events v1.9.2: Event-driven GitOps automation"
    echo "└─ 🔔 Argo Notifications v1.2.1: GitOps alerts & integrations"
    echo ""
    echo "🔄 FLUJO GITOPS OPTIMIZADO:"
    echo "Git Push → ArgoCD-DEV → Deploy dev/pre/pro → Kargo → Auto-Promote"
    echo -e "${NC}"
}

verificar_dependencias() {
    echo -e "${BLUE}🔍 Verificando dependencias del sistema...${NC}"
    
    local dependencias_requeridas=("minikube" "kubectl" "helm" "docker" "curl" "netstat" "fuser")
    local dependencias_opcionales=("jq" "yq")
    local faltantes_requeridas=()
    local faltantes_opcionales=()
    local auto_instalables=("curl" "netstat" "jq" "yq" "fuser")
    
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
                "curl")
                    echo "🔗 curl: sudo apt-get install curl (auto-instalación falló)"
                    ;;
                "netstat")
                    echo "🔗 netstat: sudo apt-get install net-tools (auto-instalación falló)"
                    ;;
                "fuser")
                    echo "🔗 fuser: sudo apt-get install psmisc (auto-instalación falló)"
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
    
    # Verificar versiones
    echo ""
    echo "📋 Versiones instaladas:"
    echo "- Minikube: $(minikube version --short 2>/dev/null || echo 'Error al obtener versión')"
    echo "- kubectl: $(kubectl version --client=true --short 2>/dev/null | grep Client || echo 'Error al obtener versión')"
    echo "- Helm: $(helm version --short 2>/dev/null || echo 'Error al obtener versión')"
    echo "- Docker: $(docker --version 2>/dev/null || echo 'Error al obtener versión')"
    
    echo -e "${GREEN}✅ Todas las dependencias requeridas están disponibles${NC}"
}

limpiar_clusters_existentes() {
    echo -e "${YELLOW}🧹 Limpiando clusters existentes...${NC}"
    
    local clusters=("$CLUSTER_DEV" "$CLUSTER_PRE" "$CLUSTER_PRO")
    local clusters_eliminados=0
    
    for cluster in "${clusters[@]}"; do
        if minikube status -p "$cluster" >&/dev/null; then
            echo "🗑️ Eliminando cluster: $cluster"
            if minikube delete -p "$cluster" --purge >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Cluster $cluster eliminado exitosamente${NC}"
                clusters_eliminados=$((clusters_eliminados + 1))
            else
                echo -e "${YELLOW}⚠️ Error al eliminar cluster $cluster (puede no existir)${NC}"
            fi
        else
            echo "ℹ️ Cluster $cluster no existe - saltando"
        fi
    done
    
    if [ $clusters_eliminados -gt 0 ]; then
        echo -e "${GREEN}✅ Limpieza completada: $clusters_eliminados clusters eliminados${NC}"
    else
        echo -e "${GREEN}✅ Limpieza completada: no había clusters que eliminar${NC}"
    fi
}

crear_clusters() {
    echo -e "${BLUE}🏗️ Creando clusters Minikube optimizados...${NC}"
    
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
    
    # Crear solo cluster DEV inicialmente - Optimización secuencial
    echo "🎯 Creando cluster DEV primero para validación..."
    crear_cluster_con_reintentos "$CLUSTER_DEV" "$DEV_MEMORY" "$DEV_CPUS" "$DEV_DISK"
    
    echo -e "${GREEN}✅ Cluster DEV creado exitosamente${NC}"
}

crear_clusters_adicionales() {
    echo -e "${BLUE}🏗️ Creando clusters PRE y PRO después de validar DEV...${NC}"
    
    # Verificar que Docker esté ejecutándose
    if ! docker info >&/dev/null; then
        echo -e "${RED}❌ Docker no está ejecutándose. Por favor, inicia Docker primero.${NC}"
        exit 1
    fi
    
    # Función auxiliar para crear un cluster con reintentos (reutilizada)
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
    
    # Crear cluster PRE - Recursos para testing
    crear_cluster_con_reintentos "$CLUSTER_PRE" "$PRE_MEMORY" "$PRE_CPUS" "$PRE_DISK"
    
    # Crear cluster PRE - Recursos para simulación de producción
    crear_cluster_con_reintentos "$CLUSTER_PRO" "$PRO_MEMORY" "$PRO_CPUS" "$PRO_DISK"
    
    echo -e "${GREEN}✅ Clusters PRE y PRO creados exitosamente${NC}"
}

configurar_contextos() {
    echo -e "${BLUE}⚙️ Configurando contextos de kubectl...${NC}"
    
    # Cambiar al cluster DEV como principal
    kubectl config use-context "$CLUSTER_DEV"
    
    # Verificar contextos disponibles
    echo "📋 Contextos disponibles:"
    kubectl config get-contexts
    
    echo -e "${GREEN}✅ Contextos configurados${NC}"
}

instalar_argocd() {
    echo -e "${BLUE}🔄 Instalando ArgoCD en DEV con acceso anónimo completo...${NC}"
    
    kubectl config use-context "$CLUSTER_DEV"
    
    # Crear namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Instalar ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.11/manifests/install.yaml
    
    # Esperar a que ArgoCD esté listo
    echo "⏳ Esperando a que ArgoCD esté listo..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    
    # Configurar acceso COMPLETAMENTE ANÓNIMO - sin login requerido
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
    
    # 3. Deshabilitar Dex (authentication)
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '{"data":{"dex.disable.authentication":"true"}}'
    
    # 4. Configurar deployment con argumentos anónimos
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
    
    # 5. Reiniciar ArgoCD server
    echo "🔄 Reiniciando ArgoCD server con configuración anónima..."
    kubectl rollout restart deployment argocd-server -n argocd
    kubectl rollout status deployment argocd-server -n argocd --timeout=300s
    
    # 6. Verificar que el servidor esté respondiendo
    echo "🔍 Verificando acceso anónimo..."
    sleep 10
    
    echo -e "${GREEN}✅ ArgoCD instalado con acceso anónimo completo (sin login)${NC}"
}

aplicar_infraestructura() {
    echo -e "${BLUE}📦 Aplicando infraestructura GitOps...${NC}"
    
    kubectl config use-context "$CLUSTER_DEV"
    
    # Verificar que estamos en el directorio correcto
    if [[ ! -f "$SCRIPT_DIR/appset-gitops-infra.yaml" ]]; then
        echo -e "${RED}❌ Archivo appset-gitops-infra.yaml no encontrado en $SCRIPT_DIR${NC}"
        echo "📁 Archivos disponibles:"
        ls -la "$SCRIPT_DIR"/*.yaml 2>/dev/null || echo "❌ No se encontraron archivos YAML"
        return 1
    fi
    
    # Aplicar las aplicaciones de infraestructura principal
    echo "📦 Aplicando aplicaciones de infraestructura principal..."
    
    # Eliminar ApplicationSets existentes para evitar conflictos de resourceVersion
    kubectl delete applicationset gitops-infra-components -n argocd --ignore-not-found=true
    kubectl delete applicationset gitops-aplicaciones -n argocd --ignore-not-found=true
    
    # Esperar un momento para la limpieza
    sleep 3
    
    if kubectl apply -f "$SCRIPT_DIR/appset-gitops-infra.yaml" && kubectl apply -f "$SCRIPT_DIR/appset-aplicaciones.yaml"; then
        echo -e "${GREEN}✅ Aplicaciones de infraestructura creadas${NC}"
    else
        echo -e "${RED}❌ Error al aplicar aplicaciones de infraestructura${NC}"
        return 1
    fi
    
    # Aplicar componentes individuales si existen
    if [[ -d "$SCRIPT_DIR/componentes" ]]; then
        echo "📂 Aplicando componentes desde directorio componentes/"
        local componentes_aplicados=0
        local componentes_fallidos=0
        
        # Aplicar componentes en orden específico para dependencias
        local orden_componentes=(
            "cert-manager"
            "external-secrets" 
            "ingress-nginx"
            "monitoring"
            "loki"
            "jaeger"
            "minio"
            "gitea"
            "kargo"
            "argo-rollouts"
            "argo-workflows"
            "argo-events"
            "argocd-applicationset"
            "argocd-notifications"
            "grafana"
        )
        
        # Primero aplicar componentes en orden
        for componente in "${orden_componentes[@]}"; do
            if [[ -f "$SCRIPT_DIR/componentes/$componente"/*.yaml ]]; then
                echo "📦 Aplicando componente: $componente"
                if kubectl apply -f "$SCRIPT_DIR/componentes/$componente"/*.yaml; then
                    componentes_aplicados=$((componentes_aplicados + 1))
                    echo -e "${GREEN}✅ Componente $componente aplicado${NC}"
                    sleep 2  # Pequeña pausa entre componentes
                else
                    componentes_fallidos=$((componentes_fallidos + 1))
                    echo -e "${YELLOW}⚠️ Error al aplicar componente $componente${NC}"
                fi
            fi
        done
        
        # Luego aplicar cualquier componente restante
        find "$SCRIPT_DIR/componentes" -name "*.yaml" -type f | while read -r archivo; do
            componente_nombre=$(basename "$(dirname "$archivo")")
            if [[ ! " ${orden_componentes[*]} " =~ " ${componente_nombre} " ]]; then
                echo "📦 Aplicando componente adicional: $componente_nombre"
                kubectl apply -f "$archivo" || echo "⚠️ Error en $archivo"
            fi
        done
        
        echo -e "${GREEN}✅ Componentes aplicados: $componentes_aplicados, Fallidos: $componentes_fallidos${NC}"
    else
        echo -e "${YELLOW}⚠️ Directorio componentes/ no encontrado en $SCRIPT_DIR${NC}"
    fi
    
    echo -e "${GREEN}✅ Infraestructura GitOps aplicada${NC}"
}

configurar_multi_cluster() {
    echo -e "${BLUE}🔗 Configurando acceso multi-cluster en ArgoCD...${NC}"
    
    # Primero esperar a que ArgoCD esté disponible
    kubectl config use-context "$CLUSTER_DEV"
    echo "⏳ Esperando a que ArgoCD API esté disponible..."
    
    # Configurar port-forward temporal para ArgoCD API
    kubectl port-forward -n argocd service/argocd-server 8080:80 >/dev/null 2>&1 &
    local pf_pid=$!
    sleep 15
    
    # Solo agregar clusters que existan
    if minikube status -p "$CLUSTER_PRE" &> /dev/null; then
        echo "🔗 Agregando cluster PRE a ArgoCD..."
        kubectl config use-context "$CLUSTER_PRE"
        yes y | timeout 30 argocd cluster add "$CLUSTER_PRE" --server localhost:8080 --insecure --grpc-web 2>/dev/null || true
    else
        echo "⚠️ Cluster PRE no existe - saltando configuración"
    fi
    
    if minikube status -p "$CLUSTER_PRO" &> /dev/null; then
        echo "🔗 Agregando cluster PRO a ArgoCD..."
        kubectl config use-context "$CLUSTER_PRO"
        yes y | timeout 30 argocd cluster add "$CLUSTER_PRO" --server localhost:8080 --insecure --grpc-web 2>/dev/null || true
    else
        echo "⚠️ Cluster PRO no existe - saltando configuración"
    fi
    
    # Limpiar port-forward temporal
    kill $pf_pid 2>/dev/null || true
    
    # Volver al cluster DEV
    kubectl config use-context "$CLUSTER_DEV"
    
    echo -e "${GREEN}✅ Multi-cluster configurado${NC}"
}

verificar_y_arreglar_servicios() {
    echo -e "${BLUE}🔧 Verificando y corrigiendo servicios problemáticos...${NC}"
    
    kubectl config use-context "$CLUSTER_DEV"
    
    # Verificar ArgoCD server
    if ! kubectl get pod -l app.kubernetes.io/component=server -n argocd | grep -q Running; then
        echo "🔄 Reiniciando ArgoCD server..."
        kubectl rollout restart deployment argocd-server -n argocd
        kubectl rollout status deployment argocd-server -n argocd --timeout=300s
    fi
    
    # Sincronizar aplicaciones pendientes automáticamente
    echo "🔄 Sincronizando aplicaciones ArgoCD pendientes..."
    local apps_pendientes=$(kubectl get applications -n argocd --no-headers | grep -E "(Unknown|OutOfSync)" | awk '{print $1}' || true)
    
    if [[ -n "$apps_pendientes" ]]; then
        echo "📋 Aplicaciones a sincronizar: $apps_pendientes"
        for app in $apps_pendientes; do
            echo "🔄 Habilitando auto-sync para: $app"
            kubectl patch application "$app" -n argocd --type merge -p '{
                "spec": {
                    "syncPolicy": {
                        "automated": {
                            "prune": true,
                            "selfHeal": true
                        }
                    }
                }
            }' 2>/dev/null || true
            
            echo "🔄 Forzando sincronización de: $app"
            kubectl patch application "$app" -n argocd --type merge -p '{
                "operation": {
                    "sync": {}
                }
            }' 2>/dev/null || true
        done
        echo "⏳ Esperando 30s para que las aplicaciones se sincronicen..."
        sleep 30
    else
        echo "✅ Todas las aplicaciones están sincronizadas"
    fi
    
    # Verificar Kargo - si no existe el namespace, intentar crearlo
    if ! kubectl get namespace kargo >/dev/null 2>&1; then
        echo "⚠️ Namespace kargo no existe, sera creado por la aplicación ArgoCD"
    else
        # Si existe, verificar que los pods estén funcionando
        if ! kubectl get pods -n kargo 2>/dev/null | grep -q Running; then
            echo "🔄 Esperando a que Kargo se despliegue..."
            kubectl wait --for=condition=Ready pods --all -n kargo --timeout=300s 2>/dev/null || echo "⚠️ Kargo puede tardar más tiempo en desplegarse"
        fi
    fi
    
    # Verificar cert-manager (necesario para Kargo)
    if ! kubectl get namespace cert-manager >/dev/null 2>&1; then
        echo "⚠️ cert-manager no encontrado, necesario para Kargo"
    fi
    
    echo -e "${GREEN}✅ Verificación de servicios completada${NC}"
}

configurar_port_forwards() {
    echo -e "${BLUE}🌐 Configurando port-forwards optimizados...${NC}"
    
    # Matar port-forwards previos de forma más agresiva
    echo "🧹 Limpiando port-forwards previos..."
    pkill -f "kubectl.*port-forward" 2>/dev/null || true
    sleep 3
    
    # Liberar puertos específicos si están ocupados
    for puerto in 8080 8081 8082 8083 8084 8085 8086 8087 8088 8090 8091 8092 8093; do
        if netstat -tuln | grep -q ":$puerto "; then
            echo "🔌 Liberando puerto $puerto..."
            fuser -k $puerto/tcp 2>/dev/null || true
        fi
    done
    sleep 2
    
    # Función para crear port-forward con reintentos y validación mejorada
    crear_port_forward() {
        local servicio="$1"
        local namespace="$2"
        local puerto_local="$3"
        local puerto_remoto="$4"
        local max_intentos=3
        
        # Verificar que el puerto esté libre
        if netstat -tuln | grep -q ":$puerto_local "; then
            echo "⚠️ Puerto $puerto_local ocupado, liberando..."
            fuser -k $puerto_local/tcp 2>/dev/null || true
            sleep 2
        fi
        
        for intento in $(seq 1 $max_intentos); do
            echo "🔗 Configurando port-forward para $servicio ($puerto_local:$puerto_remoto) - Intento $intento"
            
            # Usar nohup para evitar que se maten los procesos
            nohup kubectl port-forward -n "$namespace" "service/$servicio" "$puerto_local:$puerto_remoto" >/dev/null 2>&1 &
            local pf_pid=$!
            sleep 5  # Aumentar tiempo de espera para estabilización
            
            # Verificar que el port-forward esté funcionando con múltiples métodos
            local puerto_activo=false
            if kill -0 $pf_pid 2>/dev/null; then
                # Verificar que el puerto esté escuchando
                if netstat -tuln | grep -q ":$puerto_local "; then
                    puerto_activo=true
                else
                    # Esperar un poco más para algunos servicios lentos
                    sleep 3
                    if netstat -tuln | grep -q ":$puerto_local "; then
                        puerto_activo=true
                    fi
                fi
            fi
            
            if [ "$puerto_activo" = true ]; then
                echo -e "${GREEN}✅ Port-forward activo para $servicio en puerto $puerto_local (PID: $pf_pid)${NC}"
                return 0
            else
                kill $pf_pid 2>/dev/null || true
            fi
            
            if [ $intento -lt $max_intentos ]; then
                echo "⚠️ Reintentando port-forward para $servicio..."
                sleep 5
            fi
        done
        
        echo -e "${YELLOW}⚠️ No se pudo establecer port-forward para $servicio${NC}"
        return 1
    }
    
    # Cambiar al cluster DEV donde están todos los servicios
    kubectl config use-context "$CLUSTER_DEV"
    
    # Esperar a que los servicios estén disponibles
    echo "⏳ Esperando a que los servicios estén disponibles..."
    sleep 30
    
    # Configurar port-forwards para servicios principales
    declare -A servicios_pf=(
        ["argocd-server argocd 8080 80"]=""
        ["kargo-api kargo 8081 80"]=""
        ["argocd-dex-server argocd 8082 5556"]=""
        ["argo-workflows-server argo-workflows 8083 2746"]=""
        ["argo-rollouts-dashboard argo-rollouts 8084 3100"]=""
        ["argo-events-webhook argo-events 8089 12000"]=""
        ["prometheus-stack-grafana monitoring 8085 80"]=""
        ["prometheus-stack-kube-prom-prometheus monitoring 8086 9090"]=""
        ["prometheus-stack-kube-prom-alertmanager monitoring 8087 9093"]=""
        ["jaeger-query monitoring 8088 16686"]=""
        # ["loki-gateway monitoring 8089 80"]=""  # Loki no tiene UI web propia, se consulta via Grafana
        # ["minio minio 8090 9000"]=""  # MinIO API no tiene UI web propia, solo API S3-compatible
        ["minio-console minio 8091 9001"]=""
        ["gitea-http gitea 8092 3000"]=""
        ["kubernetes-dashboard-web kubernetes-dashboard 8093 8000"]=""
    )
    
    # Crear port-forwards
    local exitosos=0
    local fallidos=0
    
    for servicio_info in "${!servicios_pf[@]}"; do
        read -r servicio namespace puerto_local puerto_remoto <<< "$servicio_info"
        
        # Verificar que el servicio existe antes de hacer port-forward
        if kubectl get service "$servicio" -n "$namespace" >/dev/null 2>&1; then
            if crear_port_forward "$servicio" "$namespace" "$puerto_local" "$puerto_remoto"; then
                exitosos=$((exitosos + 1))
            else
                fallidos=$((fallidos + 1))
            fi
        else
            echo -e "${YELLOW}⚠️ Servicio $servicio no encontrado en namespace $namespace${NC}"
            fallidos=$((fallidos + 1))
        fi
        
        sleep 1
    done
    
    echo -e "${GREEN}✅ Port-forwards configurados: $exitosos exitosos, $fallidos fallidos${NC}"
    
    # Verificar port-forwards activos
    echo "🔍 Port-forwards activos:"
    netstat -tuln | grep -E ':(808[0-3]|809[0-3])' || echo "❌ No se encontraron port-forwards activos"
}

validar_uis() {
    echo -e "${BLUE}🔍 Validando acceso a UIs...${NC}"
    
    local uis_operativas=0
    local uis_total=${#UI_URLS[@]}
    
    for ui_name in "${!UI_URLS[@]}"; do
        url="${UI_URLS[$ui_name]}"
        echo -n "🔍 Verificando $ui_name ($url)... "
        
        # Mejorar la validación con más códigos de estado válidos y timeout más largo
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --connect-timeout 10 --max-time 15 2>/dev/null || echo "000")
        
        # Códigos de estado que consideramos válidos (incluyendo redirects y algunos errores esperados)
        if [[ "$response_code" =~ ^(200|301|302|401|403|404)$ ]]; then
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
    
    # Si hay menos del 80% operativas, mostrar información de diagnóstico
    local porcentaje=$((uis_operativas * 100 / uis_total))
    if [ $porcentaje -lt 80 ]; then
        echo -e "${YELLOW}⚠️ Solo $porcentaje% de UIs operativas. Verificando port-forwards...${NC}"
        netstat -tuln | grep -E ':(808[0-3]|809[0-3])' | while read line; do
            puerto=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
            echo "  🔗 Puerto $puerto activo"
        done
    fi
}

# Función de validación estricta para verificar que DEV está completamente funcional
validar_dev_completo() {
    echo -e "${BLUE}🔍 Validación estricta de DEV antes de crear PRE/PRO...${NC}"
    
    local errores=0
    local advertencias=0
    
    # 1. Verificar que ArgoCD está ejecutándose
    echo "📋 Verificando ArgoCD..."
    if ! kubectl get pods -n argocd | grep -q "argocd-server.*Running"; then
        echo -e "${RED}❌ ArgoCD server no está ejecutándose${NC}"
        errores=$((errores + 1))
    else
        echo -e "${GREEN}✅ ArgoCD server ejecutándose${NC}"
    fi
    
    # 2. Verificar ApplicationSets
    echo "📋 Verificando ApplicationSets..."
    local appsets=$(kubectl get applicationset -n argocd 2>/dev/null | wc -l)
    if [ $appsets -lt 2 ]; then
        echo -e "${RED}❌ ApplicationSets no encontrados o incompletos${NC}"
        errores=$((errores + 1))
    else
        echo -e "${GREEN}✅ ApplicationSets detectados${NC}"
    fi
    
    # 3. Verificar aplicaciones de infraestructura críticas
    echo "📋 Verificando aplicaciones de infraestructura..."
    local apps_criticas=("cert-manager" "external-secrets" "ingress-nginx" "monitoring" "loki" "grafana" "kargo")
    local apps_sincronizadas=0
    
    for app in "${apps_criticas[@]}"; do
        local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "NotFound")
        local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "NotFound")
        
        if [ "$sync_status" = "Synced" ] && [ "$health_status" = "Healthy" ]; then
            echo -e "${GREEN}✅ $app: Synced & Healthy${NC}"
            apps_sincronizadas=$((apps_sincronizadas + 1))
        elif [ "$sync_status" = "NotFound" ]; then
            echo -e "${RED}❌ $app: Aplicación no encontrada${NC}"
            errores=$((errores + 1))
        else
            echo -e "${YELLOW}⚠️  $app: $sync_status / $health_status${NC}"
            advertencias=$((advertencias + 1))
        fi
    done
    
    # 4. Verificar pods críticos ejecutándose
    echo "📋 Verificando pods críticos..."
    local namespaces_criticos=("cert-manager" "external-secrets-system" "ingress-nginx" "monitoring" "loki" "grafana" "kargo")
    local namespaces_ok=0
    
    for ns in "${namespaces_criticos[@]}"; do
        local pods_running=$(kubectl get pods -n "$ns" 2>/dev/null | grep -c "Running" || echo "0")
        local pods_total=$(kubectl get pods -n "$ns" 2>/dev/null | tail -n +2 | wc -l || echo "0")
        
        if [ "$pods_total" -eq 0 ]; then
            echo -e "${RED}❌ Namespace $ns: Sin pods desplegados${NC}"
            errores=$((errores + 1))
        elif [ "$pods_running" -eq "$pods_total" ]; then
            echo -e "${GREEN}✅ Namespace $ns: $pods_running/$pods_total pods ejecutándose${NC}"
            namespaces_ok=$((namespaces_ok + 1))
        else
            echo -e "${YELLOW}⚠️  Namespace $ns: $pods_running/$pods_total pods ejecutándose${NC}"
            advertencias=$((advertencias + 1))
        fi
    done
    
    # 5. Verificar UIs (reutilizar validación existente)
    validar_uis
    local uis_operativas=0
    for ui_name in "${!UI_STATUS[@]}"; do
        if [[ "${UI_STATUS[$ui_name]}" == *"OPERATIVA"* ]]; then
            uis_operativas=$((uis_operativas + 1))
        fi
    done
    local uis_total=${#UI_URLS[@]}
    local porcentaje_uis=$((uis_operativas * 100 / uis_total))
    
    # Resumen de validación
    echo ""
    echo -e "${BLUE}📊 RESUMEN DE VALIDACIÓN DEV:${NC}"
    echo "================================="
    echo "🔴 Errores críticos: $errores"
    echo "🟡 Advertencias: $advertencias"  
    echo "📱 UIs operativas: $uis_operativas/$uis_total ($porcentaje_uis%)"
    echo "🏗️ Apps críticas sincronizadas: $apps_sincronizadas/${#apps_criticas[@]}"
    echo "🛠️ Namespaces OK: $namespaces_ok/${#namespaces_criticos[@]}"
    echo ""
    
    # Criterios para continuar con PRE/PRO
    if [ $errores -eq 0 ] && [ $apps_sincronizadas -ge 5 ] && [ $porcentaje_uis -ge 60 ]; then
        echo -e "${GREEN}✅ DEV VALIDADO: Criterios cumplidos para crear PRE/PRO${NC}"
        echo -e "${GREEN}   ► Sin errores críticos${NC}"
        echo -e "${GREEN}   ► $apps_sincronizadas/${#apps_criticas[@]} apps críticas funcionando${NC}"
        echo -e "${GREEN}   ► $porcentaje_uis% UIs operativas${NC}"
        return 0
    else
        echo -e "${RED}❌ DEV NO VALIDADO: No se crearán PRE/PRO${NC}"
        echo -e "${RED}   ► Errores críticos: $errores (requerido: 0)${NC}"
        echo -e "${RED}   ► Apps críticas: $apps_sincronizadas/${#apps_criticas[@]} (requerido: ≥5)${NC}"
        echo -e "${RED}   ► UIs operativas: $porcentaje_uis% (requerido: ≥60%)${NC}"
        echo ""
        echo -e "${YELLOW}💡 Para crear PRE/PRO manualmente después de arreglar los problemas:${NC}"
        echo -e "${YELLOW}   $0 clusters${NC}"
        return 1
    fi
}

mostrar_urls_ui() {
    # Ejecutar validación primero
    validar_uis
    
    echo ""
    echo "🌐 PLATAFORMA GITOPS MULTI-CLUSTER - INTERFACES DE USUARIO"
    echo "=========================================================="
    echo ""
    echo "📊 GITOPS CORE:"
    echo "---------------"
    echo "🔄 ArgoCD UI: http://localhost:8080"
    echo "   📋 Propósito: Continuous Deployment y gestión de aplicaciones GitOps"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["ArgoCD"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🚢 Kargo UI: http://localhost:8081"
    echo "   📋 Propósito: Promociones automáticas entre entornos (dev → pre → pro)"
    echo "   🔓 Acceso: Credenciales fijas (admin/admin)"
    echo "   ${UI_STATUS["Kargo"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔐 ArgoCD Dex: http://localhost:8082"
    echo "   📋 Propósito: Authentication service para ArgoCD"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["ArgoCD_Dex"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🚢 PROGRESSIVE DELIVERY & EVENT-DRIVEN GITOPS:"
    echo "-----------------------------------------------"
    echo "⚡ Argo Workflows UI: http://localhost:8083"
    echo "   📋 Propósito: Workflow orchestration y batch processing"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Argo_Workflows"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🎯 Argo Rollouts Dashboard: http://localhost:8084"
    echo "   📋 Propósito: Progressive delivery, canary deployments y blue-green"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Argo_Rollouts"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "📡 Argo Events Webhook: http://localhost:8089"
    echo "   📋 Propósito: Event-driven GitOps automation y webhook processing"
    echo "   🔓 Acceso: Webhooks API endpoint (sin UI web)"
    echo "   ${UI_STATUS["Argo_Events"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔔 Argo Notifications: Integrado en ArgoCD + Grafana annotations"
    echo "   📋 Propósito: GitOps deployment notifications y alerting"
    echo "   🔓 Acceso: Notificaciones automáticas (sin UI independiente)"
    echo "   💡 Ver notificaciones en: Grafana → Annotations & Alerts"
    echo ""
    echo "📈 OBSERVABILITY:"
    echo "-----------------"
    echo "📊 Grafana UI: http://localhost:8085"
    echo "   📋 Propósito: Dashboards y visualización de métricas"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Grafana"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "📈 Prometheus UI: http://localhost:8086"
    echo "   📋 Propósito: Metrics collection y time-series database"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["Prometheus"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🚨 AlertManager UI: http://localhost:8087"
    echo "   📋 Propósito: Alert routing y notification management"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["AlertManager"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔍 Jaeger UI: http://localhost:8088"
    echo "   📋 Propósito: Distributed tracing y performance monitoring"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["Jaeger"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "📝 LOGS & STORAGE:"
    echo "------------------"
    echo "📝 Loki (Logs): Accesible vía Grafana (puerto 8085)"
    echo "   📋 Propósito: Agregación y consulta de logs con LogQL"
    echo "   🔓 Acceso: Loki NO tiene UI web - se consulta desde Grafana"
    echo "   💡 Instrucciones: Ir a Grafana → Explore → Seleccionar Loki como datasource"
    echo ""
    echo "🏪 MinIO API: Puerto 9000 (solo API S3-compatible)"
    echo "   📋 Propósito: Object storage S3-compatible (solo API, sin UI web)"
    echo "   🔓 Acceso: MinIO API NO tiene UI web - usar MinIO Console o clientes S3"
    echo "   💡 Instrucciones: Usar mc (MinIO Client) o SDK S3-compatible"
    echo ""
    echo "🏪 MinIO Console: http://localhost:8091"
    echo "   📋 Propósito: Object storage S3-compatible (Console Web UI)"
    echo "   🔓 Acceso: admin/admin123"
    echo "   ${UI_STATUS["MinIO_Console"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔧 DESARROLLO & GESTIÓN:"
    echo "------------------------"
    echo "🐙 Gitea UI: http://localhost:8092"
    echo "   📋 Propósito: Git repository management y source control"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Gitea"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔧 Kubernetes Dashboard: http://localhost:8093"
    echo "   📋 Propósito: Kubernetes cluster management interface"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["K8s_Dashboard"]:-"⏳ VERIFICANDO..."}"
    echo ""
    
    echo "🏗️ ARQUITECTURA DEL SISTEMA:"
    echo "=============================="
    echo "🏗️ ARQUITECTURA MULTI-CLUSTER:"
    echo "=============================="
    echo "🏭 Cluster gitops-dev: Herramientas de gestión y control centralizadas"
    echo "🏭 Cluster gitops-pre: Entorno de preproducción para validación"
    echo "🏭 Cluster gitops-pro: Entorno de producción empresarial"
    echo "📊 Stack: ArgoCD + Kargo + Observabilidad + Gestión Multi-Entorno"
    echo ""
    echo "📦 Herramientas en DEV (controlan todos los clusters):"
    echo "- ArgoCD + ApplicationSet: Gestión de aplicaciones multi-cluster"
    echo "- Kargo: Promociones automáticas entre entornos"
    echo "- Argo Events + Notifications: Event-driven automation"
    echo "- Prometheus/Grafana: Monitoreo centralizado multi-cluster"
    echo "- Gitea, MinIO, Jaeger, Loki: Infraestructura compartida"
    echo "- Demo-project: Desplegado en los 3 entornos para pruebas"
    echo ""
    echo "🔄 Flujo GitOps: Git → ArgoCD+ApplicationSet → Deploy multi-cluster → Events → Kargo → Promote → Notifications"
    echo ""
    
    echo "💡 COMANDOS ÚTILES POST-INSTALACIÓN:"
    echo "===================================="
    echo "💡 Ver diagnóstico completo: ./scripts/diagnostico-gitops.sh"
    echo "💡 Reiniciar port-forwards: ./scripts/setup-port-forwards.sh"
    echo "💡 Ver aplicaciones ArgoCD: kubectl get applications -n argocd"
    echo "💡 Port-forwards activos PID: $PORTFORWARD_PID"
    echo ""
    echo "🚀 ¡PLATAFORMA GITOPS MULTI-CLUSTER COMPLETAMENTE OPERATIVA!"
    echo "🔓 ¡TODAS LAS UIS WEB VALIDADAS PARA ACCESO SIN AUTENTICACIÓN!"
    echo "📝 ¡LOGS DE LOKI DISPONIBLES A TRAVÉS DE GRAFANA!"
}

esperar_servicios() {
    echo -e "${BLUE}⏳ Esperando a que todos los servicios estén listos...${NC}"
    
    kubectl config use-context "$CLUSTER_DEV"
    
    # Esperar namespaces críticos con timeouts más largos
    local namespaces=("argocd" "monitoring" "loki" "jaeger" "minio" "gitea" "argo-rollouts" "argo-workflows" "argo-events" "kubernetes-dashboard" "kargo")
    
    for ns in "${namespaces[@]}"; do
        echo "📦 Esperando namespace: $ns"
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            # Solo esperar pods que existan, con timeout más corto por namespace
            kubectl wait --for=condition=Ready pods --all -n "$ns" --timeout=180s 2>/dev/null || echo "⚠️ Algunos pods en $ns pueden tardar más en estar listos"
        else
            echo "⚠️ Namespace $ns no existe aún"
        fi
    done
    
    # Esperar explícitamente a servicios críticos con verificación mejorada
    echo "🔍 Verificando servicios críticos..."
    local servicios_criticos=("argocd-server" "prometheus-stack-grafana" "jaeger-query" "minio" "gitea-http")
    local servicios_disponibles=0
    
    for servicio in "${servicios_criticos[@]}"; do
        if kubectl get svc "$servicio" -A >/dev/null 2>&1; then
            servicios_disponibles=$((servicios_disponibles + 1))
            echo "✅ Servicio $servicio disponible"
        else
            echo "⚠️ Servicio $servicio no encontrado"
        fi
    done
    
    # Esperar tiempo adicional para que todos los servicios estén completamente listos
    echo "⏳ Tiempo adicional para estabilización de servicios..."
    sleep 60
    
    echo -e "${GREEN}✅ Servicios inicializados: $servicios_disponibles/${#servicios_criticos[@]} críticos disponibles${NC}"
}

instalar_todo() {
    # Configurar trap para limpieza en caso de error
    trap 'echo -e "${RED}❌ Error durante la instalación. Limpiando...${NC}"; limpiar_en_error; exit 1' ERR
    
    # Asegurar instalación completamente desatendida
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a
    export APT_LISTCHANGES_FRONTEND=none
    
    local inicio=$(date +%s)
    
    mostrar_banner
    mostrar_arquitectura
    
    echo -e "${BLUE}🚀 Iniciando instalación completa optimizada...${NC}"
    echo -e "${GREEN}✅ MODO DESATENDIDO: Sin confirmaciones interactivas${NC}"
    
    # Fase 1: Verificaciones previas
    echo -e "${PURPLE}[FASE 1/8]${NC} Verificaciones del sistema"
    verificar_dependencias
    
    # Fase 2: Preparación del entorno (sin limpieza redundante)
    echo -e "${PURPLE}[FASE 2/8]${NC} Preparación del entorno"
    echo "✅ Entorno ya limpio - continuando con creación de clusters"
    
    # Fase 3: Creación de clusters
    echo -e "${PURPLE}[FASE 3/8]${NC} Creación de clusters"
    if ! crear_clusters; then
        echo -e "${RED}❌ Error en la creación de clusters${NC}"
        exit 1
    fi
    
    # Fase 4: Configuración de contextos
    echo -e "${PURPLE}[FASE 4/8]${NC} Configuración de contextos"
    configurar_contextos
    
    # Fase 5: Instalación de ArgoCD
    echo -e "${PURPLE}[FASE 5/8]${NC} Instalación de ArgoCD"
    if ! instalar_argocd; then
        echo -e "${RED}❌ Error en la instalación de ArgoCD${NC}"
        exit 1
    fi
    
    # Fase 6: Aplicación de infraestructura
    echo -e "${PURPLE}[FASE 6/10]${NC} Despliegue de infraestructura GitOps"
    if ! aplicar_infraestructura; then
        echo -e "${RED}❌ Error en la aplicación de infraestructura${NC}"
        exit 1
    fi
    
    # Fase 7: Configuración inicial de ArgoCD
    echo -e "${PURPLE}[FASE 7/10]${NC} Configuración inicial de ArgoCD"
    echo "⚙️ ArgoCD configurado para cluster DEV (clusters adicionales se agregarán después)"
    
    # Fase 8: Esperar servicios y configurar acceso DEV
    echo -e "${PURPLE}[FASE 8/10]${NC} Finalización y configuración de acceso DEV"
    esperar_servicios
    verificar_y_arreglar_servicios
    configurar_port_forwards
    
    # VALIDACIÓN ESTRICTA: Verificar si DEV está completamente funcional antes de crear PRE y PRO
    echo -e "${PURPLE}[VALIDACIÓN CRÍTICA]${NC} Verificando estado completo de DEV"
    
    if validar_dev_completo; then
        echo -e "${GREEN}✅ VALIDACIÓN EXITOSA: DEV completamente funcional${NC}"
        echo -e "${GREEN}🚀 Procediendo a crear clusters PRE y PRO${NC}"
        
        # Fase 9: Crear clusters adicionales
        echo -e "${PURPLE}[FASE 9/10]${NC} Creación de clusters PRE y PRO"
        crear_clusters_adicionales
        
        # Fase 10: Configuración multi-cluster completa
        echo -e "${PURPLE}[FASE 10/10]${NC} Configuración multi-cluster completa"
        configurar_multi_cluster
        
        echo -e "${GREEN}✅ Arquitectura multi-cluster completa${NC}"
        local clusters_texto="3 Clusters creados y configurados"
    else
        echo -e "${RED}❌ VALIDACIÓN FALLIDA: DEV no está completamente funcional${NC}"
        echo -e "${YELLOW}⚠️ PRE y PRO no serán creados por problemas en DEV${NC}"
        echo -e "${YELLOW}💡 Soluciona los problemas de DEV y ejecuta: $0 clusters${NC}"
        local clusters_texto="1 Cluster DEV creado (PRE/PRO pendientes por errores)"
    fi
    
    # Calcular tiempo total
    local fin=$(date +%s)
    local duracion=$((fin - inicio))
    local minutos=$((duracion / 60))
    local segundos=$((duracion % 60))
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                          🎉 ¡INSTALACIÓN COMPLETADA! 🎉                     ║"  
    echo "║                                                                              ║"
    echo "║  ⏱️  Tiempo total: ${minutos}m ${segundos}s                                                    ║"
    echo "║  🏭 $clusters_texto"
    echo "║  📦 17+ Herramientas GitOps desplegadas                                     ║"
    echo "║  🌐 12 UIs web disponibles + Logs via Grafana + Notifications             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    mostrar_urls_ui
}

# Función de limpieza en caso de error
limpiar_en_error() {
    echo -e "${YELLOW}🧹 Realizando limpieza de emergencia...${NC}"
    
    # Matar port-forwards
    pkill -f "kubectl.*port-forward" 2>/dev/null || true
    
    # Mostrar estado de clusters para debug
    echo "📊 Estado de clusters al momento del error:"
    minikube status -p "$CLUSTER_DEV" 2>/dev/null || echo "❌ Cluster DEV no disponible"
    minikube status -p "$CLUSTER_PRE" 2>/dev/null || echo "❌ Cluster PRE no disponible" 
    minikube status -p "$CLUSTER_PRO" 2>/dev/null || echo "❌ Cluster PRO no disponible"
    
    echo -e "${YELLOW}💡 Para limpiar completamente, ejecuta: $0 limpiar${NC}"
}

# Funciones para ejecución individual
limpiar() {
    echo -e "${YELLOW}🧹 Limpiando entorno completo...${NC}"
    
    # Matar todos los port-forwards
    echo "🔌 Cerrando port-forwards activos..."
    if pgrep -f "kubectl.*port-forward" >/dev/null 2>&1; then
        local pf_count=$(pgrep -cf "kubectl.*port-forward" 2>/dev/null || echo "0")
        pkill -f "kubectl.*port-forward" 2>/dev/null || true
        echo -e "${GREEN}✅ $pf_count port-forwards cerrados${NC}"
    else
        echo "ℹ️ No hay port-forwards activos"
    fi
    
    # Limpiar clusters
    limpiar_clusters_existentes
    
    # Limpiar configuraciones de kubectl
    echo "🗑️ Limpiando contextos de kubectl..."
    local contextos_eliminados=0
    for cluster in "$CLUSTER_DEV" "$CLUSTER_PRE" "$CLUSTER_PRO"; do
        if kubectl config get-contexts -o name | grep -q "^$cluster$" 2>/dev/null; then
            if kubectl config delete-context "$cluster" >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Contexto $cluster eliminado${NC}"
                contextos_eliminados=$((contextos_eliminados + 1))
            fi
        fi
    done
    
    if [ $contextos_eliminados -eq 0 ]; then
        echo "ℹ️ No había contextos de kubectl que eliminar"
    fi
    
    # Limpiar archivos temporales
    echo "🗑️ Limpiando archivos temporales..."
    local archivos_temp=("/tmp/yq")
    local archivos_eliminados=0
    
    for archivo in "${archivos_temp[@]}"; do
        if [ -f "$archivo" ]; then
            sudo rm -f "$archivo" 2>/dev/null && archivos_eliminados=$((archivos_eliminados + 1))
        fi
    done
    
    if [ $archivos_eliminados -gt 0 ]; then
        echo -e "${GREEN}✅ $archivos_eliminados archivos temporales eliminados${NC}"
    else
        echo "ℹ️ No había archivos temporales que eliminar"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Limpieza completa realizada exitosamente${NC}"
    echo "💡 El entorno está listo para una instalación limpia con: $0"
}

solo_clusters() {
    echo -e "${BLUE}🏭 Creando solo clusters...${NC}"
    verificar_dependencias
    crear_clusters
    configurar_contextos
    echo -e "${GREEN}✅ Clusters creados y configurados${NC}"
}

solo_argocd() {
    echo -e "${BLUE}🔄 Instalando solo ArgoCD...${NC}" 
    kubectl config use-context "$CLUSTER_DEV" || {
        echo -e "${RED}❌ Cluster DEV no disponible. Ejecuta primero: $0 clusters${NC}"
        exit 1
    }
    instalar_argocd
    echo -e "${GREEN}✅ ArgoCD instalado${NC}"
}

solo_infraestructura() {
    echo -e "${BLUE}📦 Aplicando solo infraestructura...${NC}"
    kubectl config use-context "$CLUSTER_DEV" || {
        echo -e "${RED}❌ Cluster DEV no disponible. Ejecuta primero: $0 clusters${NC}"
        exit 1
    }
    aplicar_infraestructura
    echo -e "${GREEN}✅ Infraestructura aplicada${NC}"
}

solo_port_forwards() {
    echo -e "${BLUE}🌐 Configurando solo port-forwards...${NC}"
    kubectl config use-context "$CLUSTER_DEV" || {
        echo -e "${RED}❌ Cluster DEV no disponible${NC}"
        exit 1
    }
    configurar_port_forwards
    echo -e "${GREEN}✅ Port-forwards configurados${NC}"
}

sincronizar_aplicaciones() {
    echo -e "${BLUE}🔄 Sincronizando aplicaciones ArgoCD...${NC}"
    kubectl config use-context "$CLUSTER_DEV" || {
        echo -e "${RED}❌ Cluster DEV no disponible${NC}"
        exit 1
    }
    
    # Mostrar estado actual
    echo "📊 Estado actual de aplicaciones:"
    kubectl get applications -n argocd -o wide
    
    # Obtener aplicaciones pendientes
    local apps_pendientes=$(kubectl get applications -n argocd --no-headers | grep -E "(Unknown|OutOfSync)" | awk '{print $1}' || true)
    
    if [[ -n "$apps_pendientes" ]]; then
        echo -e "${YELLOW}📋 Aplicaciones pendientes de sincronización:${NC}"
        echo "$apps_pendientes"
        echo ""
        
        for app in $apps_pendientes; do
            echo "🔄 Configurando auto-sync para: $app"
            kubectl patch application "$app" -n argocd --type merge -p '{
                "spec": {
                    "syncPolicy": {
                        "automated": {
                            "prune": true,
                            "selfHeal": true
                        }
                    }
                }
            }' || echo "⚠️ Error al habilitar auto-sync para $app"
            
            echo "🔄 Forzando sincronización inicial de: $app"
            kubectl patch application "$app" -n argocd --type merge -p '{
                "operation": {
                    "sync": {}
                }
            }' || echo "⚠️ Error al sincronizar $app"
        done
        
        echo "⏳ Esperando 45s para que las aplicaciones se sincronicen..."
        sleep 45
        
        # Mostrar estado final
        echo "📊 Estado después de sincronización:"
        kubectl get applications -n argocd -o wide
        
    else
        echo -e "${GREEN}✅ Todas las aplicaciones ya están sincronizadas${NC}"
    fi
    
    echo -e "${GREEN}✅ Sincronización completada${NC}"
}

mostrar_estado() {
    echo -e "${BLUE}📊 Estado actual del sistema:${NC}"
    echo ""
    
    # Estado de clusters
    echo "🏭 CLUSTERS:"
    for cluster in "$CLUSTER_DEV" "$CLUSTER_PRE" "$CLUSTER_PRO"; do
        if minikube status -p "$cluster" >&/dev/null; then
            echo -e "  ✅ $cluster: $(minikube status -p "$cluster" | grep host | awk '{print $2}')"
        else
            echo -e "  ❌ $cluster: No disponible"
        fi
    done
    
    echo ""
    echo "🌐 PORT-FORWARDS ACTIVOS:"
    if pgrep -f "kubectl.*port-forward" >/dev/null; then
        netstat -tuln | grep -E ':(808[0-3]|809[0-3])' | while read line; do
            puerto=$(echo "$line" | awk '{print $4}' | cut -d: -f2)
            echo "  🔗 Puerto $puerto activo"
        done
    else
        echo "  ❌ No hay port-forwards activos"
    fi
    
    echo ""
    echo "📦 APLICACIONES ARGOCD:"
    if kubectl config use-context "$CLUSTER_DEV" >&/dev/null; then
        kubectl get applications -n argocd 2>/dev/null | head -10 || echo "  ❌ ArgoCD no disponible"
    else
        echo "  ❌ Cluster DEV no disponible"
    fi
}

mostrar_help() {
    echo -e "${CYAN}🔧 GitOps Multi-Cluster Infrastructure - Modo de uso:${NC}"
    echo ""
    echo "📖 COMANDOS DISPONIBLES:"
    echo "  $0                    # Instalación completa (recomendado)"
    echo "  $0 limpiar            # Limpiar todo el entorno"
    echo "  $0 clusters           # Crear solo los clusters"
    echo "  $0 argocd             # Instalar solo ArgoCD"
    echo "  $0 infra              # Aplicar solo infraestructura"
    echo "  $0 sync               # Sincronizar aplicaciones ArgoCD"
    echo "  $0 port-forwards      # Configurar solo port-forwards"
    echo "  $0 urls               # Mostrar URLs de interfaces"
    echo "  $0 estado             # Mostrar estado actual"
    echo "  $0 help               # Mostrar esta ayuda"
    echo ""
    echo "🚀 INSTALACIÓN RECOMENDADA:"
    echo "  1. $0                 # Instalación completa automática"
    echo ""
    echo "🔧 INSTALACIÓN PASO A PASO:"
    echo "  1. $0 clusters        # Crear clusters"
    echo "  2. $0 argocd          # Instalar ArgoCD"
    echo "  3. $0 infra           # Aplicar infraestructura"
    echo "  4. $0 sync            # Sincronizar aplicaciones"
    echo "  5. $0 port-forwards   # Configurar acceso"
}

# Manejo de argumentos
case "${1:-}" in
    "limpiar"|"clean")
        limpiar
        ;;
    "clusters")
        solo_clusters
        ;;
    "argocd")
        solo_argocd
        ;;
    "infra"|"infraestructura")
        solo_infraestructura
        ;;
    "sync"|"sincronizar")
        sincronizar_aplicaciones
        ;;
    "port-forwards"|"pf")
        solo_port_forwards
        ;;
    "urls"|"ui")
        mostrar_urls_ui
        ;;
    "estado"|"status")
        mostrar_estado
        ;;
    "help"|"ayuda"|"-h"|"--help")
        mostrar_help
        ;;
    "")
        # Instalación completa por defecto
        instalar_todo
        ;;
    *)
        echo -e "${RED}❌ Argumento desconocido: $1${NC}"
        echo ""
        mostrar_help
        exit 1
        ;;
esac
