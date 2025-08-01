#!/bin/bash

# 🚀 Port-forwards para acceso a las UIs de GitOps Multi-Cluster
# Configura todos los port-forwards necesarios desde el cluster DEV

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 CONFIGURANDO PORT-FORWARDS GITOPS MULTI-CLUSTER${NC}"
echo "====================================================="
echo ""

# Configurar contexto Kubernetes en DEV (donde están todas las herramientas)
echo -e "${YELLOW}🔧 Configurando contexto Kubernetes...${NC}"
if kubectl config get-contexts | grep -q "gitops-dev"; then
    kubectl config use-context gitops-dev
    echo -e "${GREEN}✅ Contexto establecido en gitops-dev${NC}"
else
    echo -e "${RED}❌ Contexto gitops-dev no encontrado${NC}"
    echo "   Ejecuta primero: ./instalar-todo.sh"
    exit 1
fi

# Función para verificar si un puerto está en uso
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Puerto en uso
    else
        return 1  # Puerto libre
    fi
}

# Función para establecer port-forward
setup_port_forward() {
    local service=$1
    local namespace=$2
    local local_port=$3
    local remote_port=$4
    local description=$5
    
    echo -e "${BLUE}📡 Configurando $description...${NC}"
    
    # Verificar si el puerto está en uso
    if check_port $local_port; then
        echo -e "${YELLOW}⚠️  Puerto $local_port ya está en uso${NC}"
        return 0
    fi
    
    # Verificar que el servicio existe
    if ! kubectl get service $service -n $namespace >/dev/null 2>&1; then
        echo -e "${RED}❌ Servicio $service no encontrado en namespace $namespace${NC}"
        return 1
    fi
    
    # Establecer port-forward en background
    kubectl port-forward -n $namespace svc/$service $local_port:$remote_port &
    local pf_pid=$!
    
    # Esperar un momento para verificar que el port-forward se estableció
    sleep 2
    
    if ps -p $pf_pid > /dev/null; then
        echo -e "${GREEN}✅ $description disponible en http://localhost:$local_port${NC}"
        echo "   PID: $pf_pid"
    else
        echo -e "${RED}❌ Error configurando port-forward para $description${NC}"
        return 1
    fi
}

# Configurar contexto
echo "🔧 Configurando contexto Kubernetes..."
kubectl config use-context gitops-dev 2>/dev/null || {
    echo -e "${RED}❌ Contexto gitops-dev no encontrado${NC}"
    echo "   Ejecuta primero: ./install-everything.sh"
    exit 1
}

echo -e "${GREEN}✅ Contexto configurado: gitops-dev${NC}"
echo ""

# Limpiar port-forwards previos
echo "🧹 Limpiando port-forwards previos..."
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Configurar port-forwards principales organizados por tipo
echo "🚀 Configurando accesos a las UIs organizadas por categorías..."
echo ""

# 🎯 GITOPS CORE (8080-8082)
echo "🎯 Configurando GitOps Core..."
setup_port_forward "argocd-server" "argocd" "8080" "80" "ArgoCD UI"
setup_port_forward "kargo-api" "kargo" "8081" "8080" "Kargo UI"
if kubectl get namespace argo-workflows >/dev/null 2>&1; then
    setup_port_forward "argo-workflows-server" "argo-workflows" "8082" "2746" "Argo Workflows UI" || true
fi

# 🚀 PROGRESSIVE DELIVERY (8083)
echo "🚀 Configurando Progressive Delivery..."
if kubectl get namespace argo-rollouts >/dev/null 2>&1; then
    setup_port_forward "argo-rollouts-dashboard" "argo-rollouts" "8083" "3100" "Argo Rollouts Dashboard" || true
fi

# 📊 OBSERVABILIDAD (8084-8087)
echo "📊 Configurando Observabilidad..."
if kubectl get namespace monitoring >/dev/null 2>&1; then
    setup_port_forward "grafana" "monitoring" "8084" "80" "Grafana Dashboard" || true
    setup_port_forward "prometheus-server" "monitoring" "8085" "80" "Prometheus Server" || true
    setup_port_forward "alertmanager" "monitoring" "8086" "9093" "AlertManager UI" || true
fi
if kubectl get namespace jaeger >/dev/null 2>&1; then
    setup_port_forward "jaeger-query" "jaeger" "8087" "16686" "Jaeger Tracing" || true
fi

# 📝 LOGS & STORAGE (8088-8090) 
echo "📝 Configurando Logs & Storage..."
if kubectl get namespace loki >/dev/null 2>&1; then
    setup_port_forward "loki" "loki" "8088" "3100" "Loki Logs" || true
fi
if kubectl get namespace minio >/dev/null 2>&1; then
    setup_port_forward "minio" "minio" "8089" "9000" "MinIO API" || true
    setup_port_forward "minio-console" "minio" "8090" "9001" "MinIO Console UI" || true
fi

# 🔧 DESARROLLO & GESTIÓN (8091-8092)
echo "🔧 Configurando Desarrollo & Gestión..."
if kubectl get namespace gitea >/dev/null 2>&1; then
    setup_port_forward "gitea-http" "gitea" "8091" "3000" "Gitea Git Server" || true
fi
if kubectl get namespace kubernetes-dashboard >/dev/null 2>&1; then
    setup_port_forward "kubernetes-dashboard" "kubernetes-dashboard" "8092" "443" "Kubernetes Dashboard" || true
fi

echo ""
echo -e "${GREEN}🎉 PORT-FORWARDS CONFIGURADOS${NC}"
echo "=============================="
echo ""
echo -e "${BLUE}📊 ACCESOS DISPONIBLES ORGANIZADOS POR TIPO (8080-8092):${NC}"
echo ""
echo "🔐 ArgoCD (8080):"
echo "   URL: http://localhost:8080"
echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
echo ""
echo "🚢 Kargo (8081):"
echo "   URL: https://localhost:8081"
echo "   🔓 Acceso: admin/admin"
echo ""
echo "📊 Grafana (8082):"
echo "   URL: http://localhost:8082"
echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
echo ""
echo "📈 Prometheus (8083):"
echo "   URL: http://localhost:8083"
echo "   🔓 Acceso: Directo sin autenticación"
echo ""
echo "🚨 AlertManager (8084):"
echo "   URL: http://localhost:8084"
echo "   🔓 Acceso: Directo sin autenticación"
echo ""
echo "🔍 Jaeger (8085):"
echo "   URL: http://localhost:8085"
echo "   🔓 Acceso: Directo sin autenticación"
echo ""
echo "� Loki (8086):"
echo "   URL: http://localhost:8086"
echo "   🔓 Acceso: Directo sin autenticación"
echo ""
echo "🐙 Gitea (8087):"
echo "   URL: http://localhost:8087"
echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
echo ""
echo "⚡ Argo Workflows (8088):"
echo "   URL: http://localhost:8088"
echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
echo ""
echo "� Argo Rollouts Dashboard (8089):"
echo "   URL: http://localhost:8089"
echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
echo ""
echo "�🏪 MinIO API (8090):"
echo "   URL: http://localhost:8090"
echo "   🔓 Acceso: admin/admin123"
echo ""
echo "🏪 MinIO Console (8091):"
echo "   URL: http://localhost:8091"
echo "   🔓 Acceso: admin/admin123"
echo ""
echo "🔧 Kubernetes Dashboard (8092):"
echo "   URL: http://localhost:8092"
echo "   🔓 Acceso: ANÓNIMO - SIN LOGIN REQUERIDO"
echo ""

if kubectl get namespace monitoring >/dev/null 2>&1; then
    echo "📈 Grafana:"
    echo "   URL: http://localhost:3000"
    echo ""
fi

if kubectl get namespace jaeger >/dev/null 2>&1; then
    echo "🔍 Jaeger:"
    echo "   URL: http://localhost:16686"
    echo ""
fi

echo -e "${YELLOW}📝 NOTAS:${NC}"
echo "• Los port-forwards están ejecutándose en background"
echo "• Para detenerlos: pkill -f 'kubectl port-forward'"
echo "• Para ver procesos activos: ps aux | grep 'kubectl port-forward'"
echo ""
echo -e "${GREEN}✨ ¡Todo listo para desarrollo!${NC}"
