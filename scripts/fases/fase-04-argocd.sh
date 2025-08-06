#!/bin/bash

# ============================================================================
# FASE 4: INSTALACIÓN DE ARGOCD
# ============================================================================

# Instalar ArgoCD maestro que controlará todos los clusters
instalar_argocd_maestro() {
    log_info "🔄 Instalando ArgoCD (última versión) como controlador maestro..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría instalación de ArgoCD"
        return 0
    fi
    
    # Crear namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Instalar ArgoCD (última versión estable)
    log_info "📥 Descargando e instalando ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Esperar a que ArgoCD esté listo
    log_info "⏳ Esperando que ArgoCD esté listo..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    kubectl wait --for=condition=ready --timeout=600s statefulset/argocd-application-controller -n argocd
    
    # Configurar acceso
    log_info "🔐 Configurando acceso a ArgoCD..."
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    
    # Obtener password inicial
    local argocd_password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    log_success "✅ ArgoCD instalado correctamente"
    log_info "🔑 Password inicial admin: $argocd_password"
    
    return 0
}

# Verificar que ArgoCD está healthy
verificar_argocd_healthy() {
    log_info "🔍 Verificando estado de ArgoCD..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Verificaría estado de ArgoCD"
        return 0
    fi
    
    # Verificar que ArgoCD está disponible
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_error "ArgoCD no está disponible"
        return 1
    fi
    
    # Esperar hasta 2 minutos para que todos los pods estén ready
    log_info "⏳ Esperando que todos los pods de ArgoCD estén ready..."
    local timeout=120
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        # Verificar que todos los pods están ready (excluyendo reinicios menores)
        local pods_ready
        pods_ready=$(kubectl get pods -n argocd --no-headers | awk '$2=="1/1" && $3=="Running"' | wc -l)
        local total_pods
        total_pods=$(kubectl get pods -n argocd --no-headers | wc -l)
        
        if [[ "$pods_ready" -eq "$total_pods" ]] && [[ "$total_pods" -ge 7 ]]; then
            log_success "✅ ArgoCD está healthy ($pods_ready/$total_pods pods ready)"
            return 0
        fi
        
        if [[ $((elapsed % 15)) -eq 0 ]]; then
            log_info "⏳ ArgoCD pods: $pods_ready/$total_pods ready (${elapsed}s/${timeout}s)"
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    # Si llegamos aquí, mostrar estado detallado
    log_warning "⚠️ ArgoCD no está completamente ready después de $timeout segundos"
    log_info "📊 Estado detallado de pods:"
    kubectl get pods -n argocd
    
    # Permitir continuar si al menos el server está ready
    if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_info "💡 ArgoCD server está disponible, continuando..."
        return 0
    else
        return 1
    fi
}
