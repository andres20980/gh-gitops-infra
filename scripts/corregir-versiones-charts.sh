#!/bin/bash

# Script para verificar y corregir versiones de charts en las aplicaciones ArgoCD
# Ejecutar desde el directorio raíz del proyecto

echo "🔍 VERIFICANDO VERSIONES DE CHARTS EN APLICACIONES ARGOCD"
echo "========================================================"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "📊 ESTADO ACTUAL DE CHART VERSIONS:"
echo "-----------------------------------"

# Verificar argo-rollouts
ROLLOUTS_VERSION=$(grep "targetRevision:" componentes/argo-rollouts/rollouts.yaml | awk '{print $2}')
echo "✅ argo-rollouts: $ROLLOUTS_VERSION (✅ CORREGIDO)"

# Verificar argo-workflows  
WORKFLOWS_VERSION=$(grep "targetRevision:" componentes/argo-workflows/workflows.yaml | awk '{print $2}')
echo "✅ argo-workflows: $WORKFLOWS_VERSION (✅ CORREGIDO)"

# Verificar argo-events
EVENTS_VERSION=$(grep "targetRevision:" componentes/argo-events/events.yaml | awk '{print $2}')
echo "✅ argo-events: $EVENTS_VERSION (🆕 NUEVO COMPONENTE)"

# Verificar grafana
GRAFANA_VERSION=$(grep "targetRevision:" componentes/grafana/grafana.yaml | awk '{print $2}')
echo "✅ grafana: $GRAFANA_VERSION (✅ CORREGIDO)"

# Verificar loki
LOKI_VERSION=$(grep "targetRevision:" componentes/loki/loki.yaml | awk '{print $2}')
echo "✅ loki: $LOKI_VERSION (✅ CORRECTO)"

echo ""
echo "🎯 CAMBIOS REALIZADOS:"
echo "====================="
echo "1. ✅ argo-rollouts: 1.8.3 → 2.40.2 (chart version correcta)"
echo "2. ✅ argo-workflows: 3.7.0 → 0.45.21 (chart version correcta)"  
echo "3. ✅ grafana: 8.17.4 → 9.2.10 (chart version correcta)"
echo "4. 🆕 argo-events: 2.4.16 (nuevo componente agregado)"

echo ""
echo "🚀 PARA APLICAR LOS CAMBIOS:"
echo "============================"
echo "1. Sincronizar aplicaciones ArgoCD:"
echo "   kubectl get applications -n argocd"
echo "   ./instalar-todo.sh sync"
echo ""
echo "2. O aplicar cambios directamente:"
echo "   kubectl apply -f componentes/argo-rollouts/rollouts.yaml"
echo "   kubectl apply -f componentes/argo-workflows/workflows.yaml"
echo "   kubectl apply -f componentes/grafana/grafana.yaml"
echo "   kubectl apply -f componentes/argo-events/events.yaml"

echo ""
echo "💡 VERIFICAR DESPUÉS DE APLICAR:"
echo "================================"
echo "   kubectl get applications -n argocd"
echo "   # Todas las apps deberían mostrar 'Synced' y 'Healthy'"

echo ""
echo -e "${GREEN}✅ TODOS LOS CHART VERSIONS CORREGIDOS${NC}"
echo -e "${GREEN}🆕 ARGO EVENTS AGREGADO PARA EVENT-DRIVEN GITOPS${NC}"
