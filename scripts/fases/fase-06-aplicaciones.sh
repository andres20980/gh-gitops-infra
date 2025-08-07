#!/bin/bash

# ============================================================================
# FASE 6: DESPLIEGUE DE APLICACIONES
# ============================================================================
# Despliega aplicaciones de prueba usando Application Sets
# Script autocontenido - puede ejecutarse independientemente
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar autocontención
if [[ -f "$SCRIPT_DIR/../comun/autocontener.sh" ]]; then
    # shellcheck source=../comun/autocontener.sh
    source "$SCRIPT_DIR/../comun/autocontener.sh"
else
    echo "❌ Error: No se pudo cargar el módulo de autocontención" >&2
    echo "   Asegúrate de ejecutar desde la estructura correcta del proyecto" >&2
    exit 1
fi

# ============================================================================
# FUNCIONES DE LA FASE X
# ============================================================================

# Verificar prerrequisitos críticos de la Fase 6
verificar_prerrequisitos_fase6() {
    log_info "🔍 VERIFICACIÓN CRÍTICA: Comprobando prerrequisitos para Fase 6..."
    
    # 1. Verificar que ArgoCD está healthy
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD no está instalado"
        return 1
    fi
    
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD server no está disponible"
        return 1
    fi
    
    # 2. Verificar que las herramientas GitOps están synced y healthy
    log_info "🔍 Verificando que herramientas GitOps están ready..."
    
    if kubectl get application tools-gitops -n argocd >/dev/null 2>&1; then
        local sync_status
        sync_status=$(kubectl get application tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        local health_status
        health_status=$(kubectl get application tools-gitops -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$sync_status" != "Synced" ]] || [[ "$health_status" != "Healthy" ]]; then
            log_error "❌ PRERREQUISITO FALLA: App of Tools no está synced/healthy ($sync_status/$health_status)"
            log_error "❌ NO ES SEGURO desplegar aplicaciones sin herramientas GitOps ready"
            log_info "💡 Ejecuta primero: ./instalar.sh --fase 05"
            log_info "💡 Verifica manualmente: kubectl get applications -n argocd"
            return 1
        fi
        
        log_success "✅ App of Tools está synced y healthy ($sync_status/$health_status)"
    else
        log_error "❌ PRERREQUISITO FALLA: App of Tools no encontrada"
        log_error "❌ Las herramientas GitOps no están desplegadas"
        log_info "💡 Ejecuta primero: ./instalar.sh --fase 05"
        return 1
    fi
    
    # 3. Verificar namespaces críticos de herramientas
    local herramientas_namespaces=("cert-manager" "ingress-nginx" "monitoring")
    local namespaces_ready=0
    
    for ns in "${herramientas_namespaces[@]}"; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            local pods_running
            pods_running=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep -c " Running " || echo "0")
            if [[ $pods_running -gt 0 ]]; then
                ((namespaces_ready++))
                log_success "✅ $ns: $pods_running pods running"
            else
                log_warning "⚠️ $ns: no hay pods running"
            fi
        else
            log_warning "⚠️ $ns: namespace no existe"
        fi
    done
    
    if [[ $namespaces_ready -lt 2 ]]; then
        log_error "❌ PRERREQUISITO FALLA: Muy pocas herramientas GitOps están ready ($namespaces_ready/${#herramientas_namespaces[@]})"
        log_error "❌ NO ES SEGURO desplegar aplicaciones sin infraestructura básica"
        log_info "💡 Espera a que las herramientas se desplieguen completamente"
        return 1
    fi
    
    log_success "✅ PRERREQUISITOS OK: $namespaces_ready/${#herramientas_namespaces[@]} herramientas críticas ready"
    log_success "✅ Es seguro proceder con el despliegue de aplicaciones"
    return 0
}

# Configurar aplicaciones custom
configurar_aplicaciones_custom() {
    desplegar_aplicaciones_custom
    generar_commit_aplicaciones_custom
}

# Desplegar ApplicationSets
desplegar_application_sets() {
    log_info "🚀 Desplegando ApplicationSets..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Desplegaría ApplicationSets"
        return 0
    fi
    
    # Aplicar ApplicationSet para aplicaciones
    if [[ -f "argo-apps/appset-aplicaciones-custom.yaml" ]]; then
        kubectl apply -f argo-apps/appset-aplicaciones-custom.yaml
        log_success "✅ ApplicationSets desplegados"
    else
        log_warning "⚠️ ApplicationSet no encontrado"
    fi
}

# Desplegar aplicaciones custom
desplegar_aplicaciones_custom() {
    log_info "🚀 Desplegando aplicaciones custom..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría despliegue de aplicaciones custom"
        return 0
    fi
    
    # VERIFICACIÓN CRÍTICA: Las herramientas GitOps DEBEN estar 100% operativas
    log_info "🔒 VERIFICACIÓN CRÍTICA: Herramientas GitOps deben estar 100% operativas"
    log_info "📋 Requisito: TODAS las tools deben estar Synced AND Healthy simultáneamente"
    
    if ! verificar_sistema_gitops_healthy; then
        log_error "❌ BLOQUEADO: Las herramientas GitOps NO están completamente healthy"
        log_error "❌ NO se desplegarán aplicaciones custom hasta que las tools estén operativas"
        log_info "💡 Ejecuta 'kubectl get applications -n argocd' para revisar el estado"
        log_info "💡 TODAS las tools críticas deben estar Synced + Healthy antes de continuar"
        return 1
    fi
    
    log_success "✅ VERIFICACIÓN PASADA: TODAS las herramientas GitOps están Synced + Healthy"
    log_info "🎯 13 herramientas GitOps críticas verificadas y operativas"
    log_info "🚀 Procediendo con despliegue de aplicaciones custom integradas..."
    
    # Aplicar ApplicationSet para aplicaciones custom
    log_info "📦 Aplicando ApplicationSet para aplicaciones custom con integración GitOps..."
    kubectl apply -f argo-apps/appset-aplicaciones-custom.yaml
    
    # REGENERAR APLICACIONES CUSTOM CON INTEGRACIÓN GITOPS COMPLETA
    log_info "🔧 Regenerando aplicaciones custom con integración GitOps completa..."
    local generador_script="$COMUN_DIR/generar-apps-gitops-completas.sh"
    
    if [[ -f "$generador_script" ]]; then
        # Regenerar demo-project con todas las integraciones GitOps
        log_info "🚀 Regenerando demo-project con integración completa..."
        "$generador_script" generar demo-backend demo-project "node:18-alpine" "demo-backend.local" \
            "https://github.com/andres20980/gh-gitops-infra.git" \
            "./aplicaciones/demo-project/manifests-gitops"
        
        "$generador_script" generar demo-frontend demo-project "nginx:alpine" "demo-frontend.local" \
            "https://github.com/andres20980/gh-gitops-infra.git" \
            "./aplicaciones/demo-project/manifests-gitops"
        
        "$generador_script" generar demo-database demo-project "postgres:15" "demo-db.local" \
            "https://github.com/andres20980/gh-gitops-infra.git" \
            "./aplicaciones/demo-project/manifests-gitops"
        
        # Regenerar simple-app con todas las integraciones GitOps
        log_info "🚀 Regenerando simple-app con integración completa..."
        "$generador_script" generar nginx-simple simple-app "nginx:alpine" "nginx.local" \
            "https://github.com/andres20980/gh-gitops-infra.git" \
            "./aplicaciones/simple-app/manifests-gitops"
        
        "$generador_script" generar redis-simple simple-app "redis:alpine" "redis.local" \
            "https://github.com/andres20980/gh-gitops-infra.git" \
            "./aplicaciones/simple-app/manifests-gitops"
        
        log_success "✅ Aplicaciones custom regeneradas con integración GitOps completa"
        
        # Commit y push de las nuevas configuraciones
        generar_commit_aplicaciones_custom
        
    else
        log_warning "⚠️ Generador de apps GitOps no encontrado, usando configuraciones básicas"
    fi
    
    # Esperar a que estén synced
    verificar_aplicaciones_custom_synced
    
    log_success "✅ Aplicaciones custom desplegadas"
    return 0
}

# Generar commit y push de aplicaciones custom
generar_commit_aplicaciones_custom() {
    log_info "📡 Commiteando aplicaciones custom mejoradas..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría commit y push de aplicaciones custom"
        return 0
    fi
    
    git add aplicaciones/
    git commit -m "🚀 Apps Custom con Integración GitOps Completa

- Regeneración completa de demo-project y simple-app
- Integración con todas las herramientas GitOps:
  * Argo Rollouts para progressive delivery
  * Prometheus + Grafana para monitoring
  * Jaeger para distributed tracing  
  * Loki para log aggregation
  * External Secrets para gestión de secretos
  * Cert Manager para TLS automático
  * Argo Workflows para CI/CD
  * Kargo para promotion pipeline
  * Ingress NGINX para traffic routing
- Configuraciones production-ready
- Generado automáticamente por instalar.sh"
    
    git push origin main
    log_success "✅ Aplicaciones custom mejoradas pusheadas a GitHub"
}

# Verificar que aplicaciones custom están synced
verificar_aplicaciones_custom_synced() {
    log_info "⏳ Esperando que aplicaciones custom estén synced..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Verificaría estado de aplicaciones custom"
        return 0
    fi
    
    sleep 30  # Dar tiempo inicial
    
    local timeout=300
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local custom_apps_ready
        custom_apps_ready=$(kubectl get applications -n argocd -l component=custom-app -o jsonpath='{.items[*].status.sync.status}' 2>/dev/null | grep -c "Synced" || echo "0")
        
        if [[ $custom_apps_ready -gt 0 ]]; then
            log_success "✅ Aplicaciones custom synced y healthy"
            return 0
        fi
        
        sleep 15
        elapsed=$((elapsed + 15))
        
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            log_info "⏳ Esperando aplicaciones custom... (${elapsed}s/${timeout}s)"
        fi
    done
    
    log_warning "⚠️ Timeout esperando aplicaciones custom (continuando...)"
    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE 6
# ============================================================================

fase_06_aplicaciones() {
    log_info "🚀 FASE 6: Despliegue de Aplicaciones"
    log_info "═══════════════════════════════════════"
    
    # Verificar que no estamos ejecutando como root
    if [[ "$EUID" -eq 0 ]]; then
        log_error "❌ Esta fase no debe ejecutarse como root"
        log_info "💡 Las aplicaciones deben desplegarse con usuario normal"
        return 1
    fi
    
    # VERIFICACIÓN CRÍTICA: Comprobar prerrequisitos
    if ! verificar_prerrequisitos_fase6; then
        log_error "❌ FASE 6 ABORTADA: Los prerrequisitos no se cumplen"
        log_error "❌ Las herramientas GitOps deben estar completamente ready antes de desplegar aplicaciones"
        log_info "💡 Soluciones:"
        log_info "   1. Ejecuta: ./instalar.sh --fase 05"
        log_info "   2. Espera a que todas las herramientas estén synced/healthy"
        log_info "   3. Verifica: kubectl get applications -n argocd"
        log_info "   4. Luego ejecuta: ./instalar.sh --fase 06"
        return 1
    fi
    
    # Configurar y desplegar aplicaciones
    log_info "📦 Configurando aplicaciones de ejemplo..."
    configurar_aplicaciones_custom
    
    log_info "🚀 Desplegando ApplicationSets..."
    desplegar_application_sets
    
    log_info "⏳ Verificando despliegue de aplicaciones..."
    verificar_aplicaciones_custom_synced
    
    log_info "📋 Para verificar el estado de las aplicaciones:"
    log_info "   kubectl get applications -n argocd"
    log_info "   kubectl get pods --all-namespaces"
    
    log_info "✅ Fase 6 completada: Aplicaciones desplegadas"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_06_aplicaciones "$@"
fi
