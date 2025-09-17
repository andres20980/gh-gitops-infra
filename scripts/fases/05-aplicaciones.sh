#!/bin/bash

# ============================================================================
# FASE 05: GITEA Y DESPLIEGUE DE APLICACIONES
# ============================================================================
# Despliega Gitea via ArgoCD, sincroniza el repositorio gitops-infra y aplica
# las aplicaciones demo usando ArgoCD
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


# ============================================================================
# CONFIGURACIÓN DE APLICACIONES
# ============================================================================

# Usar la raíz del proyecto detectada por el sistema DRY
readonly APLICACIONES_DIR="${PROJECT_ROOT}/aplicaciones"
readonly GITEA_APP_FILE="${PROJECT_ROOT}/herramientas-gitops/activas/gitea.yaml"
readonly GITEA_NAMESPACE="gitea"
readonly GITEA_APP_NAME="gitea"

: "${GITEA_ADMIN_USER:=admin}"
: "${GITEA_ADMIN_PASS:=admin1234}"
: "${GITEA_LOCAL_PORT:=3300}"

ensure_gitea_application() {
    if [[ ! -f "$GITEA_APP_FILE" ]]; then
        log_error "Manifiesto de Application para Gitea no encontrado: $GITEA_APP_FILE"
        return 1
    fi

    log_info "📦 Asegurando Application ArgoCD para Gitea"
    kubectl apply -f "$GITEA_APP_FILE" || {
        log_error "No se pudo aplicar $GITEA_APP_FILE"
        return 1
    }
}

wait_for_gitea_application() {
    log_info "⏳ Esperando ArgoCD Application '$GITEA_APP_NAME' (Synced+Healthy)"
    if ! wait_argocd_application "$GITEA_APP_NAME" 420; then
        log_error "La aplicación de Gitea no alcanzó estado Synced+Healthy"
        return 1
    fi
}

discover_gitea_service() {
    local svc
    svc=$(kubectl -n "$GITEA_NAMESPACE" get svc -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    if [[ -z "$svc" ]]; then
        if kubectl -n "$GITEA_NAMESPACE" get svc gitea-http >/dev/null 2>&1; then
            svc="gitea-http"
        fi
    fi
    echo "$svc"
}

discover_gitea_service_port() {
    local svc_name="$1"
    kubectl -n "$GITEA_NAMESPACE" get svc "$svc_name" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "3000"
}

start_gitea_port_forward() {
    local svc_name="$1" svc_port="$2"
    log_info "🔌 Creando port-forward temporal a Gitea (localhost:${GITEA_LOCAL_PORT} → ${svc_name}:${svc_port})"
    kubectl -n "$GITEA_NAMESPACE" port-forward svc/"$svc_name" "${GITEA_LOCAL_PORT}:${svc_port}" >/tmp/gitea-port-forward.log 2>&1 &
    GITEA_PF_PID=$!
    sleep 2
    if ! kill -0 "$GITEA_PF_PID" >/dev/null 2>&1; then
        log_error "No se pudo iniciar port-forward a Gitea (ver /tmp/gitea-port-forward.log)"
        return 1
    fi
    return 0
}

stop_gitea_port_forward() {
    if [[ -n "${GITEA_PF_PID:-}" ]] && kill -0 "$GITEA_PF_PID" >/dev/null 2>&1; then
        kill "$GITEA_PF_PID" >/dev/null 2>&1 || true
    fi
    unset GITEA_PF_PID
}

wait_gitea_http_ready() {
    local tries=0 max_tries=60 url="http://127.0.0.1:${GITEA_LOCAL_PORT}/api/v1/version"
    while (( tries < max_tries )); do
        if curl -sS --max-time 3 "$url" >/dev/null 2>&1; then
            log_success "✅ Gitea accesible via port-forward"
            return 0
        fi
        sleep 1; tries=$((tries+1))
    done
    log_error "Gitea no respondió en localhost:${GITEA_LOCAL_PORT}"
    return 1
}

delete_gitea_repo_if_exists() {
    local url="http://127.0.0.1:${GITEA_LOCAL_PORT}/api/v1/repos/${GITEA_ADMIN_USER}/gitops-infra"
    local status
    status=$(curl -sS -o /tmp/gitea-delete-response.json -w "%{http_code}" -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" -X DELETE "$url" 2>/dev/null || echo "000")
    if [[ "$status" == "204" || "$status" == "404" ]]; then
        log_info "🧹 Repo gitops-infra eliminado (status $status)"
        rm -f /tmp/gitea-delete-response.json || true
        return 0
    fi
    log_error "No se pudo borrar repo gitops-infra (HTTP $status). Revisa /tmp/gitea-delete-response.json"
    return 1
}

create_gitea_repo() {
    local url="http://127.0.0.1:${GITEA_LOCAL_PORT}/api/v1/user/repos"
    local payload='{"name":"gitops-infra","description":"Infra repo for GitOps","private":false}'
    local status
    status=$(curl -sS -o /tmp/gitea-create-response.json -w "%{http_code}" -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" -H 'Content-Type: application/json' -d "$payload" "$url" 2>/dev/null || echo "000")
    if [[ "$status" == "201" || "$status" == "422" ]]; then
        # 422 => repo ya existe (posible carrera). Se considera OK.
        log_success "✅ Repositorio gitops-infra disponible en Gitea (HTTP $status)"
        rm -f /tmp/gitea-create-response.json || true
        return 0
    fi
    log_error "No se pudo crear repo gitops-infra (HTTP $status). Ver /tmp/gitea-create-response.json"
    return 1
}

push_repo_to_gitea() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_error "El directorio actual no es un repositorio git válido"
        return 1
    fi

    local push_url="http://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}@127.0.0.1:${GITEA_LOCAL_PORT}/${GITEA_ADMIN_USER}/gitops-infra.git"
    log_info "⤴️ Subiendo contenido del repo actual a Gitea"
    if git push --mirror "$push_url" >/dev/null 2>&1; then
        log_success "✅ Push --mirror completado"
        return 0
    fi

    log_warning "Falló git push --mirror; intentando push alternativo con clon bare"
    local tmpdir
    tmpdir=$(mktemp -d)
    if git clone --bare . "$tmpdir/repo.git" >/dev/null 2>&1; then
        (cd "$tmpdir/repo.git" && git push --mirror "$push_url" >/dev/null 2>&1) || {
            log_error "No se pudo completar el push a Gitea"
            rm -rf "$tmpdir" || true
            return 1
        }
    else
        log_error "No se pudo crear clon bare para push alternativo"
        rm -rf "$tmpdir" || true
        return 1
    fi
    rm -rf "$tmpdir" || true
    log_success "✅ Push alternativo completado"
    return 0
}

seed_gitea_repository() {
    local svc service_port
    svc=$(discover_gitea_service)
    if [[ -z "$svc" ]]; then
        log_error "No se pudo detectar el Service de Gitea"
        return 1
    fi
    service_port=$(discover_gitea_service_port "$svc")

    if ! start_gitea_port_forward "$svc" "$service_port"; then
        return 1
    fi

    local previous_exit_trap
    previous_exit_trap=$(trap -p EXIT || true)
    trap 'stop_gitea_port_forward' EXIT

    wait_gitea_http_ready || return 1
    delete_gitea_repo_if_exists || return 1
    create_gitea_repo || return 1
    push_repo_to_gitea || return 1

    stop_gitea_port_forward

    if [[ -n "$previous_exit_trap" ]]; then
        eval "$previous_exit_trap"
    else
        trap - EXIT
    fi
    return 0
}

wait_gitea_incluster_ready() {
    local tries=0
    local max_tries=24
    local -a probe_urls=()

    # If user provided a preferred URL, try it first
    if [[ -n "${GITEA_PROBE_URL:-}" ]]; then
        probe_urls+=("${GITEA_PROBE_URL}")
    fi

    # Discover services labeled as Gitea and collect their HTTP endpoints
    local line svc_name svc_port
    while IFS=' ' read -r svc_name svc_port; do
        [[ -z "$svc_name" ]] && continue
        svc_port=${svc_port:-3000}
        probe_urls+=("http://${svc_name}.${GITEA_NAMESPACE}.svc.cluster.local:${svc_port}/")
        probe_urls+=("http://${svc_name}.${GITEA_NAMESPACE}.svc:${svc_port}/")
    done < <(kubectl -n "$GITEA_NAMESPACE" get svc -l app.kubernetes.io/name=gitea -o jsonpath='{range .items[*]}{.metadata.name} {.spec.ports[?(@.name=="http")].port}{"\n"}{end}' 2>/dev/null)

    # Fallback URLs if discovery yielded nothing
    if [[ ${#probe_urls[@]} -eq 0 ]]; then
        probe_urls+=(
            "http://gitea-http.${GITEA_NAMESPACE}.svc.cluster.local:3000/"
            "http://gitea.${GITEA_NAMESPACE}.svc.cluster.local:3000/"
        )
    fi

    local url pod_name
    while (( tries < max_tries )); do
        for url in "${probe_urls[@]}"; do
            [[ -z "$url" ]] && continue
            pod_name="gitea-access-$(date +%s)-$RANDOM"
            if kubectl -n "$GITEA_NAMESPACE" run "$pod_name" --image=curlimages/curl:8.7.1 --restart=Never --rm --attach --command -- sh -c "curl -sS --max-time 5 -I '$url'" >/dev/null 2>&1; then
                log_success "✅ Gitea accesible desde el cluster en $url"
                export GITEA_PROBE_URL="$url"
                return 0
            fi
        done

        log_info "⏳ Gitea aún no accesible desde dentro del cluster. Reintentando en 5s..."
        sleep 5
        tries=$((tries+1))
    done

    log_error "❌ Gitea no es accesible desde el cluster tras ${max_tries} intentos"
    return 1
}

registrar_repositorio_en_argocd() {
    local base_url="${GITEA_PROBE_URL:-http://gitea-http.gitea.svc.cluster.local:3000/}"
    local repo_url="${base_url%/}/admin/gitops-infra.git"

    if ! setup_argocd_cli >/dev/null 2>&1; then
        log_warning "⚠️ No se pudo preparar la CLI de ArgoCD para registrar el repositorio"
        return 1
    fi

    log_info "🔗 Registrando repositorio GitOps en ArgoCD: ${repo_url}"
    if argocd repo add --name gitops-infra --type git --insecure-ignore-host-key \
        --username "${GITEA_ADMIN_USER}" --password "${GITEA_ADMIN_PASS}" \
        "$repo_url" --upsert >/dev/null 2>&1; then
        log_success "✅ Repositorio gitops-infra registrado/actualizado en ArgoCD"
        return 0
    fi

    log_error "❌ No se pudo registrar el repositorio gitops-infra en ArgoCD"
    return 1
}

limpiar_recursos_argocd() {
    log_info "🧹 Eliminando aplicaciones ArgoCD previas (excepto gitea)"
    local apps
    apps=$(kubectl -n "$ARGOCD_NAMESPACE" get applications -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    if [[ -n "$apps" ]]; then
        while read -r app; do
            [[ -z "$app" ]] && continue
            [[ "$app" == "gitea" ]] && continue
            log_info "   - Eliminando application: $app"
            kubectl -n "$ARGOCD_NAMESPACE" delete application "$app" --ignore-not-found --wait=true >/dev/null 2>&1 || true
        done <<<"$apps"
    fi

    log_info "🧹 Eliminando ApplicationSets previos"
    local appsets
    appsets=$(kubectl -n "$ARGOCD_NAMESPACE" get applicationsets.argoproj.io -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
    if [[ -n "$appsets" ]]; then
        while read -r aset; do
            [[ -z "$aset" ]] && continue
            log_info "   - Eliminando applicationset: $aset"
            kubectl -n "$ARGOCD_NAMESPACE" delete applicationset "$aset" --ignore-not-found --wait=true >/dev/null 2>&1 || true
        done <<<"$appsets"
    fi
}

# ============================================================================
# FASE 05: APLICACIONES
# ============================================================================

main() {
    log_section "📱 FASE 5: Gitea y Despliegue de Aplicaciones"

    # 1. Verificar prerrequisitos
    log_info "🔍 Verificando prerrequisitos..."
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    
    if ! check_argocd_exists; then
        log_error "❌ ArgoCD no está instalado"
        return 1
    fi
    
    # 2. Desplegar Gitea via ArgoCD y preparar repositorio
    ensure_gitea_application || return 1
    wait_for_gitea_application || return 1
    limpiar_recursos_argocd || true
    seed_gitea_repository || return 1
    registrar_repositorio_en_argocd || return 1
    wait_gitea_incluster_ready || return 1

    # 3. Aplicar App-of-Apps / ApplicationSet de herramientas ahora que el repo existe
    log_info "🔁 Aplicando App-of-Apps y ApplicationSet de herramientas"
    local bootstrap_attempt=0
    local bootstrap_max=12
    local bootstrap_ok=false
    while (( bootstrap_attempt < bootstrap_max )); do
        bootstrap_attempt=$((bootstrap_attempt+1))
        log_info "🔁 Intento ${bootstrap_attempt}/${bootstrap_max} de aplicar bootstrap"
        if apply_argocd_bootstrap_apps; then
            log_success "✅ Bootstrap ArgoCD aplicado"
            bootstrap_ok=true
            break
        else
            local rc=$?
            if [[ $rc -eq 2 ]]; then
                log_info "⏳ Gitea aún no accesible desde ArgoCD. Reintentando en 5s..."
                sleep 5
                continue
            fi

            log_error "❌ Error aplicando bootstrap de herramientas"
            return 1
        fi
    done

    if [[ "$bootstrap_ok" != true ]]; then
        log_error "❌ Bootstrap de herramientas no se pudo aplicar tras ${bootstrap_max} intentos"
        return 1
    fi

    # 4. Esperar a que la aplicación agregadora de herramientas quede lista
    log_info "🔎 Esperando aplicación agregadora de herramientas ('herramientas-gitops')"
    if ! wait_argocd_application "herramientas-gitops" 600; then
        log_error "❌ Las herramientas GitOps no alcanzaron estado Synced+Healthy"
        return 1
    fi

    if ! wait_all_apps_healthy argocd 600; then
        log_error "❌ No todas las herramientas GitOps alcanzaron Synced+Healthy"
        return 1
    fi

    # 5. Desplegar ApplicationSet de aplicaciones de ejemplo solo cuando el ecosistema está listo
    log_info "🚀 Desplegando ApplicationSets de aplicaciones personalizadas"

    if [[ -f "$APLICACIONES_DIR/conjunto-aplicaciones.yaml" ]]; then
        kubectl apply -f "$APLICACIONES_DIR/conjunto-aplicaciones.yaml"
        log_success "✅ ApplicationSet principal desplegado"
    else
        log_warning "⚠️ ApplicationSet no encontrado en $APLICACIONES_DIR"
    fi

    # 6. Verificar aplicaciones personalizadas
    log_info "📋 Verificando aplicaciones personalizadas"
    if ! wait_all_apps_healthy argocd 600; then
        log_warning "⚠️ Algunas aplicaciones personalizadas no alcanzaron Synced+Healthy dentro del timeout"
        kubectl get applications -n argocd || true
        return 1
    fi

    log_success "✅ Fase 5 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
