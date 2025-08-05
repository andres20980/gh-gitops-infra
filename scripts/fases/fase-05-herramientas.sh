#!/bin/bash

# ============================================================================
# FASE 5: HERRAMIENTAS GITOPS
# ============================================================================

# Actualizar helm charts y desplegar herramientas
actualizar_y_desplegar_herramientas() {
    log_info "📊 Actualizando helm charts y desplegando herramientas GitOps..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría optimización de herramientas"
        log_info "[DRY-RUN] Ejecutaría actualización de helm charts"
        log_info "[DRY-RUN] Ejecutaría despliegue de herramientas via ArgoCD"
        return 0
    fi
    
    # ========================================================================
    # 1. OPTIMIZAR CONFIGURACIONES DE HERRAMIENTAS
    # ========================================================================
    log_info "🔧 Optimizando configuraciones de herramientas GitOps para desarrollo..."
    local optimizador_script="$COMUN_DIR/optimizar-dev.sh"
    
    if [[ -f "$optimizador_script" ]]; then
        if "$optimizador_script" herramientas-gitops; then
            log_success "✅ Herramientas optimizadas con configuraciones mínimas"
        else
            log_error "❌ Error optimizando herramientas GitOps"
            return 1
        fi
    else
        log_warning "⚠️ Script optimizador no encontrado: $optimizador_script"
        log_info "Continuando con configuraciones por defecto..."
    fi
    
    # ========================================================================
    # 2. ACTUALIZAR HELM CHARTS
    # ========================================================================
    log_info "📊 Actualizando versiones de helm charts..."
    local helm_updater_script="$COMUN_DIR/helm-updater.sh"
    
    if [[ -f "$helm_updater_script" ]]; then
        if "$helm_updater_script" update herramientas-gitops; then
            log_success "✅ Helm charts actualizados a últimas versiones"
        else
            log_warning "⚠️ Error actualizando helm charts (continuando...)"
        fi
    else
        log_info "ℹ️ Actualizador de helm charts no encontrado (usando versiones fijas)"
    fi
    
    # ========================================================================
    # 2.1. COMMIT Y PUSH AUTOMÁTICO DE CAMBIOS
    # ========================================================================
    log_info "📡 Commiteando y pusheando cambios para ArgoCD..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría commit y push de cambios optimizados"
    else
        # Verificar si hay cambios
        if git diff --quiet && git diff --cached --quiet; then
            log_info "ℹ️ No hay cambios para commitear"
        else
            # Agregar todos los cambios
            git add herramientas-gitops/ argo-apps/
            
            # Commit con mensaje descriptivo
            local commit_msg="🔧 Auto-optimización GitOps: actualización de herramientas y configuraciones

- Optimización de 13 herramientas GitOps con mejores prácticas
- Actualización de versiones de Helm charts
- Configuraciones mínimas para desarrollo
- Generado automáticamente por instalar.sh"

            git commit -m "$commit_msg"
            
            # Push a GitHub
            if git push origin main; then
                log_success "✅ Cambios pusheados a GitHub - ArgoCD puede sincronizar"
                # Dar tiempo a ArgoCD para detectar cambios en GitHub
                log_info "⏳ Esperando que ArgoCD detecte cambios en GitHub..."
                sleep 15
            else
                log_warning "⚠️ Error pusheando a GitHub - ArgoCD podría no sincronizar correctamente"
                log_info "💡 Puedes hacer push manual después: git push origin main"
            fi
        fi
    fi
    
    # ========================================================================
    # 3. DESPLEGAR HERRAMIENTAS VIA ARGOCD
    # ========================================================================
    log_info "🚀 Desplegando herramientas GitOps..."
    kubectl apply -f argo-apps/app-of-tools-gitops.yaml
    
    log_info "⏳ Esperando que ArgoCD sincronice las herramientas..."
    sleep 10
    
    log_info "🔧 Desplegando ApplicationSet para aplicaciones custom..."
    kubectl apply -f argo-apps/appset-aplicaciones-custom.yaml
    
    # Esperar a que todas las aplicaciones estén synced
    log_info "⏳ Esperando que todas las herramientas estén synced y healthy..."
    local timeout=600
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local apps_status
        apps_status=$(kubectl get applications -n argocd -o jsonpath='{.items[*].status.sync.status}' 2>/dev/null || echo "")
        local health_status
        health_status=$(kubectl get applications -n argocd -o jsonpath='{.items[*].status.health.status}' 2>/dev/null || echo "")
        
        if [[ "$apps_status" =~ "Synced" ]] && [[ "$health_status" =~ "Healthy" ]]; then
            log_success "✅ Todas las herramientas están synced y healthy"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        
        if [[ $((elapsed % 60)) -eq 0 ]]; then
            log_info "⏳ Esperando herramientas... (${elapsed}s/${timeout}s)"
        fi
    done
    
    log_error "Timeout esperando que las herramientas estén ready"
    return 1
}

# Verificar que todo el sistema GitOps está healthy
verificar_sistema_gitops_healthy() {
    log_info "🔍 Verificando estado completo del sistema GitOps..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Verificaría estado del sistema GitOps"
        return 0
    fi
    
    # Verificar ArgoCD
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_error "ArgoCD no está disponible"
        return 1
    fi
    
    # Lista de herramientas GitOps críticas que DEBEN estar healthy
    local herramientas_criticas=(
        "argo-events"
        "argo-rollouts"
        "argo-workflows"
        "cert-manager"
        "external-secrets"
        "gitea"
        "grafana"
        "ingress-nginx"
        "jaeger"
        "kargo"
        "loki"
        "minio"
        "prometheus-stack"
    )
    
    log_info "🔍 Verificando estado de ${#herramientas_criticas[@]} herramientas GitOps críticas..."
    
    local max_intentos=10
    local intento=1
    
    while [[ $intento -le $max_intentos ]]; do
        log_info "🔄 Intento $intento/$max_intentos - Verificando herramientas GitOps..."
        
        local herramientas_no_healthy=()
        local herramientas_no_synced=()
        
        # Verificar cada herramienta crítica
        for herramienta in "${herramientas_criticas[@]}"; do
            local health_status
            local sync_status
            
            health_status=$(kubectl get application "$herramienta" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            sync_status=$(kubectl get application "$herramienta" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            
            if [[ "$health_status" != "Healthy" ]]; then
                herramientas_no_healthy+=("$herramienta($health_status)")
            fi
            
            if [[ "$sync_status" != "Synced" ]]; then
                herramientas_no_synced+=("$herramienta($sync_status)")
            fi
        done
        
        # Si todas están healthy y synced, success
        if [[ ${#herramientas_no_healthy[@]} -eq 0 ]] && [[ ${#herramientas_no_synced[@]} -eq 0 ]]; then
            log_success "✅ TODAS las herramientas GitOps están Healthy y Synced"
            log_info "🎯 ${#herramientas_criticas[@]} herramientas críticas verificadas correctamente"
            return 0
        fi
        
        # Mostrar herramientas problemáticas
        if [[ ${#herramientas_no_healthy[@]} -gt 0 ]]; then
            log_warning "⚠️ Herramientas no healthy: ${herramientas_no_healthy[*]}"
        fi
        
        if [[ ${#herramientas_no_synced[@]} -gt 0 ]]; then
            log_warning "⚠️ Herramientas no synced: ${herramientas_no_synced[*]}"
        fi
        
        # Esperar antes del siguiente intento
        if [[ $intento -lt $max_intentos ]]; then
            log_info "⏳ Esperando 30 segundos antes del siguiente intento..."
            sleep 30
        fi
        
        ((intento++))
    done
    
    # Si llegamos aquí, hay problemas
    log_error "❌ Sistema GitOps NO está completamente healthy después de $max_intentos intentos"
    log_error "❌ Herramientas con problemas detectadas - revisar con: kubectl get applications -n argocd"
    return 1
}
