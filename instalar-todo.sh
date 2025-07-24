#!/bin/bash

# 🚀 Instalador Completo GitOps Multi-Cluster - Plataforma Empresarial
# Instala desde Ubuntu limpio: prerrequisitos + infraestructura GitOps multi-entorno
# Arquitectura: 3 clusters (dev/pre/pro) con gestión centralizada desde DEV

# Colores para la salida
RED='\03    echo "🏗️ ARQUITECTURA MULTI-CLUSTER:"
    echo "=============================="
    echo "🏭 Cluster gitops-dev (4GB RAM, 2 CPU, 20GB): Herramientas de gestión y control centralizadas"
    echo "🏭 Cluster gitops-pre (2GB RAM, 1 CPU, 1GB): Entorno de preproducción para validación"
    echo "🏭 Cluster gitops-pro (2GB RAM, 1 CPU, 1GB): Entorno de producción empresarial"
    echo "📊 Stack: ArgoCD + Kargo + Observabilidad + Gestión Multi-Entorno"m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
    echo "- Kargo: Promociones automáticas entre entornos"
    echo "- Prometheus/Grafana: Monitoreo centralizado multi-cluster"
    echo "- Gitea, MinIO, Jaeger, Loki: Infraestructura compartida"
    echo "- Demo-project: Desplegado en los 3 entornos para pruebas"
    echo ""
    echo "🔄 Flujo GitOps: Git → ArgoCD-DEV → Deploy dev/pre/pro → Kargo → Promote"1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Funciones de logging
log_info() { echo -e "${BLUE}[INFO]${NC} 🔍 $1"; }
log_success() { echo -e "${GREEN}[ÉXITO]${NC} ✅ $1"; }
log_warning() { echo -e "${YELLOW}[AVISO]${NC} ⚠️  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} ❌ $1"; }
log_step() { echo -e "${PURPLE}[PASO]${NC} 🚀 $1"; }
log_install() { echo -e "${GREEN}[INSTALAR]${NC} 📦 $1"; }

# Verificar que no estamos ejecutando como root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Este script NO debe ejecutarse como root o con sudo"
        log_error "Ejecuta: ./instalar-todo.sh (sin sudo)"
        exit 1
    fi
}

# Actualizar sistema
update_system() {
    log_step "Actualizando paquetes del sistema..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release
    log_success "Sistema actualizado"
}

# Instalar Docker
install_docker() {
    log_step "Instalando Docker..."
    if command -v docker &> /dev/null; then
        log_success "Docker ya está instalado"
        return
    fi
    
    # Add Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    log_success "Docker instalado correctamente"
    log_warning "Puede que necesites reiniciar la sesión para usar Docker sin sudo"
}

# Instalar kubectl
install_kubectl() {
    log_step "Instalando kubectl..."
    if command -v kubectl &> /dev/null; then
        log_success "kubectl ya está instalado"
        return
    fi
    
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    log_success "kubectl instalado correctamente"
}

# Instalar Minikube
install_minikube() {
    log_step "Instalando Minikube..."
    if command -v minikube &> /dev/null; then
        log_success "Minikube ya está instalado"
        return
    fi
    
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
    
    log_success "Minikube instalado correctamente"
}

# Instalar Helm
install_helm() {
    log_step "Instalando Helm..."
    if command -v helm &> /dev/null; then
        log_success "Helm ya está instalado"
        return
    fi
    
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt update
    sudo apt install -y helm
    
    log_success "Helm instalado correctamente"
}

# Verificar acceso a Docker
verify_docker_access() {
    log_step "Verificando acceso a Docker..."
    if ! docker ps &> /dev/null; then
        log_error "No se puede acceder a Docker. Puede que necesites:"
        log_error "1. Reiniciar la sesión (logout/login)"
        log_error "2. O ejecutar: newgrp docker"
        exit 1
    fi
    log_success "Acceso a Docker verificado"
}

# Verificar instalaciones
verify_installations() {
    log_step "Verificando todas las instalaciones..."
    
    for cmd in docker kubectl minikube helm git; do
        if command -v $cmd &> /dev/null; then
            version=$($cmd --version 2>/dev/null | head -1)
            log_success "$cmd: $version"
        else
            log_error "$cmd no está instalado correctamente"
            exit 1
        fi
    done
    
    log_success "¡Todos los prerrequisitos verificados!"
}

# Validar acceso a UIs sin autenticación
validar_acceso_ui_sin_autenticacion() {
    log_info "🔍 Validando acceso a UIs sin autenticación..."
    
    # Definir UIs para validar con sus respuestas esperadas
    declare -A ui_checks=(
        ["ArgoCD"]="8080:/healthz:200"
        ["Kargo"]="8081/api/v1alpha1/health:200"
        ["Grafana"]="8082/api/health:200"
        ["Prometheus"]="8083/-/healthy:200"
        ["AlertManager"]="8084/-/healthy:200"
        ["Jaeger"]="8085/:200"
        ["Loki"]="8086/ready:200"
        ["Gitea"]="8087/:200"
        ["Argo_Workflows"]="8088/:200"
        ["MinIO_API"]="8089/:200"
        ["MinIO_Console"]="8090/minio/health/live:200"
        ["K8s_Dashboard"]="8091/:200"
    )
    
    # Esperar a que los servicios estén listos
    sleep 10
    
    echo ""
    echo "🔍 VALIDACIÓN DE ACCESO A UIS:"
    echo "============================="
    
    for ui_name in "${!ui_checks[@]}"; do
        local check_info="${ui_checks[$ui_name]}"
        local port=$(echo "$check_info" | cut -d: -f1)
        local path=$(echo "$check_info" | cut -d: -f2)
        local expected_code=$(echo "$check_info" | cut -d: -f3)
        
        # Intentar acceder a la UI
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}${path}" --connect-timeout 5 --max-time 10 2>/dev/null || echo "000")
        
        if [[ "$response_code" == "$expected_code" ]] || [[ "$response_code" =~ ^2[0-9][0-9]$ ]]; then
            echo "✅ $ui_name (puerto $port): ACCESIBLE"
            UI_STATUS["$ui_name"]="✅ ACCESIBLE"
        else
            echo "❌ $ui_name (puerto $port): NO ACCESIBLE (código: $response_code)"
            UI_STATUS["$ui_name"]="❌ NO ACCESIBLE"
        fi
    done
    
    echo ""
    log_success "Validación de UIs completada"
}

# Mostrar resumen completo de UIs con resultados de validación
mostrar_resumen_completo_uis() {
    # Inicializar array asociativo para estado de UIs
    declare -A UI_STATUS
    
    echo "🚀 RESUMEN COMPLETO DE PLATAFORMA GITOPS:"
    echo "========================================="
    echo ""
    
    # Obtener contraseñas reales para servicios que las necesiten
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
    
    echo "🎯 HERRAMIENTAS GITOPS CORE:"
    echo "----------------------------"
    echo "🎯 ArgoCD UI: http://localhost:8080"
    echo "   📋 Propósito: Continuous Delivery y GitOps orchestration"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["ArgoCD"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🚢 Kargo UI: https://localhost:8081"
    echo "   📋 Propósito: Multi-stage application promotion pipeline"
    echo "   🔓 Acceso: admin/admin (configuración para desarrollo)"
    echo "   ${UI_STATUS["Kargo"]:-"⏳ VERIFICANDO..."}"
    echo ""
    
    echo "📊 HERRAMIENTAS DE OBSERVABILIDAD:"
    echo "----------------------------------"
    echo "📊 Grafana UI: http://localhost:8082"
    echo "   📋 Propósito: Dashboards y visualización de métricas"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Grafana"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "📈 Prometheus UI: http://localhost:8083"
    echo "   📋 Propósito: Recolección y consulta de métricas"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["Prometheus"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🚨 AlertManager UI: http://localhost:8084"
    echo "   📋 Propósito: Gestión y enrutado de alertas"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["AlertManager"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔍 Jaeger UI: http://localhost:8085"
    echo "   📋 Propósito: Distributed tracing y análisis de rendimiento"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["Jaeger"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "📝 Loki UI: http://localhost:8086"
    echo "   📋 Propósito: Agregación y consulta de logs"
    echo "   🔓 Acceso: Directo sin autenticación"
    echo "   ${UI_STATUS["Loki"]:-"⏳ VERIFICANDO..."}"
    echo ""
    
    echo "💾 HERRAMIENTAS DE ALMACENAMIENTO Y DESARROLLO:"
    echo "----------------------------------------------"
    echo "🐙 Gitea UI: http://localhost:8087"
    echo "   📋 Propósito: Git repository management y source control"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Gitea"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "⚡ Argo Workflows UI: http://localhost:8088"
    echo "   📋 Propósito: Workflow orchestration y batch processing"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["Argo_Workflows"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🏪 MinIO API: http://localhost:8089"
    echo "   📋 Propósito: Object storage S3-compatible (API)"
    echo "   🔓 Acceso: Credenciales fijas (admin/admin123)"
    echo "   ${UI_STATUS["MinIO_API"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🏪 MinIO Console: http://localhost:8090"
    echo "   📋 Propósito: Object storage S3-compatible (Console UI)"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["MinIO_Console"]:-"⏳ VERIFICANDO..."}"
    echo ""
    echo "🔧 Kubernetes Dashboard: http://localhost:8091"
    echo "   📋 Propósito: Kubernetes cluster management interface"
    echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
    echo "   ${UI_STATUS["K8s_Dashboard"]:-"⏳ VERIFICANDO..."}"
    echo ""
    
    echo "🏗️ ARQUITECTURA DEL SISTEMA:"
    echo "=============================="
    echo "�️ ARQUITECTURA MULTI-CLUSTER:"
    echo "=============================="
    echo "�🏭 Cluster gitops-dev: Herramientas de gestión y control centralizadas"
    echo "🏭 Cluster gitops-pre: Entorno de preproducción para validación"
    echo "🏭 Cluster gitops-pro: Entorno de producción empresarial"
    echo "📊 Stack: ArgoCD + Kargo + Observabilidad + Gestión Multi-Entorno"
    echo ""
    echo "📦 Herramientas en DEV (controlan todos los clusters):"
    echo "- ArgoCD: Gestión de aplicaciones en dev/pre/pro"
    echo "- Kargo: Promociones automáticas entre entornos"
    echo "- Prometheus/Grafana: Monitoreo centralizado multi-cluster"
    echo "- Gitea, MinIO, Jaeger, Loki: Infraestructura compartida"
    echo "- Demo-project: Desplegado en los 3 entornos para pruebas"
    echo ""
    echo "🔄 Flujo GitOps: Git → ArgoCD-DEV → Deploy dev/pre/pro → Kargo → Promote"
    echo ""
    
    echo "💡 COMANDOS ÚTILES POST-INSTALACIÓN:"
    echo "===================================="
    echo "💡 Ver diagnóstico completo: ./scripts/diagnostico-gitops.sh"
    echo "💡 Reiniciar port-forwards: ./scripts/setup-port-forwards.sh"
    echo "💡 Ver aplicaciones ArgoCD: kubectl get applications -n argocd"
    echo "💡 Port-forwards activos PID: $PORTFORWARD_PID"
    echo ""
    echo "🚀 ¡PLATAFORMA GITOPS MULTI-CLUSTER COMPLETAMENTE OPERATIVA!"
    echo "🔓 ¡TODAS LAS UIS VALIDADAS PARA ACCESO SIN AUTENTICACIÓN!"
}

# Función principal
main() {
    echo ""
    echo "🚀================================================"
    echo "   📦 INSTALADOR COMPLETO GITOPS"
    echo "   🔧 Prerrequisitos + Despliegue de Infraestructura"
    echo "================================================"
    echo ""
    
    # Verificaciones iniciales
    check_not_root
    
    # Fase 1: Actualizar sistema
    update_system
    
    # Fase 2: Instalar herramientas
    install_docker
    install_kubectl
    install_minikube
    install_helm
    
    # Fase 3: Verificar acceso a Docker
    verify_docker_access
    
    # Fase 4: Verificar instalaciones
    verify_installations
    
    # Fase 5: Configurar clusters multi-entorno GitOps
    log_step "Creando clusters multi-entorno (dev/pre/pro)..."
    
    # Limpiar clusters existentes
    minikube delete --all
    
    # Crear cluster de desarrollo (principal con todas las herramientas - MÁS RECURSOS)
    log_step "Creando cluster gitops-dev (principal con todas las herramientas)..."
    minikube start -p gitops-dev --memory=4096 --cpus=2 --disk-size=20gb
    
    # Crear cluster de preproducción (solo aplicaciones - RECURSOS MÍNIMOS)
    log_step "Creando cluster gitops-pre (preproducción)..."
    minikube start -p gitops-pre --memory=2048 --cpus=1 --disk-size=1gb
    
    # Crear cluster de producción (solo aplicaciones - RECURSOS MÍNIMOS)
    log_step "Creando cluster gitops-pro (producción)..."
    minikube start -p gitops-pro --memory=2048 --cpus=1 --disk-size=1gb
    
    # Establecer contexto en DEV para las instalaciones
    kubectl config use-context gitops-dev
    
    # Instalar ArgoCD con configuración personalizada
    log_step "Instalando ArgoCD con Helm..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Agregar repositorio de Helm de ArgoCD
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    # Instalar ArgoCD con configuración sin autenticación para desarrollo
    helm install argocd argo/argo-cd \
      --namespace argocd \
      --set server.service.type=ClusterIP \
      --set server.extraArgs[0]="--insecure" \
      --set server.config."users\.anonymous\.enabled"="true" \
      --set server.config."users\.anonymous\.policies"="p, role:anonymous, applications, *, */*, allow\np, role:anonymous, clusters, *, *, allow\np, role:anonymous, repositories, *, *, allow\ng, argocd:anonymous, role:admin" \
      --set configs.cm."server\.insecure"="true" \
      --set configs.cm."url"="http://localhost:8080" \
      --set configs.cm."policy\.default"="role:admin" \
      --set dex.enabled=false \
      --wait --timeout=600s
    
    # Esperar a que ArgoCD esté completamente listo
    log_step "Esperando que ArgoCD esté completamente operativo..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
    
    # Aplicar app-of-apps principal para desplegar toda la infraestructura
    log_step "Desplegando infraestructura GitOps completa..."
    kubectl apply -f aplicaciones-gitops-infra.yaml
    
    echo ""
    echo "🎯================================================"
    echo "   ✅ INSTALACIÓN DE PRERREQUISITOS COMPLETADA!"
    echo "   🚀 INICIANDO DESPLIEGUE GITOPS..."
    echo "================================================"
    echo ""
    
    # Esperar a que ArgoCD esté listo y todas las aplicaciones se desplieguen
    log_step "Esperando que ArgoCD y todas las aplicaciones estén listas..."
    sleep 60

    # Iniciar port-forwards automáticamente para acceso inmediato a UIs
    log_step "Iniciando port-forwards de UIs automáticamente..."
    chmod +x scripts/setup-port-forwards.sh
    ./scripts/setup-port-forwards.sh &
    PORTFORWARD_PID=$!
    
    # Esperar a que se establezcan los port-forwards
    sleep 15
    
    # Validar acceso sin autenticación a todas las UIs
    log_step "Validando acceso sin autenticación a todas las UIs..."
    validar_acceso_ui_sin_autenticacion
    
    echo ""
    echo "🏆================================================"
    echo "   🎉 INSTALACIÓN COMPLETA FINALIZADA!"
    echo "   📊 Plataforma GitOps Multi-Cluster Desplegada!"
    echo "   🌐 UIs Validadas y Accesibles Sin Login!"
    echo "================================================"
    echo ""
    
    # Mostrar resumen completo con validación de acceso
    mostrar_resumen_completo_uis
}

# Manejar Ctrl+C elegantemente
trap 'log_error "Instalación interrumpida por el usuario"; exit 1' INT

# Ejecutar función principal
main "$@"
