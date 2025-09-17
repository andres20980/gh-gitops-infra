#!/bin/bash

# ============================================================================
# FASE 4: INSTALACIÓN ARGOCD
# ============================================================================
# Instalación robusta de ArgoCD con verificación de contexto y timeouts
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail

ensure_argocd_ui() {
    # Ensure argocd-server is reachable: prefer existing NodePort; else start port-forward
    # Prefer a no-auth proxy service if present
    if kubectl -n "$ARGOCD_NAMESPACE" get svc argocd-server-noauth >/dev/null 2>&1; then
        target_svc=argocd-server-noauth
        svc_type=$(kubectl -n "$ARGOCD_NAMESPACE" get svc argocd-server-noauth -o jsonpath='{.spec.type}' 2>/dev/null || true)
    else
        target_svc=argocd-server
        svc_type=$(kubectl -n "$ARGOCD_NAMESPACE" get svc argocd-server --ignore-not-found -o jsonpath='{.spec.type}' 2>/dev/null || true)
    fi

    if [[ "$svc_type" == "NodePort" ]]; then
        log_success "ArgoCD UI expuesta por Service NodePort"
        return 0
    fi

    # If not NodePort, create a background port-forward to localhost:8080 -> service:80
    if pgrep -f "kubectl -n $ARGOCD_NAMESPACE port-forward svc/${target_svc} 8080:80" >/dev/null 2>&1; then
        log_info "Port-forward de ArgoCD ya está activo"
        return 0
    fi

    log_info "Iniciando port-forward para ArgoCD en background (localhost:8080) hacia ${target_svc}..."
    kubectl -n "$ARGOCD_NAMESPACE" port-forward svc/${target_svc} 8080:80 >/tmp/argocd-port-forward.log 2>&1 &
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

    # Ensure no-auth proxy exists (idempotent). This allows UI access without login.
    if deploy_argocd_noauth_proxy >/dev/null 2>&1; then
        log_info "Proxy no-auth para ArgoCD instalado/actualizado"
    else
        log_warn "No se pudo asegurar proxy no-auth; la UI podría requerir login"
    fi
    
    # 3. Mostrar información de acceso
    show_argocd_access
    show_argocd_cli_status

    # 4. Asegurar acceso UI (NodePort o port-forward)
    ensure_argocd_ui
    
    log_success "✅ Fase 4 completada exitosamente"
}

deploy_argocd_noauth_proxy() {
        log_info "🔐 Configurando proxy no-auth para ArgoCD (argocd-server-noauth)"

        # Obtain admin password from secret and create token via CLI
        ADMIN_PASS=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true)
        if [[ -z "$ADMIN_PASS" ]]; then
                ADMIN_PASS=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-secret -o jsonpath='{.data.admin\.password}' 2>/dev/null | base64 -d 2>/dev/null || true)
        fi
    if [[ -z "$ADMIN_PASS" ]]; then
        log_warning "No se encontró contraseña admin en secretos; no se creará token noauth"
                return 1
        fi

        # Login with argocd CLI (in-cluster we port-forward temporarily to create token)
        TMP_PF_LOG=$(mktemp)
        kubectl -n "$ARGOCD_NAMESPACE" port-forward svc/argocd-server 8080:443 >/dev/null 2>&1 &
        PF_PID=$!
        sleep 2
        # Try login and create token
    if ! argocd login 127.0.0.1:8080 --insecure --username admin --password "$ADMIN_PASS" >/dev/null 2>&1; then
        log_warning "argocd CLI login falló; no se creará token noauth"
                kill $PF_PID >/dev/null 2>&1 || true
                return 1
        fi
        TOKEN_NAME="noauth-$(date +%s)"
        TOKEN_VALUE=$(argocd account generate-token --account admin --description "$TOKEN_NAME" 2>/dev/null || true)
        # Cleanup temporary port-forward
        kill $PF_PID >/dev/null 2>&1 || true

    if [[ -z "$TOKEN_VALUE" ]]; then
        log_warning "No se pudo generar token admin para proxy noauth"
                return 1
        fi

        # Create a simple nginx deployment that forwards Authorization header
        cat <<EOF | kubectl -n "$ARGOCD_NAMESPACE" apply -f -
apiVersion: v1
kind: Service
metadata:
    name: argocd-server-noauth
spec:
    type: ClusterIP
    selector:
        app: argocd-server-noauth
    ports:
        - port: 80
            targetPort: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
    name: argocd-server-noauth
spec:
    replicas: 1
    selector:
        matchLabels:
            app: argocd-server-noauth
    template:
        metadata:
            labels:
                app: argocd-server-noauth
        spec:
            containers:
            - name: nginx-proxy
                image: nginx:1.25
                ports:
                - containerPort: 8080
                volumeMounts:
                - name: nginx-conf
                    mountPath: /etc/nginx/conf.d
            volumes:
            - name: nginx-conf
                configMap:
                    name: argocd-server-noauth-cm
EOF

        # Create configmap with nginx conf that proxies to argocd-server:443 and injects the Authorization header
        cat <<EOF | kubectl -n "$ARGOCD_NAMESPACE" apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
    name: argocd-server-noauth-cm
data:
    default.conf: |
        server {
            listen 8080;
            location / {
                proxy_set_header Authorization "Bearer ${TOKEN_VALUE}";
                proxy_set_header Host $host;
                proxy_pass https://argocd-server:443;
                proxy_ssl_verify off;
            }
        }
EOF

        log_success "✅ Proxy no-auth desplegado como Service 'argocd-server-noauth'"

        # If we have a Gitea admin token cached from fase 02, try to register the repo in ArgoCD
        TOKEN_FILE="${PROJECT_ROOT:-.}/.cache/gitea-admin-token"
        if [[ -f "$TOKEN_FILE" && -x "$(command -v argocd)" ]]; then
            reg_token=$(cat "$TOKEN_FILE")
            repo_url="http://gitea-http.gitea.svc.cluster.local:3000/admin/gitops-infra.git"
            log_info "🔗 Registrando repo en ArgoCD usando token cached"
            if argocd repo add --name gitops-infra --type git --insecure-ignore-host-key --username "admin" --password "$reg_token" "$repo_url" --upsert >/dev/null 2>&1; then
                log_success "✅ Repo registrado en ArgoCD (auto)"
            else
                log_warning "⚠️ Falló registrar repo en ArgoCD (auto)"
            fi
        fi
        return 0
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
