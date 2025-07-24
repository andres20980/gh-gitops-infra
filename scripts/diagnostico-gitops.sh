#!/bin/bash

# 🔍 Script de Diagnóstico Integral GitOps
# Identifica problemas en el despliegue de infraestructura

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 DIAGNÓSTICO INTEGRAL GITOPS${NC}"
echo "================================="
echo ""

# 1. Verificar contexto Kubernetes
echo -e "${BLUE}1. CONTEXTO KUBERNETES${NC}"
echo "----------------------"
if kubectl config current-context 2>/dev/null; then
    echo -e "${GREEN}✅ Contexto activo encontrado${NC}"
    CONTEXT=$(kubectl config current-context)
    echo "   Contexto actual: $CONTEXT"
else
    echo -e "${RED}❌ No hay contexto activo${NC}"
    exit 1
fi
echo ""

# 2. Verificar cluster y nodos
echo -e "${BLUE}2. ESTADO DEL CLUSTER${NC}"
echo "---------------------"
if kubectl get nodes 2>/dev/null; then
    echo -e "${GREEN}✅ Cluster accesible${NC}"
else
    echo -e "${RED}❌ No se puede acceder al cluster${NC}"
    exit 1
fi
echo ""

# 3. Verificar namespace ArgoCD
echo -e "${BLUE}3. NAMESPACE ARGOCD${NC}"
echo "-------------------"
if kubectl get namespace argocd 2>/dev/null; then
    echo -e "${GREEN}✅ Namespace argocd existe${NC}"
else
    echo -e "${RED}❌ Namespace argocd no existe${NC}"
    exit 1
fi
echo ""

# 4. Verificar pods ArgoCD
echo -e "${BLUE}4. PODS ARGOCD${NC}"
echo "--------------"
kubectl get pods -n argocd 2>/dev/null || echo -e "${RED}❌ No se pueden obtener pods de ArgoCD${NC}"
echo ""

# 5. Verificar aplicaciones ArgoCD
echo -e "${BLUE}5. APLICACIONES ARGOCD${NC}"
echo "----------------------"
APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
if [ "$APPS" -gt 0 ]; then
    echo -e "${GREEN}✅ Encontradas $APPS aplicaciones${NC}"
    kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️ No hay aplicaciones ArgoCD desplegadas${NC}"
fi
echo ""

# 6. Verificar namespace Kargo
echo -e "${BLUE}6. NAMESPACE KARGO${NC}"
echo "------------------"
if kubectl get namespace kargo 2>/dev/null; then
    echo -e "${GREEN}✅ Namespace kargo existe${NC}"
    
    # Verificar pods en namespace kargo
    KARGO_PODS=$(kubectl get pods -n kargo --no-headers 2>/dev/null | wc -l)
    if [ "$KARGO_PODS" -gt 0 ]; then
        echo -e "${GREEN}✅ Encontrados $KARGO_PODS pods en kargo${NC}"
        kubectl get pods -n kargo 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠️ No hay pods en namespace kargo${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Namespace kargo no existe${NC}"
fi
echo ""

# 7. Verificar servicios Kargo
echo -e "${BLUE}7. SERVICIOS KARGO${NC}"
echo "------------------"
kubectl get svc -n kargo 2>/dev/null || echo -e "${YELLOW}⚠️ No hay servicios en namespace kargo${NC}"
echo ""

# 8. Verificar connectividad ArgoCD
echo -e "${BLUE}8. CONECTIVIDAD ARGOCD${NC}"
echo "----------------------"
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8080/ | grep -q "200"; then
    echo -e "${GREEN}✅ ArgoCD accesible en https://localhost:8080${NC}"
else
    echo -e "${YELLOW}⚠️ ArgoCD no accesible en https://localhost:8080${NC}"
    echo "   Verificando port-forwards activos..."
    ps aux | grep "kubectl port-forward" | grep -v grep || echo "   No hay port-forwards activos"
fi
echo ""

# 9. Verificar port-forwards
echo -e "${BLUE}9. PORT-FORWARDS ACTIVOS${NC}"
echo "------------------------"
PF_COUNT=$(ps aux | grep "kubectl port-forward" | grep -v grep | wc -l)
if [ "$PF_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Encontrados $PF_COUNT port-forwards activos${NC}"
    ps aux | grep "kubectl port-forward" | grep -v grep | awk '{print "   " $11 " " $12 " " $13 " " $14}'
else
    echo -e "${YELLOW}⚠️ No hay port-forwards activos${NC}"
fi
echo ""

# 10. Diagnóstico de aplicación Kargo específicamente
echo -e "${BLUE}10. DIAGNÓSTICO ESPECÍFICO KARGO${NC}"
echo "--------------------------------"
if kubectl get application kargo -n argocd 2>/dev/null; then
    echo -e "${GREEN}✅ Aplicación Kargo existe en ArgoCD${NC}"
    
    # Estado detallado de la aplicación
    SYNC_STATUS=$(kubectl get application kargo -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Desconocido")
    HEALTH_STATUS=$(kubectl get application kargo -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Desconocido")
    
    echo "   Sync Status: $SYNC_STATUS"
    echo "   Health Status: $HEALTH_STATUS"
    
    if [ "$SYNC_STATUS" != "Synced" ] || [ "$HEALTH_STATUS" != "Healthy" ]; then
        echo -e "${YELLOW}⚠️ Kargo no está completamente sincronizado o saludable${NC}"
        echo "   Obteniendo detalles..."
        kubectl describe application kargo -n argocd | grep -A 10 -B 5 "Status:" || true
    fi
else
    echo -e "${RED}❌ Aplicación Kargo no existe en ArgoCD${NC}"
    echo "   Verificando si existe el archivo de configuración..."
    if [ -f "/home/asanchez/gh-gitops-infra/componentes/kargo/kargo.yaml" ]; then
        echo -e "${GREEN}   ✅ Archivo kargo.yaml existe${NC}"
    else
        echo -e "${RED}   ❌ Archivo kargo.yaml no encontrado${NC}"
    fi
fi
echo ""

# 10.1. Verificar conectividad Kargo
echo -e "${BLUE}10.1. CONECTIVIDAD KARGO${NC}"
echo "------------------------"
if curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8081/ | grep -q "200"; then
    echo -e "${GREEN}✅ Kargo UI accesible en https://localhost:8081${NC}"
else
    echo -e "${YELLOW}⚠️ Kargo UI no accesible en https://localhost:8081${NC}"
    echo "   Verificando si el port-forward está activo..."
    ps aux | grep "kubectl port-forward" | grep "kargo-api" | grep -v grep || echo "   Port-forward de Kargo no activo"
fi
echo ""

# 11. Resumen y recomendaciones
echo -e "${BLUE}11. RESUMEN Y RECOMENDACIONES${NC}"
echo "-----------------------------"

if [ "$APPS" -eq 0 ]; then
    echo -e "${YELLOW}🔧 RECOMENDACIÓN: Aplicar app-of-apps principal${NC}"
    echo "   kubectl apply -f /home/asanchez/gh-gitops-infra/aplicaciones-gitops-infra.yaml"
fi

if ! kubectl get namespace kargo 2>/dev/null; then
    echo -e "${YELLOW}🔧 RECOMENDACIÓN: Aplicar configuración de Kargo${NC}"
    echo "   kubectl apply -f /home/asanchez/gh-gitops-infra/componentes/kargo/kargo.yaml"
fi

if [ "$PF_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}🔧 RECOMENDACIÓN: Configurar port-forwards${NC}"
    echo "   ./scripts/setup-port-forwards.sh"
fi

echo ""
echo -e "${BLUE}🎯 DIAGNÓSTICO COMPLETADO${NC}"
echo "========================"
