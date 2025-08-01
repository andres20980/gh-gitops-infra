#!/bin/bash

# Script para desplegar aplicaciones ArgoCD respetando dependencias
# Ejecutar desde el directorio raíz del proyecto

echo "🚀 DESPLIEGUE SECUENCIAL CON DEPENDENCIAS GITOPS"
echo "================================================"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para esperar que una aplicación esté Synced y Healthy
wait_for_app() {
    local app_name=$1
    local max_wait=${2:-300}  # 5 minutos por defecto
    local wait_time=0
    
    echo -e "${BLUE}⏳ Esperando que $app_name esté Synced y Healthy...${NC}"
    
    while [ $wait_time -lt $max_wait ]; do
        local status=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
        local health=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
        
        if [[ "$status" == "Synced" && "$health" == "Healthy" ]]; then
            echo -e "${GREEN}✅ $app_name está Synced y Healthy${NC}"
            return 0
        fi
        
        echo "   $app_name: sync=$status health=$health (${wait_time}s/${max_wait}s)"
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    echo -e "${RED}❌ TIMEOUT: $app_name no alcanzó estado Synced+Healthy en ${max_wait}s${NC}"
    return 1
}

# Función para forzar sincronización de una aplicación
force_sync() {
    local app_name=$1
    echo -e "${YELLOW}🔄 Forzando sincronización de $app_name...${NC}"
    
    # Anotar para forzar refresh desde Git
    kubectl annotate application $app_name -n argocd argocd.argoproj.io/refresh=now --overwrite >/dev/null 2>&1
    
    # Habilitar auto-sync si no está habilitado
    kubectl patch application $app_name -n argocd --type='merge' -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1
    
    sleep 5
}

# Verificar que estamos en el contexto correcto
if ! kubectl config current-context | grep -q "gitops-dev"; then
    echo -e "${RED}❌ Error: No estás en el contexto gitops-dev${NC}"
    exit 1
fi

echo ""
echo "📋 VERIFICANDO ESTADO INICIAL..."
kubectl get applications -n argocd --no-headers | awk '{print $1 " -> " $2 "/" $3}'

echo ""
echo -e "${BLUE}🏗️ FASE 1: INFRAESTRUCTURA BASE (cert-manager, ingress-nginx)${NC}"
echo "============================================================="

# Cert-manager (crítico para TLS y webhooks)
echo "1️⃣ Desplegando cert-manager..."
force_sync cert-manager
if wait_for_app cert-manager 600; then
    echo -e "${GREEN}✅ cert-manager desplegado exitosamente${NC}"
else
    echo -e "${RED}❌ cert-manager falló - ABORTANDO${NC}"
    exit 1
fi

# Ingress controller
echo ""
echo "2️⃣ Desplegando ingress-nginx..."
force_sync ingress-nginx
if wait_for_app ingress-nginx 300; then
    echo -e "${GREEN}✅ ingress-nginx desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ ingress-nginx con problemas - continuando...${NC}"
fi

echo ""
echo -e "${BLUE}🔐 FASE 2: SECRETOS Y MONITOREO (external-secrets, monitoring)${NC}"
echo "================================================================="

# External Secrets (para gestión de secretos)
echo "3️⃣ Desplegando external-secrets..."
force_sync external-secrets
if wait_for_app external-secrets 300; then
    echo -e "${GREEN}✅ external-secrets desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ external-secrets con problemas - continuando...${NC}"
fi

# Prometheus Stack (ya está desplegado, pero verificamos)
echo ""
echo "4️⃣ Verificando monitoring (prometheus-stack)..."
if wait_for_app monitoring 60; then
    echo -e "${GREEN}✅ monitoring ya está operativo${NC}"
else
    force_sync monitoring
    wait_for_app monitoring 300
fi

echo ""
echo -e "${BLUE}📊 FASE 3: OBSERVABILIDAD (loki, grafana, jaeger)${NC}"
echo "=================================================="

# Loki para logs
echo "5️⃣ Desplegando loki..."
force_sync loki
if wait_for_app loki 300; then
    echo -e "${GREEN}✅ loki desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ loki con problemas - continuando...${NC}"
fi

# Grafana para dashboards
echo ""
echo "6️⃣ Desplegando grafana..."
force_sync grafana
if wait_for_app grafana 300; then
    echo -e "${GREEN}✅ grafana desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ grafana con problemas - continuando...${NC}"
fi

# Jaeger para tracing
echo ""
echo "7️⃣ Desplegando jaeger..."
force_sync jaeger
if wait_for_app jaeger 300; then
    echo -e "${GREEN}✅ jaeger desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ jaeger con problemas - continuando...${NC}"
fi

echo ""
echo -e "${BLUE}🚀 FASE 4: GITOPS AVANZADO (argo-*, kargo)${NC}"
echo "==========================================="

# Argo Rollouts
echo "8️⃣ Desplegando argo-rollouts..."
force_sync argo-rollouts
if wait_for_app argo-rollouts 300; then
    echo -e "${GREEN}✅ argo-rollouts desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ argo-rollouts con problemas - continuando...${NC}"
fi

# Argo Workflows
echo ""
echo "9️⃣ Desplegando argo-workflows..."
force_sync argo-workflows
if wait_for_app argo-workflows 300; then
    echo -e "${GREEN}✅ argo-workflows desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ argo-workflows con problemas - continuando...${NC}"
fi

# Argo Events
echo ""
echo "🔟 Desplegando argo-events..."
force_sync argo-events
if wait_for_app argo-events 300; then
    echo -e "${GREEN}✅ argo-events desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ argo-events con problemas - continuando...${NC}"
fi

# Kargo (requiere cert-manager + external-secrets)
echo ""
echo "1️⃣1️⃣ Desplegando kargo..."
force_sync kargo
if wait_for_app kargo 600; then
    echo -e "${GREEN}✅ kargo desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ kargo con problemas - continuando...${NC}"
fi

echo ""
echo -e "${BLUE}🏪 FASE 5: STORAGE Y SCM (minio, gitea)${NC}"
echo "======================================="

# MinIO
echo "1️⃣2️⃣ Desplegando minio..."
force_sync minio
if wait_for_app minio 300; then
    echo -e "${GREEN}✅ minio desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ minio con problemas - continuando...${NC}"
fi

# Gitea
echo ""
echo "1️⃣3️⃣ Desplegando gitea..."
force_sync gitea
if wait_for_app gitea 300; then
    echo -e "${GREEN}✅ gitea desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ gitea con problemas - continuando...${NC}"
fi

echo ""
echo -e "${BLUE}📱 FASE 6: COMPLEMENTOS (argocd-notifications, argocd-applicationset)${NC}"
echo "====================================================================="

# ArgoCD Notifications
echo "1️⃣4️⃣ Desplegando argocd-notifications..."
force_sync argocd-notifications
if wait_for_app argocd-notifications 180; then
    echo -e "${GREEN}✅ argocd-notifications desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ argocd-notifications con problemas - continuando...${NC}"
fi

# ArgoCD ApplicationSet
echo ""
echo "1️⃣5️⃣ Desplegando argocd-applicationset..."
force_sync argocd-applicationset
if wait_for_app argocd-applicationset 180; then
    echo -e "${GREEN}✅ argocd-applicationset desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️ argocd-applicationset con problemas - continuando...${NC}"
fi

echo ""
echo -e "${BLUE}🎯 RESUMEN FINAL${NC}"
echo "================"

# Estado final
echo ""
echo "📋 ESTADO FINAL DE APLICACIONES:"
kubectl get applications -n argocd --no-headers | awk '{
    if ($2 == "Synced" && $3 == "Healthy") 
        print "✅ " $1 " -> " $2 "/" $3
    else if ($2 == "Synced")
        print "🟡 " $1 " -> " $2 "/" $3  
    else
        print "❌ " $1 " -> " $2 "/" $3
}'

# Contar éxitos
TOTAL=$(kubectl get applications -n argocd --no-headers | wc -l)
SYNCED=$(kubectl get applications -n argocd --no-headers | awk '$2=="Synced" && $3=="Healthy"' | wc -l)
PERCENTAGE=$((SYNCED * 100 / TOTAL))

echo ""
echo -e "${GREEN}📊 ESTADÍSTICAS FINALES:${NC}"
echo "========================"
echo "✅ Aplicaciones Synced+Healthy: $SYNCED/$TOTAL ($PERCENTAGE%)"
echo "🎯 Objetivo mínimo para PRE/PRO: 5/7 aplicaciones críticas (≥71%)"

if [ $PERCENTAGE -ge 70 ]; then
    echo -e "${GREEN}🎉 ¡ÉXITO! Plataforma lista para crear PRE/PRO${NC}"
    echo -e "${GREEN}💡 Ejecuta: ./instalar-todo.sh clusters${NC}"
else
    echo -e "${YELLOW}⚠️ Necesita más aplicaciones funcionando para PRE/PRO${NC}"
    echo -e "${YELLOW}💡 Revisa los logs de aplicaciones fallidas${NC}"
fi

echo ""
echo -e "${BLUE}🔧 COMANDOS DE DIAGNÓSTICO:${NC}"
echo "==========================="
echo "# Ver logs de una aplicación específica:"
echo "kubectl logs -f deployment/argocd-application-controller-0 -n argocd"
echo ""
echo "# Ver detalles de una aplicación:"
echo "kubectl describe application <app-name> -n argocd"
echo ""
echo "# Reiniciar port-forwards:"
echo "./scripts/setup-port-forwards.sh"

echo ""
echo -e "${GREEN}✅ DESPLIEGUE SECUENCIAL COMPLETADO${NC}"
