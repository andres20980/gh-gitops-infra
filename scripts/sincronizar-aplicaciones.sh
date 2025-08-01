#!/bin/bash

echo "🔄 SINCRONIZACIÓN MASIVA DE APLICACIONES ARGOCD"
echo "=============================================="

# Lista de aplicaciones críticas en orden de dependencia
CRITICAL_APPS=(
    "cert-manager"      # Base para TLS
    "external-secrets"  # Base para secrets
    "ingress-nginx"     # Base para ingress
    "kargo"            # Progressive delivery
    "argo-rollouts"    # Rollouts
    "argo-workflows"   # Workflows
    "argo-events"      # Events
    "argocd-applicationset" # ApplicationSet
    "argocd-notifications"  # Notifications
    "gitea"            # Git repos
    "minio"            # Storage
    "loki"             # Logs
    "jaeger"           # Tracing
    "grafana"          # Dashboards
)

for app in "${CRITICAL_APPS[@]}"; do
    echo "🔧 Procesando $app..."
    
    # Forzar refresh
    kubectl annotate application $app -n argocd argocd.argoproj.io/refresh=now --overwrite 2>/dev/null
    
    # Habilitar auto-sync si no está habilitado
    kubectl patch application $app -n argocd --type='merge' -p='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true},"syncOptions":["CreateNamespace=true","ServerSideApply=true"]}}}' 2>/dev/null
    
    # Esperar un poco entre apps
    sleep 2
done

echo ""
echo "✅ Sincronización iniciada para todas las aplicaciones críticas"
echo "💡 Verificar estado con: kubectl get applications -n argocd"
