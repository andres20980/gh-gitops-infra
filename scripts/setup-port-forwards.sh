#!/bin/bash

# 🚀 Port-forwards para acceso a las UIs de GitOps
# Configura todos los port-forwards necesarios para el desarrollo

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 CONFIGURANDO PORT-FORWARDS GITOPS${NC}"
echo "====================================="
echo ""

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

# Configurar port-forwards principales
echo "🚀 Configurando accesos a las UIs..."
echo ""

# ArgoCD
setup_port_forward "argocd-server" "argocd" "8080" "80" "ArgoCD UI"

# Kargo  
setup_port_forward "kargo-api" "kargo" "8081" "8080" "Kargo UI"

# Grafana (si existe)
if kubectl get namespace monitoring >/dev/null 2>&1; then
    setup_port_forward "grafana" "monitoring" "3000" "80" "Grafana Dashboard" || true
fi

# Jaeger (si existe)
if kubectl get namespace jaeger >/dev/null 2>&1; then
    setup_port_forward "jaeger-query" "jaeger" "16686" "16686" "Jaeger Tracing" || true
fi

echo ""
echo -e "${GREEN}🎉 PORT-FORWARDS CONFIGURADOS${NC}"
echo "=============================="
echo ""
echo -e "${BLUE}📊 ACCESOS DISPONIBLES:${NC}"
echo ""
echo "🔐 ArgoCD:"
echo "   URL: http://localhost:8080"
echo "   Usuario: admin"
echo "   Contraseña: (ver secrets de ArgoCD)"
echo ""
echo "🚢 Kargo:"
echo "   URL: https://localhost:8081"
echo "   Usuario: admin"
echo "   Contraseña: admin"
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
