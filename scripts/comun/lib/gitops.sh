#!/bin/bash

# ============================================================================
# GITOPS LIB - Gestión Universal de Herramientas GitOps
# ============================================================================
# Responsabilidad: ArgoCD, Helm charts, aplicaciones GitOps
# Principios: GitOps-native, Security-first, Production-ready
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Permitir override desde configuracion.sh; usar valores por defecto si no están definidos
: "${ARGOCD_NAMESPACE:=argocd}"
: "${ARGOCD_VERSION:=stable}"  # Siempre usa la versión estable más reciente
: "${ARGOCD_TIMEOUT:=300}"

# Modo de exposición del servidor ArgoCD: nodeport | port-forward
: "${ARGOCD_EXPOSE_MODE:=port-forward}"
: "${ARGOCD_PORT_FORWARD_PORT:=8080}"
: "${ARGOCD_PORT_FORWARD_ADDR:=127.0.0.1}"
: "${ARGOCD_AUTO_LOGIN:=true}"

# Lista de herramientas GitOps; permite override si el entorno define GITOPS_TOOLS
: "${GITOPS_TOOLS:=}"
if [[ -z "$GITOPS_TOOLS" ]]; then
readonly GITOPS_TOOLS=(
    "argo-events:monitoring"
    "argo-rollouts:deployment"
    "argo-workflows:workflows"
    "cert-manager:security"
    "external-secrets:security"
    "gitea:scm"
    "grafana:monitoring"
    "ingress-nginx:networking"
    "jaeger:tracing"
    "kargo:deployment"
    "loki:logging"
    "minio:storage"
    "prometheus-stack:monitoring"
)
fi

# ============================================================================
# FUNCIONES DE ARGOCD
# ============================================================================

# Verificar si ArgoCD existe
check_argocd_exists() {
    if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
        log_info "📋 Namespace $ARGOCD_NAMESPACE existe"
        
        if kubectl get deployment argocd-server -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
            local ready_replicas
            ready_replicas=$(kubectl get deployment argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            
            if [[ "$ready_replicas" -gt 0 ]]; then
                log_success "✅ ArgoCD instalado y funcionando"
                return 0
            else
                log_warning "⚠️ ArgoCD instalado pero no Ready"
                return 1
            fi
        else
            log_warning "⚠️ Namespace existe pero ArgoCD no instalado"
            return 1
        fi
    else
        log_info "🆕 ArgoCD no está instalado"
        return 1
    fi
}

# Instalar ArgoCD
install_argocd() {
    log_info "📦 Instalando ArgoCD..."
    
    # Crear namespace
    if ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
        kubectl create namespace "$ARGOCD_NAMESPACE"
        log_success "✅ Namespace $ARGOCD_NAMESPACE creado"
    fi
    
    # Instalar ArgoCD
    log_info "📥 Descargando ArgoCD $ARGOCD_VERSION..."
    if ! kubectl apply -n "$ARGOCD_NAMESPACE" -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"; then
        log_error "❌ Error instalando ArgoCD"
        return 1
    fi
    
    log_success "✅ ArgoCD instalado"
    return 0
}

# Configurar servicio ArgoCD
setup_argocd_service() {
    log_info "🌐 Configurando servicio ArgoCD..."
    
    # NodePort para acceso externo
    kubectl patch svc argocd-server -n "$ARGOCD_NAMESPACE" -p '{"spec":{"type":"NodePort","ports":[{"name":"https","port":443,"targetPort":8080,"nodePort":30443}]}}'
    
    local service_type
    service_type=$(kubectl get svc argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null || echo "Unknown")
    
    if [[ "$service_type" == "NodePort" ]]; then
        log_success "✅ Servicio ArgoCD configurado como NodePort"
        return 0
    else
        log_error "❌ Error configurando servicio ArgoCD"
        return 1
    fi
}

# Exponer ArgoCD vía port-forward en background
setup_argocd_port_forward() {
    local port="${ARGOCD_PORT_FORWARD_PORT}" addr="${ARGOCD_PORT_FORWARD_ADDR}"
    local pid_file="/tmp/argocd-port-forward.pid"
    local log_file="/tmp/argocd-port-forward.log"

    log_info "🔌 Exponiendo ArgoCD por port-forward en https://${addr}:${port} ..."

    # Asegurar svc existe
    if ! kubectl -n "$ARGOCD_NAMESPACE" get svc argocd-server >/dev/null 2>&1; then
        log_error "❌ Servicio argocd-server no encontrado"
        return 1
    fi

    # Si ya hay un port-forward activo, mantenerlo
    if [[ -f "$pid_file" ]]; then
        local old_pid
        old_pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" >/dev/null 2>&1; then
            log_success "✅ Port-forward ya activo (PID $old_pid)"
            return 0
        fi
    fi

    # Intentar liberar puerto si está en uso
    if command -v fuser >/dev/null 2>&1; then
        fuser -k "${port}/tcp" >/dev/null 2>&1 || true
    fi

    # Lanzar en background
    nohup kubectl -n "$ARGOCD_NAMESPACE" port-forward svc/argocd-server "${port}:443" --address="$addr" >"$log_file" 2>&1 &
    local pf_pid=$!
    echo "$pf_pid" > "$pid_file"

    # Esperar hasta que esté activo
    local waited=0; local max_wait=30
    until grep -q "Forwarding from ${addr}:${port}" "$log_file" 2>/dev/null; do
        sleep 1; waited=$((waited+1))
        if (( waited >= max_wait )); then
            log_error "❌ Port-forward no se activó a tiempo (ver $log_file)"
            return 1
        fi
    done
    log_success "✅ Port-forward activo (PID $pf_pid)"
}

# Selector de exposición según modo
expose_argocd() {
    case "$ARGOCD_EXPOSE_MODE" in
        nodeport)
            setup_argocd_service
            ;;
        port-forward)
            setup_argocd_port_forward
            ;;
        *)
            log_warning "⚠️ Modo ARGOCD_EXPOSE_MODE desconocido: $ARGOCD_EXPOSE_MODE, usando port-forward"
            setup_argocd_port_forward
            ;;
    esac
}

# Esperar ArgoCD ready
wait_argocd_ready() {
    log_info "⏳ Esperando ArgoCD ready..."
    
    local components=("argocd-server" "argocd-repo-server" "argocd-application-controller")
    for component in "${components[@]}"; do
        log_info "🔄 Esperando $component..."

        # Si existe como Deployment, esperar condición available
        if kubectl -n "$ARGOCD_NAMESPACE" get deploy "$component" >/dev/null 2>&1; then
            if ! kubectl -n "$ARGOCD_NAMESPACE" wait --for=condition=available --timeout=${ARGOCD_TIMEOUT}s deployment/"$component" >/dev/null 2>&1; then
                log_error "❌ Timeout esperando deployment/$component"
                return 1
            fi
            log_success "✅ $component disponible (Deployment)"
            continue
        fi

        # Si existe como StatefulSet, usar rollout status
        if kubectl -n "$ARGOCD_NAMESPACE" get sts "$component" >/dev/null 2>&1; then
            if ! kubectl -n "$ARGOCD_NAMESPACE" rollout status statefulset/"$component" --timeout=${ARGOCD_TIMEOUT}s >/dev/null 2>&1; then
                log_error "❌ Timeout esperando statefulset/$component"
                return 1
            fi
            log_success "✅ $component disponible (StatefulSet)"
            continue
        fi

        # Como fallback, esperar pods por etiqueta de nombre
        if ! kubectl -n "$ARGOCD_NAMESPACE" wait --for=condition=ready pod -l app.kubernetes.io/name="$component" --timeout=${ARGOCD_TIMEOUT}s >/dev/null 2>&1; then
            log_error "❌ Timeout esperando pods de $component"
            return 1
        fi
        log_success "✅ $component disponible (Pods)"
    done
    
    local running_pods
    running_pods=$(kubectl get pods -n "$ARGOCD_NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    log_success "✅ ArgoCD completamente ready ($running_pods pods running)"
    return 0
}

# Configurar ArgoCD CLI
setup_argocd_cli() {
    log_info "🔧 Configurando ArgoCD CLI..."
    
    local argocd_server_url
    if [[ "$ARGOCD_EXPOSE_MODE" == "nodeport" ]]; then
        local ip port
        ip=$(minikube ip --profile=gitops-dev 2>/dev/null || echo "localhost")
        port=$(kubectl get svc argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30443")
        argocd_server_url="$ip:$port"
    else
        local addr="${ARGOCD_PORT_FORWARD_ADDR}" port="${ARGOCD_PORT_FORWARD_PORT}"
        argocd_server_url="$addr:$port"
    fi
    export ARGOCD_SERVER="$argocd_server_url"
    
    # Autologin opcional
    if [[ "$ARGOCD_AUTO_LOGIN" == "true" ]] && command -v argocd >/dev/null 2>&1; then
        # Asegurar exposición activa si usamos port-forward
        if [[ "$ARGOCD_EXPOSE_MODE" == "port-forward" ]]; then
            setup_argocd_port_forward || log_warning "⚠️ No se pudo asegurar port-forward activo"
        fi
        # Seleccionar contexto y comprobar si ya hay sesión
        argocd context "$argocd_server_url" >/dev/null 2>&1 || true
        if argocd account get-user-info >/dev/null 2>&1; then
            log_success "✅ ArgoCD CLI ya autenticado"
            return 0
        fi
        # Obtener contraseña inicial
        local argocd_password
        argocd_password=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")

        if [[ -z "$argocd_password" ]]; then
            log_warning "⚠️ No se pudo obtener contraseña inicial ArgoCD"
            return 0
        fi

        log_info "🔐 Configurando login automático..."
        if echo "$argocd_password" | argocd login "$argocd_server_url" --insecure --username admin --password-stdin >/dev/null 2>&1; then
            log_success "✅ ArgoCD CLI configurado y login exitoso"
            argocd context "$argocd_server_url" >/dev/null 2>&1 || true
        else
            log_info "ℹ️ Autologin no completado (posible contexto previo). Puedes ejecutar: argocd login $argocd_server_url --insecure"
            return 0
        fi
    else
        log_info "💡 Autologin desactivado o CLI no disponible; saltando"
        return 0
    fi
}

# Mostrar info de acceso ArgoCD
show_argocd_access() {
    log_section "🌟 Información de Acceso ArgoCD"
    local argocd_password
    argocd_password=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")

    if [[ "$ARGOCD_EXPOSE_MODE" == "nodeport" ]]; then
        local ip port
        ip=$(minikube ip --profile=gitops-dev 2>/dev/null || echo "localhost")
        port=$(kubectl get svc argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30443")
        log_info "🌐 URL: https://$ip:$port"
        log_info "👤 Usuario: admin"
        log_info "🔑 Contraseña: $argocd_password"
        log_info ""
        log_info "💡 Para acceso por CLI:"
        log_info "   argocd login $ip:$port --insecure"
    else
        local addr="${ARGOCD_PORT_FORWARD_ADDR}" port="${ARGOCD_PORT_FORWARD_PORT}"
        log_info "🌐 URL: https://$addr:$port"
        log_info "👤 Usuario: admin"
        log_info "🔑 Contraseña: $argocd_password"
        log_info ""
        log_info "💡 Para acceso por CLI:"
        log_info "   argocd login $addr:$port --insecure"
    fi
}

# Mostrar estado de la CLI de ArgoCD (logueado o no)
show_argocd_cli_status() {
    if ! command -v argocd >/dev/null 2>&1; then
        log_info "🔐 ArgoCD CLI no instalada"
        return 0
    fi

    # Determinar servidor según modo
    local server
    if [[ "$ARGOCD_EXPOSE_MODE" == "nodeport" ]]; then
        local ip port
        ip=$(minikube ip --profile=gitops-dev 2>/dev/null || echo "localhost")
        port=$(kubectl get svc argocd-server -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30443")
        server="$ip:$port"
    else
        # Asegurar port-forward activo
        setup_argocd_port_forward || true
        server="${ARGOCD_PORT_FORWARD_ADDR}:${ARGOCD_PORT_FORWARD_PORT}"
    fi

    # Seleccionar contexto y consultar info
    argocd context "$server" >/dev/null 2>&1 || true
    local info
    info=$(argocd account get-user-info 2>/dev/null || true)

    if [[ -n "$info" ]]; then
        local user
        user=$(grep -E '^Username:' <<<"$info" | awk '{print $2}' | head -1 || echo "admin")
        log_success "✅ ArgoCD CLI: Logged In: true | Usuario: $user | Servidor: $server"
    else
        log_info "🔐 ArgoCD CLI: Logged In: false | Servidor: $server"
        log_info "   Ejecuta: argocd login $server --insecure"
    fi
}

# ============================================================================
# FUNCIONES DE HELM
# ============================================================================

# Verificar si chart Helm está instalado
check_helm_chart() {
    local release="$1"
    local namespace="$2"
    
    if helm list -n "$namespace" 2>/dev/null | grep -q "^$release"; then
        local status
        status=$(helm status "$release" -n "$namespace" -o json 2>/dev/null | jq -r '.info.status' 2>/dev/null || echo "unknown")
        
        if [[ "$status" == "deployed" ]]; then
            log_success "✅ Chart $release deployed en $namespace"
            return 0
        else
            log_warning "⚠️ Chart $release status: $status"
            return 1
        fi
    else
        log_info "🆕 Chart $release no instalado en $namespace"
        return 1
    fi
}

# Instalar chart Helm
install_helm_chart() {
    local release="$1"
    local chart="$2"
    local namespace="$3"
    local values_file="${4:-}"
    
    log_info "📦 Instalando chart $release..."
    
    # Crear namespace si no existe
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        kubectl create namespace "$namespace"
        log_success "✅ Namespace $namespace creado"
    fi
    
    # Construir comando helm
    local helm_cmd="helm install $release $chart --namespace $namespace --create-namespace"
    
    if [[ -n "$values_file" && -f "$values_file" ]]; then
        helm_cmd+=" --values $values_file"
        log_info "📄 Usando values: $values_file"
    fi
    
    # Instalar chart
    if eval "$helm_cmd" >/dev/null 2>&1; then
        log_success "✅ Chart $release instalado"
        return 0
    else
        log_error "❌ Error instalando chart $release"
        return 1
    fi
}

# Actualizar chart Helm
upgrade_helm_chart() {
    local release="$1"
    local chart="$2"
    local namespace="$3"
    local values_file="${4:-}"
    
    log_info "🔄 Actualizando chart $release..."
    
    local helm_cmd="helm upgrade $release $chart --namespace $namespace"
    
    if [[ -n "$values_file" && -f "$values_file" ]]; then
        helm_cmd+=" --values $values_file"
    fi
    
    if eval "$helm_cmd" >/dev/null 2>&1; then
        log_success "✅ Chart $release actualizado"
        return 0
    else
        log_error "❌ Error actualizando chart $release"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE APLICACIONES GITOPS
# ============================================================================

# Instalar herramienta GitOps
install_gitops_tool() {
    local tool="$1"
    local category="$2"
    
    log_info "🔧 Instalando herramienta GitOps: $tool"
    
    local chart_file="$PROJECT_ROOT/herramientas-gitops/${tool}.yaml"
    local values_file="$PROJECT_ROOT/herramientas-gitops/values-dev/${tool}-dev-values.yaml"
    
    if [[ ! -f "$chart_file" ]]; then
        log_error "❌ Chart file no encontrado: $chart_file"
        return 1
    fi
    
    # Aplicar configuración
    if kubectl apply -f "$chart_file"; then
        log_success "✅ $tool configurado"
        
        # Esperar deployment si es aplicación
        local namespace
        namespace=$(grep -E "^\s*namespace:" "$chart_file" | awk '{print $2}' | head -1 || echo "default")
        
        if kubectl get deployment -n "$namespace" 2>/dev/null | grep -q "$tool"; then
            log_info "⏳ Esperando deployment $tool..."
            kubectl wait --for=condition=available --timeout=180s deployment -l app.kubernetes.io/name="$tool" -n "$namespace" >/dev/null 2>&1 || true
        fi
        
        return 0
    else
        log_error "❌ Error instalando $tool"
        return 1
    fi
}

# Instalar todas las herramientas GitOps
install_all_gitops_tools() {
    log_section "🛠️ Instalando Herramientas GitOps"
    
    local success_count=0
    local total_count=${#GITOPS_TOOLS[@]}
    
    for spec in "${GITOPS_TOOLS[@]}"; do
        IFS=':' read -r tool category <<< "$spec"
        
        if install_gitops_tool "$tool" "$category"; then
            ((success_count++))
        fi
    done
    
    log_info "📊 Instalación completada: $success_count/$total_count herramientas"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "✅ Todas las herramientas GitOps instaladas"
        return 0
    else
        log_warning "⚠️ Algunas herramientas fallaron"
        return 1
    fi
}

# ============================================================================
# FUNCIONES PRINCIPALES
# ============================================================================

# Instalar stack GitOps completo
install_gitops_stack() {
    log_section "🚀 Instalación Stack GitOps Completo"
    
    # 1. Verificar cluster disponible
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster no disponible"
        return 1
    fi
    
    # 2. Instalar ArgoCD
    if ! check_argocd_exists; then
        if ! install_argocd; then
            return 1
        fi
        expose_argocd
        wait_argocd_ready
        setup_argocd_cli
    else
        # Asegurar exposición según modo actual
        expose_argocd || true
    fi
    
    # 3. Instalar herramientas GitOps
    install_all_gitops_tools
    
    # 4. Mostrar información final
    show_argocd_access
    
    log_success "✅ Stack GitOps instalado completamente"
    return 0
}

# Mostrar resumen GitOps
show_gitops_summary() {
    log_section "📋 Resumen Stack GitOps"
    
    # ArgoCD status
    if check_argocd_exists; then
        log_info "✅ ArgoCD: Instalado y funcionando"
        
        local argocd_apps
        argocd_apps=$(kubectl get applications -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | wc -l || echo "0")
        log_info "  📱 Aplicaciones: $argocd_apps"
    else
        log_info "❌ ArgoCD: No instalado"
    fi
    
    # Herramientas GitOps
    log_info "🛠️ Herramientas GitOps:"
    for spec in "${GITOPS_TOOLS[@]}"; do
        IFS=':' read -r tool category <<< "$spec"
        
        if kubectl get all -l app.kubernetes.io/name="$tool" --all-namespaces >/dev/null 2>&1; then
            log_info "  ✅ $tool ($category)"
        else
            log_info "  ❌ $tool ($category)"
        fi
    done
}
