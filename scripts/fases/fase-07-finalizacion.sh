#!/bin/bash

# ============================================================================
# FASE 7: FINALIZACIÓN Y VERIFICACIÓN
# ============================================================================
# Verifica el estado final y proporciona información de acceso
# Script autocontenido - puede ejecutarse independientemente
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar autocontención
if [[ -f "$SCRIPT_DIR/../comun/bootstrap.sh" ]]; then
    # shellcheck source=../comun/bootstrap.sh
    source "$SCRIPT_DIR/../comun/bootstrap.sh"
else
    echo "❌ Error: No se pudo cargar el módulo de autocontención" >&2
    echo "   Asegúrate de ejecutar desde la estructura correcta del proyecto" >&2
    exit 1
fi

# ============================================================================
# FUNCIONES DE LA FASE X
# ============================================================================

# Mostrar accesos al sistema
mostrar_accesos_sistema() {
    log_section "🌟 Accesos al Sistema GitOps"
    
    # ArgoCD
    local argocd_port
    argocd_port=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
    local argocd_ip
    argocd_ip=$(minikube ip --profile="$CLUSTER_DEV_NAME" 2>/dev/null || echo "N/A")
    
    log_info "🔄 ArgoCD:"
    log_info "   URL: https://$argocd_ip:$argocd_port"
    log_info "   Usuario: admin"
    
    local argocd_password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Ver en cluster")
    log_info "   Password: $argocd_password"
    
    # Clusters disponibles
    log_info "🌐 Clusters disponibles:"
    log_info "   • $CLUSTER_DEV_NAME (desarrollo - completo)"
    if [[ "$SOLO_DEV" != "true" ]]; then
        log_info "   • $CLUSTER_PRE_NAME (preproducción - mínimo)"
        log_info "   • $CLUSTER_PRO_NAME (producción - mínimo)"
    fi
    
    # Comandos útiles
    log_info "💡 Comandos útiles:"
    log_info "   • kubectl config use-context $CLUSTER_DEV_NAME"
    log_info "   • kubectl get applications -n argocd"
    log_info "   • minikube dashboard --profile=$CLUSTER_DEV_NAME"
    
    # Mostrar URLs de servicios principales si están disponibles
    mostrar_urls_servicios
}

# Mostrar URLs de servicios principales
mostrar_urls_servicios() {
    local services=(
        "grafana:grafana:3000"
        "prometheus:prometheus-stack-kube-prom-prometheus:9090"
        "jaeger:jaeger-query:16686"
        "gitea:gitea-http:3000"
    )
    
    log_info "🌐 Servicios disponibles:"
    
    for service in "${services[@]}"; do
        IFS=':' read -r name svc_name port <<< "$service"
        
        local nodeport
        nodeport=$(kubectl get svc "$svc_name" -n "$name" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
        
        if [[ -n "$nodeport" ]]; then
            local cluster_ip
            cluster_ip=$(minikube ip --profile="$CLUSTER_DEV_NAME" 2>/dev/null || echo "localhost")
            log_info "   • $name: http://$cluster_ip:$nodeport"
        fi
    done
}

# Mostrar resumen final del proceso
mostrar_resumen_final() {
    log_section "🎉 ENTORNO GITOPS ABSOLUTO COMPLETADO"
    log_success "✅ Proceso desatendido completado exitosamente"
    log_info "🌟 Entorno GitOps Absoluto configurado:"
    log_info "   • Cluster gitops-dev: ArgoCD + Todas las herramientas + Apps custom"
    
    if [[ "$SOLO_DEV" != "true" ]]; then
        log_info "   • Cluster gitops-pre: Listo para promociones con Kargo"
        log_info "   • Cluster gitops-pro: Listo para promociones con Kargo"
        log_info "   • Sistema de promoción automática configurado"
    fi
    
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "📄 Log completo guardado en: $LOG_FILE"
    fi
    
    mostrar_accesos_sistema
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE 7
# ============================================================================

fase_07_finalizacion() {
    log_info "🎯 FASE 7: Finalización y Verificación"
    log_info "════════════════════════════════════════"
    
    # Verificar estado final del sistema
    log_info "🔍 Verificando estado final del sistema..."
    
    # Verificar clusters activos
    log_info "📋 Clusters activos:"
    minikube profile list 2>/dev/null || log_warning "No se pudo listar perfiles"
    
    # Verificar ArgoCD y aplicaciones
    if kubectl get namespace argocd >/dev/null 2>&1; then
        log_info "📋 Aplicaciones en ArgoCD:"
        kubectl get applications -n argocd 2>/dev/null | head -10 || log_warning "No se pudo listar aplicaciones"
    fi
    
    # Mostrar resumen final y accesos
    mostrar_resumen_final
    
    log_info "✅ Fase 7 completada: Sistema verificado y finalizado"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_07_finalizacion "$@"
fi
