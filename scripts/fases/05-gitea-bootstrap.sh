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

    # 3) Esperar a que Gitea esté disponible (servicio HTTP y endpoints listos)
    log_info "⏳ Esperando servicio de Gitea..."
    if ! kubectl -n gitea wait --for=condition=available --timeout=300s deployment -l app.kubernetes.io/name=gitea >/dev/null 2>&1; then
        log_warning "⚠️ Timeout esperando Gitea; continuamos con mejor esfuerzo"
    fi
    # Esperar endpoints del servicio
    local waited=0; local max_wait=120
    until kubectl -n gitea get endpoints gitea-http -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -qE '.'; do
        sleep 2; waited=$((waited+2)); [[ $waited -ge $max_wait ]] && break
    done

    # 4) Configurar port-forward temporal para Gitea y validar API
    log_info "🔌 Iniciando port-forward temporal a Gitea (localhost:8088)"
    kubectl -n gitea port-forward svc/gitea-http 8088:3000 >/tmp/gitea-pf.log 2>&1 &
    local pf_pid=$!
    # Esperar a que responda la API
    waited=0; max_wait=60
    until curl -fsS http://localhost:8088/api/v1/version >/dev/null 2>&1; do
        sleep 2; waited=$((waited+2)); if (( waited >= max_wait )); then
            log_warning "⚠️ Gitea API no respondió a tiempo; se continúa"
            break
        fi
    done

    local gitea_user="admin" gitea_pass="admin" repo_name="gitops-infra"
    local api="http://localhost:8088/api/v1"

    # Intento de autenticación: admin/admin; si falla probamos gitea/gitea
    log_info "📚 Asegurando repositorio en Gitea: $repo_name"
    # Comprobar si existe
    if ! curl -fsS -u "$gitea_user:$gitea_pass" "$api/repos/$gitea_user/$repo_name" >/dev/null 2>&1; then
        # Intentar con admin/admin crear repo público; fallback a gitea/gitea
        if ! curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
            -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1; then
            gitea_user="gitea"; gitea_pass="gitea"
            log_warning "⚠️ admin/admin no válido; probando gitea/gitea"
            # Rechequear existencia con nuevo usuario
            if ! curl -fsS -u "$gitea_user:$gitea_pass" "$api/repos/$gitea_user/$repo_name" >/dev/null 2>&1; then
                curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
                    -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1 || true
            fi
        fi
    else
        log_info "✅ Repositorio ya existe: $gitea_user/$repo_name"
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
    # IMPORTANTE: el Service gitea-http suele exponer el puerto 3000; incluirlo en la URL
    local internal_repo_url="http://gitea-http.gitea.svc.cluster.local:3000/$gitea_user/$repo_name.git"
    log_info "📝 Sustituyendo placeholders con: $internal_repo_url"
    find "$PROJECT_ROOT/argo-apps" -type f -name "*.yaml" -print0 | xargs -0 -I{} sed -i "s|http://gitea-service/your-user/your-repo.git|$internal_repo_url|g" {}
    find "$PROJECT_ROOT/aplicaciones" -type f -name "*.yaml" -print0 | xargs -0 -I{} sed -i "s|http://gitea-service/your-user/your-repo.git|$internal_repo_url|g" {}
    find "$PROJECT_ROOT/herramientas-gitops" -type f -name "*.yaml" -print0 | xargs -0 -I{} sed -i "s|http://gitea-service/your-user/your-repo.git|$internal_repo_url|g" {}

    # 7) Validación previa: conectividad y acceso git al repo desde el cluster
    local svc_url="http://gitea-http.gitea.svc.cluster.local:3000"
    if kubectl -n argocd run --rm -i gitea-check --image=curlimages/curl:8.10.1 --restart=Never -- \
        -sSf ${svc_url}/api/v1/version >/dev/null 2>&1; then
        log_success "✅ Conectividad HTTP a Gitea OK"
    else
        log_error "❌ Conectividad HTTP a Gitea falló; no se aplicarán Applications"
        return 1
    fi
    # Verificar git ls-remote (acceso al repo) desde el cluster
    local repo_http_url="${svc_url}/${gitea_user}/${repo_name}.git"
    if kubectl -n argocd run --rm -i gitea-git-check --image=alpine/git:latest --restart=Never -- \
        git ls-remote "$repo_http_url" >/dev/null 2>&1; then
        log_success "✅ Acceso git al repositorio OK (ls-remote)"
    else
        log_error "❌ No se pudo acceder al repositorio via git HTTP: $repo_http_url"
        return 1
    fi

    # 8) Crear la Application que apunta a herramientas-gitops/activas en el repositorio Gitea
    local app_tools="$PROJECT_ROOT/argo-apps/aplicacion-de-herramientas-gitops.yaml"
    if [[ -f "$app_tools" ]]; then
        log_info "🚀 Aplicando Application de herramientas GitOps (app-of-tools)"
        kubectl apply -f "$app_tools"
    else
        log_warning "⚠️ No se encontró $app_tools"
    fi

    # 9) Registrar clusters pre/pro en ArgoCD (si CLI disponible)
    register_additional_clusters || true

    # 10) Esperar a que todas las Applications estén en Sync/Healthy
    wait_all_apps_healthy argocd 600 || true

    # 11) Limpiar port-forward
    if ps -p "$pf_pid" >/dev/null 2>&1; then
        kill "$pf_pid" >/dev/null 2>&1 || true
    fi

    log_success "✅ Fase 5 (Bootstrap Gitea y Argo Apps) completada"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
