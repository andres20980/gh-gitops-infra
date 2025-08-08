#!/bin/bash
# ============================================================================
# MÓDULO DE MONITOREO Y VERIFICACIÓN GITOPS - v3.0.0
# ============================================================================
# Especializado en monitoreo activo y verificación de estado
# Máximo: 400 líneas - Principio de Responsabilidad Única

set +u  # Desactivar verificación de variables no definidas

# Función para esperar a que todas las aplicaciones estén Synced y Healthy
esperar_aplicaciones_completas() {
    local max_intentos=60  # 10 minutos máximo
    local contador=1
    local aplicaciones_esperadas=(
        "argo-events" "argo-rollouts" "argo-workflows" "cert-manager"
        "external-secrets" "gitea" "grafana" "ingress-nginx" "jaeger"
        "kargo" "loki" "minio" "prometheus-stack"
    )
    
    echo "🎯 Verificando estado de ${#aplicaciones_esperadas[@]} herramientas GitOps..."
    echo "⚠️  MODO ACTIVO: Diagnosticando y corrigiendo problemas automáticamente"
    
    while [[ $contador -le $max_intentos ]]; do
        echo "[$contador/$max_intentos] 🔍 Verificando estado de aplicaciones..."
        
        local todas_ok=true
        local aplicaciones_problematicas=()
        local aplicaciones_out_of_sync=()
        local aplicaciones_unhealthy=()
        
        # Verificar cada aplicación esperada
        for app in "${aplicaciones_esperadas[@]}"; do
            verificar_estado_aplicacion "$app" todas_ok aplicaciones_problematicas aplicaciones_out_of_sync aplicaciones_unhealthy
        done
        
        if [[ "$todas_ok" == "true" ]]; then
            echo
            echo "✅ ¡Todas las herramientas GitOps están Synced y Healthy!"
            mostrar_estado_final_aplicaciones
            return 0
        fi
        
        # Mostrar aplicaciones problemáticas
        mostrar_problemas_aplicaciones "${aplicaciones_problematicas[@]}"
        
        # CORRECCIONES ACTIVAS cada 3 intentos
        if [[ $((contador % 3)) -eq 0 ]]; then
            ejecutar_correcciones_activas "${aplicaciones_out_of_sync[@]}" "${aplicaciones_unhealthy[@]}"
        fi
        
        # CORRECCIÓN PROFUNDA cada 10 intentos
        if [[ $((contador % 10)) -eq 0 ]]; then
            ejecutar_correccion_profunda
        fi
        
        echo "   ⏱️  Esperando 10 segundos antes del siguiente chequeo..."
        sleep 10
        ((contador++))
    done
    
    echo
    echo "❌ ¡TIMEOUT! Algunas aplicaciones no llegaron a estar Synced y Healthy"
    ejecutar_correccion_emergencia_final
    return 1
}

# Función para verificar estado de una aplicación individual
verificar_estado_aplicacion() {
    local app="$1"
    local -n todas_ok_ref="$2"
    local -n problematicas_ref="$3"
    local -n out_of_sync_ref="$4"
    local -n unhealthy_ref="$5"
    
    if ! kubectl get application "$app" -n argocd >/dev/null 2>&1; then
        todas_ok_ref=false
        problematicas_ref+=("$app:NO_EXISTE")
        return
    fi
    
    local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    if [[ "$sync_status" != "Synced" ]]; then
        todas_ok_ref=false
        out_of_sync_ref+=("$app")
        problematicas_ref+=("$app:$sync_status/$health_status")
    elif [[ "$health_status" != "Healthy" ]]; then
        todas_ok_ref=false
        unhealthy_ref+=("$app")
        problematicas_ref+=("$app:$sync_status/$health_status")
    fi
}

# Función para mostrar problemas de aplicaciones
mostrar_problemas_aplicaciones() {
    local aplicaciones_problematicas=("$@")
    
    if [[ ${#aplicaciones_problematicas[@]} -gt 0 ]]; then
        echo "   ⚠️  Aplicaciones pendientes: ${aplicaciones_problematicas[@]:0:5}"
        if [[ ${#aplicaciones_problematicas[@]} -gt 5 ]]; then
            echo "      ... y $((${#aplicaciones_problematicas[@]} - 5)) más"
        fi
    fi
}

# Función para ejecutar correcciones activas
ejecutar_correcciones_activas() {
    local aplicaciones_out_of_sync=("$@")
    
    echo "   🔧 Aplicando correcciones activas..."
    
    # Separar argumentos entre out_of_sync y unhealthy
    local separador_encontrado=false
    local aplicaciones_unhealthy=()
    local apps_out_of_sync=()
    
    for arg in "$@"; do
        if [[ "$arg" == "--unhealthy" ]]; then
            separador_encontrado=true
            continue
        fi
        
        if [[ "$separador_encontrado" == "true" ]]; then
            aplicaciones_unhealthy+=("$arg")
        else
            apps_out_of_sync+=("$arg")
        fi
    done
    
    # Forzar sincronización de aplicaciones OutOfSync
    if [[ ${#apps_out_of_sync[@]} -gt 0 ]]; then
        forzar_sincronizacion_apps "${apps_out_of_sync[@]}"
    fi
    
    # Diagnosticar aplicaciones Unhealthy
    if [[ ${#aplicaciones_unhealthy[@]} -gt 0 ]]; then
        diagnosticar_aplicaciones_unhealthy "${aplicaciones_unhealthy[@]}"
    fi
    
    # Verificar App of Tools principal
    verificar_app_of_tools
}

# Función para forzar sincronización de aplicaciones
forzar_sincronizacion_apps() {
    local apps_out_of_sync=("$@")
    
    echo "   🔄 Forzando sincronización de aplicaciones OutOfSync..."
    for app in "${apps_out_of_sync[@]}"; do
        echo "      🔄 Sincronizando: $app"
        kubectl patch application "$app" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true}}}}}' >/dev/null 2>&1 || true
    done
}

# Función para diagnosticar aplicaciones Unhealthy
diagnosticar_aplicaciones_unhealthy() {
    local aplicaciones_unhealthy=("$@")
    
    echo "   🩺 Diagnosticando aplicaciones Unhealthy..."
    for app in "${aplicaciones_unhealthy[@]}"; do
        echo "      🩺 Diagnosticando: $app"
        
        # Obtener información del estado
        local mensaje_health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.message}' 2>/dev/null || echo "")
        local conditions=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null || echo "")
        
        echo "         Estado: $mensaje_health"
        if [[ -n "$conditions" ]]; then
            echo "         Condiciones: $conditions"
        fi
        
        # Verificar y crear namespace si es necesario
        verificar_namespace_aplicacion "$app"
        
        # Verificar eventos de warning
        verificar_eventos_warning "$app"
    done
}

# Función para verificar namespace de aplicación
verificar_namespace_aplicacion() {
    local app="$1"
    local target_namespace=$(kubectl get application "$app" -n argocd -o jsonpath='{.spec.destination.namespace}' 2>/dev/null || echo "")
    
    if [[ -n "$target_namespace" ]]; then
        if ! kubectl get namespace "$target_namespace" >/dev/null 2>&1; then
            echo "         🔧 Creando namespace faltante: $target_namespace"
            kubectl create namespace "$target_namespace" >/dev/null 2>&1 || true
        fi
    fi
}

# Función para verificar eventos de warning
verificar_eventos_warning() {
    local app="$1"
    local target_namespace=$(kubectl get application "$app" -n argocd -o jsonpath='{.spec.destination.namespace}' 2>/dev/null || echo "")
    
    if [[ -n "$target_namespace" ]]; then
        local recursos_error=$(kubectl get events -n "$target_namespace" --field-selector type=Warning --no-headers 2>/dev/null | head -3)
        if [[ -n "$recursos_error" ]]; then
            echo "         ⚠️ Eventos de warning en $target_namespace:"
            echo "$recursos_error" | sed 's/^/            /'
        fi
    fi
}

# Función para verificar App of Tools
verificar_app_of_tools() {
    echo "   🔍 Verificando App of Tools principal..."
    
    if ! kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
        echo "   🚨 App of Tools no encontrada, reaplicando..."
        if kubectl apply -f argo-apps/app-of-tools-gitops.yaml >/dev/null 2>&1; then
            echo "   ✅ App of Tools reaplicada"
        else
            echo "   ❌ Error reaplicando App of Tools"
        fi
    else
        local sync_status=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        if [[ "$sync_status" != "Synced" ]]; then
            echo "   🔄 Forzando sincronización de App of Tools..."
            kubectl patch application app-of-tools-gitops -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true}}}}}' >/dev/null 2>&1 || true
        fi
    fi
}

# Función de corrección profunda
ejecutar_correccion_profunda() {
    echo "      🔧 Corrección profunda iniciada..."
    
    # Refresh completo de ArgoCD
    echo "      🔄 Refrescando repositorio en ArgoCD..."
    kubectl patch application app-of-tools-gitops -n argocd --type merge -p '{"operation":{"refresh":{}}}' >/dev/null 2>&1 || true
    
    # Verificar estado de ArgoCD server
    verificar_argocd_server
    
    # Limpiar aplicaciones en estado error
    limpiar_aplicaciones_error
}

# Función para verificar ArgoCD server
verificar_argocd_server() {
    if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | grep -q Running; then
        echo "      🚨 ArgoCD server problemático, reiniciando..."
        kubectl rollout restart deployment argocd-server -n argocd >/dev/null 2>&1 || true
    fi
}

# Función para limpiar aplicaciones en estado error
limpiar_aplicaciones_error() {
    echo "      🧹 Limpiando aplicaciones en estado error..."
    local apps_error=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}:{.status.health.status}{"\n"}{end}' 2>/dev/null | grep ":Unknown\|:Missing" | cut -d: -f1)
    
    if [[ -n "$apps_error" ]]; then
        while read -r app; do
            if [[ -n "$app" ]]; then
                echo "      🔄 Recreando aplicación problemática: $app"
                kubectl patch application "$app" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true},"prune":true}}}}' >/dev/null 2>&1 || true
            fi
        done <<< "$apps_error"
    fi
}

# Función de corrección de emergencia final
ejecutar_correccion_emergencia_final() {
    echo "🚨 Ejecutando corrección de emergencia final..."
    
    local herramientas_criticas=("grafana" "prometheus-stack" "ingress-nginx" "cert-manager")
    local criticas_ok=0
    
    for tool in "${herramientas_criticas[@]}"; do
        if verificar_herramienta_critica "$tool"; then
            ((criticas_ok++))
        fi
    done
    
    echo "📊 Herramientas críticas funcionando: $criticas_ok/${#herramientas_criticas[@]}"
    
    if [[ $criticas_ok -ge 2 ]]; then
        echo "✅ Al menos las herramientas críticas básicas están funcionando"
        return 0
    else
        echo "❌ Demasiadas herramientas críticas fallando"
        return 1
    fi
}

# Función para verificar herramienta crítica
verificar_herramienta_critica() {
    local tool="$1"
    
    if kubectl get application "$tool" -n argocd >/dev/null 2>&1; then
        local sync_status=$(kubectl get application "$tool" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        local health_status=$(kubectl get application "$tool" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
            echo "   ✅ Crítica OK: $tool"
            return 0
        else
            echo "   ❌ Crítica PROBLEMA: $tool ($sync_status/$health_status)"
            # Último intento de corrección
            kubectl patch application "$tool" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true},"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1 || true
            return 1
        fi
    else
        echo "   ❌ Crítica FALTANTE: $tool"
        return 1
    fi
}
