#!/bin/bash

# ============================================================================
# HELPER: GESTIÓN DE ARGOCD
# ============================================================================
# Funciones especializadas para instalación y configuración de ArgoCD
# Principios: Verificación de contexto, Timeouts inteligentes, Robustez
# ============================================================================

set -euo pipefail

# ============================================================================
# VERIFICACIÓN DE CONTEXTO Y CONECTIVIDAD
# ============================================================================

# Verifica que estamos en el contexto correcto de kubectl
verificar_contexto_kubectl() {
    local contexto_esperado="${1:-gitops-dev}"
    local contexto_actual="$(kubectl config current-context 2>/dev/null || echo "none")"
    
    if [[ "$contexto_actual" != "$contexto_esperado" ]]; then
        log_warning "⚠️ Contexto incorrecto: $contexto_actual (esperado: $contexto_esperado)"
        log_info "🔧 Cambiando al contexto correcto..."
        
        if kubectl config use-context "$contexto_esperado" >/dev/null 2>&1; then
            log_success "✅ Contexto cambiado a: $contexto_esperado"
        else
            log_error "❌ Error: No se pudo cambiar al contexto $contexto_esperado"
            return 1
        fi
    else
        log_info "✅ Contexto correcto: $contexto_actual"
    fi
    
    return 0
}

# Verifica conectividad rápida al cluster
verificar_conectividad_cluster() {
    if ! kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
        log_error "❌ No hay conectividad al cluster Kubernetes"
        return 1
    fi
    
    if ! kubectl get nodes --request-timeout=10s >/dev/null 2>&1; then
        log_error "❌ No se pueden obtener nodos del cluster"
        return 1
    fi
    
    return 0
}

# Verifica que estamos en el cluster correcto
verificar_cluster_correcto() {
    local cluster_esperado="${1:-gitops-dev}"
    local nodo_cluster="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "unknown")"
    
    if [[ "$nodo_cluster" != "$cluster_esperado" ]]; then
        log_warning "⚠️ Cluster incorrecto: $nodo_cluster (esperado: $cluster_esperado)"
        return 1
    fi
    
    log_info "✅ Cluster correcto: $nodo_cluster"
    return 0
}

# ============================================================================
# INSTALACIÓN DE ARGOCD
# ============================================================================

# Instala ArgoCD con verificaciones robustas
instalar_argocd_robusto() {
    log_info "🔄 Instalando ArgoCD (versión estable) como controlador maestro..."
    
    # Crear namespace de forma idempotente
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    # Instalar ArgoCD con timeout
    log_info "📥 Descargando e instalando manifiestos de ArgoCD..."
    if ! timeout 60s kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml; then
        log_error "❌ Error descargando manifiestos de ArgoCD"
        return 1
    fi
    
    log_success "✅ Manifiestos de ArgoCD aplicados correctamente"
    return 0
}

# Configura acceso NodePort para ArgoCD
configurar_acceso_argocd() {
    log_info "🔐 Configurando acceso via NodePort (compatible con WSL)..."
    
    # Configurar NodePort con timeout
    if ! timeout 10s kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}' >/dev/null 2>&1; then
        log_warning "⚠️ Error configurando NodePort (puede estar ya configurado)"
    else
        log_success "✅ NodePort configurado correctamente"
    fi
    
    return 0
}

# ============================================================================
# VERIFICACIÓN Y ESPERA INTELIGENTE
# ============================================================================

# Espera inteligente con timeouts cortos y verificación progresiva
esperar_argocd_listo() {
    local timeout_max="${1:-180}"  # 3 minutos máximo
    local intervalo="${2:-5}"      # Verificar cada 5 segundos
    
    log_info "⏳ Esperando que ArgoCD esté completamente desplegado (timeout: ${timeout_max}s)..."
    
    local elapsed=0
    while [[ $elapsed -lt $timeout_max ]]; do
        # Verificar deployments (READY = x/x donde x=x)
        local deployments_ready=0
        local deployments_total=0
        
        if deployments_info=$(kubectl get deployments -n argocd --no-headers 2>/dev/null); then
            deployments_total=$(echo "$deployments_info" | wc -l)
            # Verificar deployments que estén ready: formato "1/1" en columna READY
            deployments_ready=$(echo "$deployments_info" | awk '$2 == "1/1" {count++} END {print count+0}')
        fi
        
        # Verificar statefulsets (READY = x/x donde x=x)
        local statefulsets_ready=0
        local statefulsets_total=0
        
        if statefulsets_info=$(kubectl get statefulsets -n argocd --no-headers 2>/dev/null); then
            statefulsets_total=$(echo "$statefulsets_info" | wc -l)
            # Verificar statefulsets que estén ready: formato "1/1" en columna READY
            statefulsets_ready=$(echo "$statefulsets_info" | awk '$2 == "1/1" {count++} END {print count+0}')
        fi
        
        # Calcular progreso total
        local total_recursos=$((deployments_total + statefulsets_total))
        local recursos_listos=$((deployments_ready + statefulsets_ready))
        
        # Mostrar progreso cada 15 segundos
        if [[ $((elapsed % 15)) -eq 0 ]]; then
            log_info "📊 ArgoCD: $recursos_listos/$total_recursos recursos listos (${elapsed}s/${timeout_max}s)"
        fi
        
        # Verificar si todo está listo
        if [[ $recursos_listos -eq $total_recursos ]] && [[ $total_recursos -ge 6 ]]; then
            log_success "✅ ArgoCD completamente desplegado ($recursos_listos/$total_recursos recursos)"
            return 0
        fi
        
        sleep "$intervalo"
        elapsed=$((elapsed + intervalo))
    done
    
    # Timeout alcanzado - mostrar estado detallado
    log_warning "⚠️ Timeout alcanzado (${timeout_max}s). Estado actual:"
    kubectl get pods -n argocd 2>/dev/null || log_error "No se pueden obtener pods"
    
    # Permitir continuar si al menos el server está corriendo
    if kubectl get pod -l app.kubernetes.io/name=argocd-server -n argocd --no-headers 2>/dev/null | grep -q "Running"; then
        log_info "💡 ArgoCD server está ejecutándose, continuando..."
        return 0
    fi
    
    return 1
}

# ============================================================================
# INFORMACIÓN DE ACCESO
# ============================================================================

# Obtiene información de acceso a ArgoCD de forma robusta
obtener_info_acceso() {
    local cluster_name="${1:-gitops-dev}"
    
    # Obtener IP del cluster
    local cluster_ip="localhost"
    if command -v minikube >/dev/null 2>&1; then
        cluster_ip="$(minikube ip -p "$cluster_name" 2>/dev/null || echo "localhost")"
    fi
    
    # Obtener puerto NodePort
    local argocd_port_https="443"
    local argocd_port_http="80"
    
    if port_info=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null); then
        [[ -n "$port_info" ]] && argocd_port_https="$port_info"
    fi
    
    if port_info=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null); then
        [[ -n "$port_info" ]] && argocd_port_http="$port_info"
    fi
    
    # Intentar obtener contraseña (puede fallar si el secret no existe aún)
    local argocd_password="<usar kubectl para obtener>"
    if password_data=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null); then
        if [[ -n "$password_data" ]]; then
            argocd_password="$(echo "$password_data" | base64 -d 2>/dev/null || echo "<error decodificando>")"
        fi
    fi
    
    # Mostrar información de acceso
    log_info "🌐 Información de acceso a ArgoCD:"
    log_info "   📍 URL HTTPS: https://$cluster_ip:$argocd_port_https"
    log_info "   📍 URL HTTP:  http://$cluster_ip:$argocd_port_http"
    log_info "   👤 Usuario: admin"
    log_info "   🔐 Password: $argocd_password"
    
    if [[ "$argocd_password" == "<usar kubectl para obtener>" ]]; then
        log_info "   💡 Para obtener la contraseña:"
        log_info "      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    fi
    
    return 0
}
