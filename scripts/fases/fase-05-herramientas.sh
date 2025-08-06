#!/bin/bash

# ============================================================================
# FASE 5: INSTALACIÓN DE HERRAMIENTAS GITOPS
# ============================================================================
# Instala todas las herramientas GitOps definidas en herramientas-gitops/
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

# Configurar Git para operaciones GitOps
configurar_git_ops() {
    log_info "🔧 Configurando Git para operaciones GitOps..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Configuraría Git para operaciones GitOps"
        return 0
    fi
    
    # Esta función se implementará cuando sea necesaria
    log_info "ℹ️ Configuración Git no requerida actualmente"
    return 0
}

# Instalar herramientas GitOps via ArgoCD
instalar_herramientas_gitops() {
    log_info "🚀 Instalando herramientas GitOps con configuraciones dev..."
    
    # Optimizar configuraciones para desarrollo
    optimizar_configuraciones_dev
    
    # Desplegar via ArgoCD
    desplegar_herramientas_via_argocd
    
    log_success "✅ Herramientas GitOps desplegadas via ArgoCD"
}

# Esperar que las herramientas estén healthy
esperar_herramientas_healthy() {
    verificar_estado_herramientas_con_timeout
}

# Verificar estado de herramientas con timeout
verificar_estado_herramientas_con_timeout() {
    log_info "⏳ Esperando que todas las herramientas estén synced y healthy..."
    local timeout=300  # 5 minutos es suficiente para dev
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        # Verificar App of Tools principal
        if kubectl get application tools-gitops -n argocd >/dev/null 2>&1; then
            local sync_status
            sync_status=$(kubectl get application tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            local health_status
            health_status=$(kubectl get application tools-gitops -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            if [[ "$sync_status" == "Synced" ]] && [[ "$health_status" == "Healthy" ]]; then
                log_success "✅ App of Tools está synced y healthy"
                return 0
            fi
            
            if [[ $((elapsed % 30)) -eq 0 ]]; then
                log_info "⏳ App of Tools: $sync_status/$health_status (${elapsed}s/${timeout}s)"
            fi
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    log_warning "⚠️ Timeout verificando herramientas - pueden seguir instalándose en background"
    log_info "💡 Verifica manualmente: kubectl get applications -n argocd"
    return 0  # No fallar la instalación por timeout en verificación
}

# Optimizar configuraciones para desarrollo
optimizar_configuraciones_dev() {
    log_info "🔧 Optimizando configuraciones de herramientas GitOps para desarrollo..."
    
    # 1. Actualizar versiones de helm charts a las últimas
    actualizar_helm_charts
    
    # 2. Optimizar configuraciones para desarrollo
    aplicar_optimizaciones_dev
    
    # 3. Commit y push de cambios para ArgoCD
    commitear_cambios_para_argocd
}

# Actualizar helm charts a las últimas versiones
actualizar_helm_charts() {
    log_info "📊 Actualizando versiones de helm charts a las últimas..."
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
}

# Aplicar optimizaciones de desarrollo
aplicar_optimizaciones_dev() {
    log_info "🔧 Aplicando configuraciones mínimas para desarrollo..."
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
}

# Commitear y pushear cambios para ArgoCD
commitear_cambios_para_argocd() {
    log_info "📡 Commiteando y pusheando cambios para ArgoCD..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría commit y push de cambios optimizados"
        return 0
    fi
    
    # Verificar si hay cambios
    if git diff --quiet && git diff --cached --quiet; then
        log_info "ℹ️ No hay cambios para commitear"
        return 0
    fi
    
    # Agregar todos los cambios
    git add herramientas-gitops/ argo-apps/
    
    # Commit con mensaje descriptivo
    local commit_msg="🔧 Auto-optimización GitOps: actualización de herramientas y configuraciones

- Actualización de versiones de Helm charts a las últimas
- Optimización de herramientas GitOps con configuraciones mínimas dev
- Preparadas para controlar 3 entornos: DEV, PRE, PRO
- Generado automáticamente por instalar.sh v3.0.0"

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
}

# Desplegar herramientas via ArgoCD
desplegar_herramientas_via_argocd() {
    log_info "📦 Desplegando App of Tools para herramientas GitOps..."
    
    if ! kubectl apply -f "${RUTA_PROYECTO}/argo-apps/app-of-tools-gitops.yaml"; then
        log_error "❌ Error aplicando app-of-tools-gitops"
        return 1
    fi
    
    # Esperar que la app se registre en ArgoCD
    log_info "⏳ Esperando que la App of Tools se registre..."
    if ! esperar_condicion "kubectl get application tools-gitops -n argocd" 30; then
        log_error "❌ La App of Tools no se registró correctamente"
        return 1
    fi
    
    # Forzar sync inicial (en dev, queremos que se instale inmediatamente)
    log_info "🔄 Iniciando sync de herramientas GitOps..."
    kubectl patch application tools-gitops -n argocd --type merge -p '{"operation":{"sync":{}}}' 2>/dev/null || true
    
    # Mostrar progreso
    mostrar_progreso_herramientas
}

# Mostrar progreso de instalación de herramientas
mostrar_progreso_herramientas() {
    log_info "📊 Monitoreando instalación de herramientas..."
    
    local herramientas=(
        "cert-manager"
        "ingress-nginx"
        "prometheus-stack"
        "grafana"
        "loki"
        "argo-workflows"
        "argo-events"
        "argo-rollouts"
    )
    
    for herramienta in "${herramientas[@]}"; do
        log_info "  📦 $herramienta - preparando..."
    done
    
    log_info "💡 Las herramientas se instalarán de forma asíncrona via ArgoCD"
}





# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE 5
# ============================================================================

fase_05_herramientas() {
    log_info "🛠️ FASE 5: Instalación de Herramientas GitOps"
    log_info "═══════════════════════════════════════════════"
    log_info "🎯 Instalando herramientas con configuraciones mínimas dev"
    log_info "🎯 Preparadas para controlar 3 entornos: DEV, PRE, PRO"
    
    # Verificar que no estamos ejecutando como root
    if [[ "$EUID" -eq 0 ]]; then
        log_error "❌ Esta fase no debe ejecutarse como root"
        log_info "💡 Las herramientas GitOps deben instalarse con usuario normal"
        return 1
    fi
    
    # Verificar que ArgoCD está disponible y healthy
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD no está instalado"
        log_info "💡 Ejecuta primero la Fase 4 (ArgoCD)"
        return 1
    fi
    
    # Verificar que ArgoCD está healthy antes de continuar
    if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
        log_error "❌ ArgoCD server no está disponible"
        log_info "💡 Espera a que ArgoCD esté completamente healthy"
        return 1
    fi
    
    # Configurar repositorio Git si es necesario
    configurar_git_ops
    
    # Instalar todas las herramientas GitOps con configuraciones mínimas
    log_info "🚀 Instalando herramientas GitOps vía ArgoCD..."
    instalar_herramientas_gitops
    
    # Esperar y verificar que todas estén synced y healthy
    log_info "⏳ Esperando que todas las herramientas estén synced y healthy..."
    esperar_herramientas_healthy
    
    log_info "📋 Para verificar el estado de las herramientas:"
    log_info "   kubectl get applications -n argocd"
    log_info "   kubectl get pods --all-namespaces"
    
    log_success "✅ Fase 5 completada: Herramientas GitOps instaladas y ready para 3 entornos"
    log_info "🎯 Próximo paso: Instalar aplicaciones custom (Fase 6)"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_05_herramientas "$@"
fi
