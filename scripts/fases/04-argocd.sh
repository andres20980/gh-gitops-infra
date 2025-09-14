#!/bin/bash

# ============================================================================
# FASE 4: INSTALACIÓN ARGOCD
# ============================================================================
# Instalación robusta de ArgoCD con verificación de contexto y timeouts
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail

apply_argocd_bootstrap_apps() {
    # Apply the app-of-apps and appsset from the repo path argo-apps/
    repo_base="${PWD}"
    apps_dir="$repo_base/argo-apps"
    if [[ ! -d "$apps_dir" ]]; then
        log_error "Directorio $apps_dir no existe"
        return 1
    fi

    # Antes de aplicar, comprobar que Gitea (repo) está accesible desde el cluster.
    # Las aplicaciones apuntan por defecto a: gitea-http-stable.gitea.svc.cluster.local:3000
    GITEA_HOST="http://gitea-http-stable.gitea.svc.cluster.local:3000/"

    log_info "Comprobando disponibilidad de Gitea en $GITEA_HOST desde argocd-repo-server..."
    if kubectl -n "$ARGOCD_NAMESPACE" exec deploy/argocd-repo-server -- sh -c "curl -sS --max-time 3 -I $GITEA_HOST" >/dev/null 2>&1; then
        log_info "Gitea accesible desde el cluster — aplicando apps de bootstrap"
    else
      log_info "Gitea NO accesible aún desde el cluster. Se omite aplicar App-of-Apps/AppSet.\n  Instala/expón las dependencias externas (p.ej. Gitea) y vuelve a ejecutar esta fase." 
        return 0
    fi

    for f in aplicacion-de-herramientas-gitops.yaml conjunto-aplicaciones-personalizadas.yaml; do
        file_path="$apps_dir/$f"
        if [[ ! -f "$file_path" ]]; then
            log_info "⚠️  Archivo $file_path no encontrado, saltando"
            continue
        fi

        log_info "Aplicando $f..."
        kubectl apply -f "$file_path" -n "$ARGOCD_NAMESPACE" || {
            log_error "kubectl apply falló para $f"
            return 1
        }
    done

    # Trigger a refresh via annotation to help ArgoCD detect new apps quickly
    kubectl -n "$ARGOCD_NAMESPACE" get applications --ignore-not-found -o name | xargs -r -n1 kubectl -n "$ARGOCD_NAMESPACE" annotate --overwrite {} argocd.argoproj.io/refresh=hard >/dev/null 2>&1 || true
    return 0
}

ensure_argocd_ui() {
    # Ensure argocd-server is reachable: prefer existing NodePort; else start port-forward
    svc=$(kubectl -n "$ARGOCD_NAMESPACE" get svc argocd-server --ignore-not-found -o jsonpath='{.spec.type}' 2>/dev/null || true)
    if [[ "$svc" == "NodePort" ]]; then
        log_success "ArgoCD UI expuesta por Service NodePort"
        return 0
    fi

    # If not NodePort, create a background port-forward to localhost:8080 -> service:80
    if pgrep -f "kubectl -n $ARGOCD_NAMESPACE port-forward svc/argocd-server 8080:80" >/dev/null 2>&1; then
        log_info "Port-forward de ArgoCD ya está activo"
        return 0
    fi

    log_info "Iniciando port-forward para ArgoCD en background (localhost:8080)..."
    kubectl -n "$ARGOCD_NAMESPACE" port-forward svc/argocd-server 8080:80 >/tmp/argocd-port-forward.log 2>&1 &
    PF_PID=$!
    echo "$PF_PID" >/tmp/argocd-port-forward.pid
    sleep 1
    if kill -0 "$PF_PID" >/dev/null 2>&1; then
        log_success "Port-forward iniciado (pid=$PF_PID). Abre http://localhost:8080"
    else
        log_error "No se pudo iniciar port-forward de ArgoCD; revisa /tmp/argocd-port-forward.log"
        return 1
    fi
}


# ============================================================================
# FASE 4: ARGOCD
# ============================================================================

main() {
    log_section "🚀 FASE 4: Instalación ArgoCD"
    
    # 1. Verificar cluster disponible
    log_info "🔍 Verificando cluster..."
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    
    # 2. Instalar ArgoCD
    log_info "📦 Configurando ArgoCD..."
    if ! check_argocd_exists; then
        install_argocd
        setup_argocd_service
        wait_argocd_ready
        setup_argocd_cli
    else
        log_success "✅ ArgoCD ya está instalado y funcionando"
    fi
    
    # 3. Mostrar información de acceso
    show_argocd_access
    show_argocd_cli_status

    # 4. Auto-gestionar ArgoCD: aplicar App-of-Apps y AppSet para herramientas
    log_info "🔁 Aplicando App-of-Apps y AppSet de argo-apps..."
    apply_argocd_bootstrap_apps || log_error "No se pudieron aplicar las aplicaciones ArgoCD de bootstrap"

    # 5. Asegurar acceso UI (NodePort o port-forward)
    ensure_argocd_ui
    
    log_success "✅ Fase 4 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

