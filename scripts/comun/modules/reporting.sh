#!/bin/bash
# ============================================================================
# MÓDULO DE REPORTING Y ESTADO GITOPS - v3.0.0
# ============================================================================
# Especializado en reporting detallado y mostrar estado final
# Máximo: 300 líneas - Principio de Responsabilidad Única

set +u  # Desactivar verificación de variables no definidas

# Función para mostrar estado final detallado de aplicaciones
mostrar_estado_final_aplicaciones() {
    echo
    echo "📊 Estado detallado de todas las herramientas GitOps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local aplicaciones_esperadas=(
        "argo-events" "argo-rollouts" "argo-workflows" "cert-manager"
        "external-secrets" "gitea" "grafana" "ingress-nginx" "jaeger"
        "kargo" "loki" "minio" "prometheus-stack"
    )
    
    local estadisticas
    calcular_estadisticas_aplicaciones aplicaciones_esperadas estadisticas
    mostrar_tabla_estado_aplicaciones "${aplicaciones_esperadas[@]}"
    mostrar_resumen_ejecutivo estadisticas
    verificar_configuracion_multicluster
}

# Función para calcular estadísticas de aplicaciones
calcular_estadisticas_aplicaciones() {
    local -n apps_esperadas_ref="$1"
    local -n stats_ref="$2"
    
    local total_apps=${#apps_esperadas_ref[@]}
    local apps_synced=0
    local apps_healthy=0
    local apps_completas=0
    
    for app in "${apps_esperadas_ref[@]}"; do
        if kubectl get application "$app" -n argocd >/dev/null 2>&1; then
            local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            [[ "$sync_status" == "Synced" ]] && ((apps_synced++))
            [[ "$health_status" == "Healthy" ]] && ((apps_healthy++))
            [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]] && ((apps_completas++))
        fi
    done
    
    stats_ref["total"]=$total_apps
    stats_ref["synced"]=$apps_synced
    stats_ref["healthy"]=$apps_healthy
    stats_ref["completas"]=$apps_completas
}

# Función para mostrar tabla de estado de aplicaciones
mostrar_tabla_estado_aplicaciones() {
    local aplicaciones_esperadas=("$@")
    
    printf "%-18s %-12s %-12s %-15s\n" "APLICACIÓN" "SYNC" "HEALTH" "ESTADO"
    echo "──────────────────┼────────────┼────────────┼───────────────"
    
    for app in "${aplicaciones_esperadas[@]}"; do
        mostrar_fila_estado_aplicacion "$app"
    done
}

# Función para mostrar una fila de estado de aplicación
mostrar_fila_estado_aplicacion() {
    local app="$1"
    
    if ! kubectl get application "$app" -n argocd >/dev/null 2>&1; then
        printf "%-18s %-12s %-12s %-15s\n" "$app" "NO_EXISTE" "NO_EXISTE" "❌ FALTANTE"
        return
    fi
    
    local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    # Estado visual
    local estado_visual="❌ PROBLEMA"
    if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
        estado_visual="✅ COMPLETO"
    elif [[ "$sync_status" == "Synced" ]]; then
        estado_visual="🔄 SYNC_OK"
    elif [[ "$health_status" == "Healthy" ]]; then
        estado_visual="⚠️ HEALTH_OK"
    fi
    
    printf "%-18s %-12s %-12s %-15s\n" "$app" "$sync_status" "$health_status" "$estado_visual"
}

# Función para mostrar resumen ejecutivo
mostrar_resumen_ejecutivo() {
    local -n stats_ref="$1"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📈 RESUMEN EJECUTIVO:"
    echo "   🎯 Aplicaciones completas (Synced + Healthy): ${stats_ref[completas]}/${stats_ref[total]}"
    echo "   🔄 Aplicaciones sincronizadas: ${stats_ref[synced]}/${stats_ref[total]}"
    echo "   💚 Aplicaciones saludables: ${stats_ref[healthy]}/${stats_ref[total]}"
    
    local porcentaje_completas=$((stats_ref[completas] * 100 / stats_ref[total]))
    echo "   📊 Porcentaje de éxito: $porcentaje_completas%"
    
    mostrar_evaluacion_estado "${stats_ref[completas]}" "${stats_ref[total]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Función para mostrar evaluación del estado
mostrar_evaluacion_estado() {
    local apps_completas="$1"
    local total_apps="$2"
    
    if [[ $apps_completas -eq $total_apps ]]; then
        echo "   🎉 ¡TODAS LAS HERRAMIENTAS GITOPS ESTÁN OPERATIVAS!"
    elif [[ $apps_completas -ge $((total_apps * 80 / 100)) ]]; then
        echo "   ✅ La mayoría de herramientas están funcionando correctamente"
    elif [[ $apps_completas -ge $((total_apps * 50 / 100)) ]]; then
        echo "   ⚠️ Aproximadamente la mitad de herramientas están funcionando"
    else
        echo "   ❌ La mayoría de herramientas tienen problemas - requiere intervención"
    fi
}

# Función para verificar configuración multi-cluster
verificar_configuracion_multicluster() {
    echo
    echo "🌐 Verificando configuración multi-cluster de ArgoCD..."
    
    local clusters_configurados
    clusters_configurados=$(kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster -o name 2>/dev/null | wc -l)
    
    echo "   📊 Clusters configurados en ArgoCD: $clusters_configurados"
    
    if [[ $clusters_configurados -eq 0 ]]; then
        echo "   ℹ️  Solo cluster local configurado (normal para entorno dev)"
        echo "   💡 Para multi-cluster, ejecutar configuración adicional en fases posteriores"
    else
        echo "   ✅ Configuración multi-cluster detectada"
        mostrar_clusters_externos
    fi
    
    return 0
}

# Función para mostrar clusters externos
mostrar_clusters_externos() {
    echo "   🔍 Clusters externos configurados:"
    local clusters_info=$(kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster -o custom-columns="CLUSTER:.metadata.labels.argocd\.argoproj\.io/secret-type,SERVER:.data.server" 2>/dev/null)
    
    if [[ -n "$clusters_info" ]]; then
        echo "$clusters_info" | sed 's/^/      /'
    else
        echo "      (Detalles no disponibles)"
    fi
}

# Función para generar reporte de despliegue
generar_reporte_despliegue() {
    local archivo_reporte="logs/reporte-despliegue-$(date +%Y%m%d-%H%M%S).md"
    
    echo "📝 Generando reporte de despliegue en $archivo_reporte..."
    
    cat > "$archivo_reporte" << EOF
# Reporte de Despliegue GitOps

**Fecha:** $(date '+%Y-%m-%d %H:%M:%S')  
**Versión:** v3.0.0  
**Cluster:** $(kubectl config current-context)  

## Estado de Aplicaciones

$(mostrar_estado_final_aplicaciones 2>/dev/null)

## Información del Sistema

- **Kubernetes Version:** $(kubectl version --short --client 2>/dev/null | head -1 || echo "No disponible")
- **ArgoCD Version:** $(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/version}' 2>/dev/null || echo "No disponible")
- **Número de Nodos:** $(kubectl get nodes --no-headers 2>/dev/null | wc -l)

## Herramientas Autodescubiertas

$(for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
    local key_repo="${herramienta}_repo"
    local key_chart="${herramienta}_chart"
    local repo="${GITOPS_CHART_INFO[$key_repo]:-unknown}"
    local chart="${GITOPS_CHART_INFO[$key_chart]:-unknown}"
    echo "- **$herramienta:** $repo/$chart"
done)

## Tiempo de Despliegue

- **Inicio:** $INICIO_DESPLIEGUE
- **Fin:** $(date '+%Y-%m-%d %H:%M:%S')

EOF

    echo "✅ Reporte generado: $archivo_reporte"
}

# Función para mostrar métricas de rendimiento
mostrar_metricas_rendimiento() {
    echo
    echo "📊 Métricas de Rendimiento del Despliegue:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Tiempo de despliegue
    if [[ -n "${INICIO_DESPLIEGUE:-}" ]]; then
        local tiempo_total=$(( $(date +%s) - $(date -d "$INICIO_DESPLIEGUE" +%s) ))
        echo "   ⏱️  Tiempo total de despliegue: $tiempo_total segundos"
    fi
    
    # Uso de recursos del cluster
    echo "   🖥️  Uso de recursos del cluster:"
    kubectl top nodes 2>/dev/null | head -5 | sed 's/^/      /' || echo "      (Métricas no disponibles)"
    
    # Número de pods por namespace
    echo "   📦 Pods por namespace GitOps:"
    kubectl get pods --all-namespaces --no-headers 2>/dev/null | \
        grep -E "(argo|grafana|prometheus|nginx|cert-manager|minio|gitea|jaeger|loki|kargo)" | \
        awk '{print $1}' | sort | uniq -c | sed 's/^/      /'
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
