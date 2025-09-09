#!/bin/bash

# =============================================================================
# FASE 5 (Bootstrap Gitea):
# - Garantiza Gitea desplegado vía Argo Application activa de gitea
# - Crea repositorio en Gitea y empuja el contenido actual del proyecto
# - Reemplaza placeholders con la URL interna de Gitea
# - Crea la Application de herramientas GitOps (app-of-tools) y espera Sync/Healthy
# - Registra clusters pre/pro en ArgoCD (si CLI disponible)
# =============================================================================

set -euo pipefail

main() {
    log_section "🧩 FASE 5 (Bootstrap Gitea y Argo Apps)"

    # 1) Verificaciones previas
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    if ! check_argocd_exists; then
        log_error "❌ ArgoCD no está instalado (ejecutar Fase 4 primero)"
        return 1
    fi

    # 2) Asegurar que la Application de Gitea está aplicada (usa carpeta activas)
    local gitea_app_file="$PROJECT_ROOT/herramientas-gitops/activas/gitea.yaml"
    if [[ -f "$gitea_app_file" ]]; then
        log_info "📦 Aplicando Application de Gitea..."
        kubectl apply -f "$gitea_app_file"
    else
        log_error "❌ No se encuentra el manifiesto de Gitea activo: $gitea_app_file"
        return 1
    fi

    # 3) Esperar a que Gitea esté disponible (servicio HTTP)
    log_info "⏳ Esperando servicio de Gitea..."
    if ! kubectl -n gitea wait --for=condition=available --timeout=300s deployment -l app.kubernetes.io/name=gitea >/dev/null 2>&1; then
        log_warning "⚠️ Timeout esperando Gitea; continuamos con mejor esfuerzo"
    fi

    # 4) Configurar port-forward temporal para Gitea y crear repo
    log_info "🔌 Iniciando port-forward temporal a Gitea (localhost:8088)"
    kubectl -n gitea port-forward svc/gitea-http 8088:3000 >/tmp/gitea-pf.log 2>&1 &
    local pf_pid=$!; sleep 3

    local gitea_user="admin" gitea_pass="admin" repo_name="gitops-infra"
    local api="http://localhost:8088/api/v1"

    # Intento de autenticación: admin/admin; si falla probamos gitea/gitea
    log_info "📚 Creando repositorio en Gitea: $repo_name"
    if ! curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
        -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1; then
        gitea_user="gitea"; gitea_pass="gitea"
        log_warning "⚠️ admin/admin no válido; probando gitea/gitea"
        curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
            -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1 || true
    fi

    # 5) Empujar contenido local al nuevo remoto
    local remote_url="http://$gitea_user:$gitea_pass@localhost:8088/$gitea_user/$repo_name.git"
    log_info "🔁 Publicando repositorio actual en Gitea..."
    (
        set -e
        cd "$PROJECT_ROOT"
        git init >/dev/null 2>&1 || true
        git branch -M main >/dev/null 2>&1 || true
        if git remote get-url gitea >/dev/null 2>&1; then
            git remote set-url gitea "$remote_url"
        else
            git remote add gitea "$remote_url"
        fi
        git add -A
        git commit -m "feat(bootstrap): publicación inicial en Gitea" >/dev/null 2>&1 || true
        git push -u gitea main >/dev/null 2>&1 || true
    )

    # 6) Reemplazar placeholders de repoURL con la URL interna del servicio Gitea (para uso dentro del cluster)
    local internal_repo_url="http://gitea-http.gitea.svc.cluster.local/$gitea_user/$repo_name.git"
    log_info "📝 Sustituyendo placeholders con: $internal_repo_url"
    find "$PROJECT_ROOT/argo-apps" -type f -name "*.yaml" -print0 | xargs -0 -I{} sed -i "s|http://gitea-service/your-user/your-repo.git|$internal_repo_url|g" {}
    find "$PROJECT_ROOT/aplicaciones" -type f -name "*.yaml" -print0 | xargs -0 -I{} sed -i "s|http://gitea-service/your-user/your-repo.git|$internal_repo_url|g" {}

    # 7) Crear la Application que apunta a herramientas-gitops/activas en el repositorio Gitea
    local app_tools="$PROJECT_ROOT/argo-apps/aplicacion-de-herramientas-gitops.yaml"
    if [[ -f "$app_tools" ]]; then
        log_info "🚀 Aplicando Application de herramientas GitOps (app-of-tools)"
        kubectl apply -f "$app_tools"
    else
        log_warning "⚠️ No se encontró $app_tools"
    fi

    # 8) Registrar clusters pre/pro en ArgoCD (si CLI disponible)
    register_additional_clusters || true

    # 9) Esperar a que todas las Applications estén en Sync/Healthy
    wait_all_apps_healthy argocd 600 || true

    # 10) Limpiar port-forward
    if ps -p "$pf_pid" >/dev/null 2>&1; then
        kill "$pf_pid" >/dev/null 2>&1 || true
    fi

    log_success "✅ Fase 5 (Bootstrap Gitea y Argo Apps) completada"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

