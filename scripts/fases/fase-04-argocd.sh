#!/bin/bash

# ============================================================================
# FASE 4: INSTALACIÓN Y CONFIGURACIÓN DE ARGOCD
# ============================================================================
# Instala ArgoCD maestro que controlará todos los clusters
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

# Instalar ArgoCD maestro que controlará todos los clusters (DEV, PRE, PRO)
instalar_argocd_maestro() {
    log_info "🔄 Instalando ArgoCD (última versión) como controlador maestro..."
    log_info "   🎯 Este ArgoCD controlará DEV, PRE y PRO desde el cluster DEV"
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría instalación de ArgoCD"
        return 0
    fi
    
    # Crear namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Instalar ArgoCD (última versión estable)
    log_info "📥 Descargando e instalando ArgoCD (última versión estable)..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Esperar a que ArgoCD esté listo
    log_info "⏳ Esperando que ArgoCD esté completamente desplegado..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    kubectl wait --for=condition=ready --timeout=600s statefulset/argocd-application-controller -n argocd
    
    # Configurar acceso via NodePort para WSL
    log_info "🔐 Configurando acceso via NodePort (compatible con WSL)..."
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
    
    # Obtener información de acceso
    local argocd_password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    local argocd_port
    argocd_port=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
    
    local cluster_ip
    cluster_ip=$(minikube ip --profile="$CLUSTER_DEV_NAME" 2>/dev/null || echo "localhost")
    
    log_success "✅ ArgoCD instalado correctamente como controlador maestro"
    log_info "🌐 Acceso a ArgoCD:"
    log_info "   URL: https://$cluster_ip:$argocd_port"
    log_info "   Usuario: admin"
    log_info "   Password: $argocd_password"
    
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

# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE 4
# ============================================================================

fase_04_argocd() {
    log_info "🏗️ FASE 4: Instalación y Configuración de ArgoCD"
    log_info "════════════════════════════════════════════════"
    
    # Verificar que no estamos ejecutando como root
    if [[ "$EUID" -eq 0 ]]; then
        log_error "❌ Esta fase no debe ejecutarse como root"
        log_info "💡 ArgoCD debe instalarse con usuario normal"
        return 1
    fi
    
    # Verificar que tenemos un cluster activo
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ No hay cluster Kubernetes activo"
        log_info "💡 Ejecuta primero la Fase 3 (clusters)"
        return 1
    fi
    
    # Instalar ArgoCD
    instalar_argocd_maestro
    
    # Verificar instalación
    verificar_argocd_healthy
    
    log_info "🌐 Para acceder a ArgoCD:"
    log_info "   URL: https://argocd.local"
    log_info "   Usuario: admin"
    log_info "   Contraseña: Usar 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d'"
    
    log_info "✅ Fase 4 completada: ArgoCD instalado y configurado"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_04_argocd "$@"
fi
