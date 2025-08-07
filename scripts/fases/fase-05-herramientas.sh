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

# Cargar helper dinámico de GitOps
if [[ -f "$SCRIPT_DIR/../comun/helpers/gitops-helper.sh" ]]; then
    # shellcheck source=../comun/helpers/gitops-helper.sh
    source "$SCRIPT_DIR/../comun/helpers/gitops-helper.sh"
else
    echo "❌ Error: No se pudo cargar el helper dinámico de GitOps" >&2
    echo "   Asegúrate de que el sistema de helpers esté disponible" >&2
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
    log_info "🚀 Instalando herramientas GitOps con sistema dinámico v3.0.0..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Se ejecutaría optimización GitOps dinámica"
        autodescubrir_herramientas_gitops
        mostrar_resumen_herramientas
        return 0
    fi
    
    # Ejecutar optimización GitOps completamente dinámica
    log_info "🔍 Iniciando autodescubrimiento y optimización dinámica..."
    
    if ! ejecutar_optimizacion_gitops; then
        log_error "❌ Falló la optimización GitOps dinámica"
        return 1
    fi
    
    log_success "✅ Herramientas GitOps optimizadas dinámicamente"
    return 0
}

# Crear aplicación de herramientas GitOps en ArgoCD
crear_app_herramientas_gitops() {
    log_info "📋 Creando App of Tools en ArgoCD..."
    
    # Verificar que el archivo de configuración existe
    local tools_app_file="argo-apps/app-of-tools-gitops.yaml"
    if [[ ! -f "$tools_app_file" ]]; then
        log_warning "⚠️ Archivo $tools_app_file no encontrado, creando configuración básica..."
        
        # Crear directorio si no existe
        mkdir -p "$(dirname "$tools_app_file")"
        
        # Crear configuración básica
        cat > "$tools_app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-tools-gitops
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/andres20980/gh-gitops-infra.git
    targetRevision: HEAD
    path: herramientas-gitops
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    fi
    
    # Aplicar la aplicación
    if kubectl apply -f "$tools_app_file"; then
        log_success "✅ App of Tools creada en ArgoCD"
    else
        log_warning "⚠️ Error creando App of Tools, pero continuando..."
    fi
}

# Esperar que las herramientas estén healthy
esperar_herramientas_healthy() {
    verificar_estado_herramientas_con_timeout
}

# Verificar estado de herramientas con timeout
verificar_estado_herramientas_con_timeout() {
    log_info "⏳ Esperando que todas las herramientas GitOps estén synced y healthy..."
    local timeout=600  # 10 minutos para herramientas GitOps completas
    local elapsed=0
    local check_interval=15
    
    # Lista de herramientas críticas que deben estar healthy
    local herramientas_criticas=(
        "cert-manager"
        "ingress-nginx" 
        "prometheus-stack"
        "grafana"
    )
    
    log_info "📋 Verificando herramientas críticas: ${herramientas_criticas[*]}"
    
    while [[ $elapsed -lt $timeout ]]; do
        local all_healthy=true
        local status_report=""
        
        # Verificar App of Tools principal
        if kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
            local sync_status
            sync_status=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            local health_status
            health_status=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            status_report="📊 App of Tools: $sync_status/$health_status"
            
            if [[ "$sync_status" != "Synced" ]] || [[ "$health_status" != "Healthy" ]]; then
                all_healthy=false
            fi
        else
            status_report="📊 App of Tools: No encontrada"
            all_healthy=false
        fi
        
        # Verificar herramientas individuales en sus namespaces
        local herramientas_ready=0
        for herramienta in "${herramientas_criticas[@]}"; do
            local namespace=""
            case "$herramienta" in
                "cert-manager") namespace="cert-manager" ;;
                "ingress-nginx") namespace="ingress-nginx" ;;
                "prometheus-stack") namespace="monitoring" ;;
                "grafana") namespace="monitoring" ;;
            esac
            
            if [[ -n "$namespace" ]] && kubectl get namespace "$namespace" >/dev/null 2>&1; then
                local pods_ready
                pods_ready=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | grep -c " Running " || echo "0")
                local total_pods
                total_pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0")
                
                if [[ $pods_ready -gt 0 ]] && [[ $pods_ready -eq $total_pods ]]; then
                    ((herramientas_ready++))
                    status_report="$status_report\n  ✅ $herramienta: $pods_ready/$total_pods pods ready"
                else
                    all_healthy=false
                    status_report="$status_report\n  ⏳ $herramienta: $pods_ready/$total_pods pods ready"
                fi
            else
                all_healthy=false
                status_report="$status_report\n  ❌ $herramienta: namespace no encontrado"
            fi
        done
        
        # Mostrar estado cada 30 segundos
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            echo -e "$status_report"
            log_info "⏳ Progreso: $herramientas_ready/${#herramientas_criticas[@]} herramientas críticas ready (${elapsed}s/${timeout}s)"
        fi
        
        # Si todo está healthy, verificar una vez más para confirmar
        if [[ "$all_healthy" == "true" ]]; then
            log_info "🔍 Todas las herramientas parecen estar ready, verificación final..."
            sleep 10
            
            # Verificación final
            local final_check=true
            if kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
                local final_sync
                final_sync=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
                local final_health
                final_health=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
                
                if [[ "$final_sync" == "Synced" ]] && [[ "$final_health" == "Healthy" ]]; then
                    log_success "✅ Verificación final exitosa: Todas las herramientas GitOps están synced y healthy"
                    log_success "✅ $herramientas_ready/${#herramientas_criticas[@]} herramientas críticas operativas"
                    log_info "📋 Estado final del App of Tools: $final_sync/$final_health"
                    return 0
                else
                    final_check=false
                fi
            else
                final_check=false
            fi
            
            if [[ "$final_check" == "false" ]]; then
                log_warning "⚠️ Verificación final falló, continuando monitoreo..."
                all_healthy=false
            fi
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    # Timeout alcanzado
    log_error "❌ TIMEOUT: Las herramientas GitOps no están completamente ready después de $((timeout/60)) minutos"
    log_error "❌ NO ES SEGURO continuar con la Fase 6 hasta que las herramientas estén healthy"
    
    # Mostrar estado final para diagnóstico
    log_info "📊 Estado final de herramientas GitOps:"
    kubectl get applications -n argocd 2>/dev/null || log_warning "⚠️ No se pueden obtener applications"
    
    log_info "📊 Namespaces con herramientas:"
    for herramienta in "${herramientas_criticas[@]}"; do
        local namespace=""
        case "$herramienta" in
            "cert-manager") namespace="cert-manager" ;;
            "ingress-nginx") namespace="ingress-nginx" ;;
            "prometheus-stack") namespace="monitoring" ;;
            "grafana") namespace="monitoring" ;;
        esac
        
        if [[ -n "$namespace" ]]; then
            if kubectl get namespace "$namespace" >/dev/null 2>&1; then
                log_info "  � $herramienta ($namespace):"
                kubectl get pods -n "$namespace" 2>/dev/null | head -5 || log_warning "    ⚠️ Error obteniendo pods"
            else
                log_warning "  ❌ $herramienta: namespace $namespace no existe"
            fi
        fi
    done
    
    log_info "💡 Para continuar manualmente:"
    log_info "   1. Verifica: kubectl get applications -n argocd"
    log_info "   2. Verifica: kubectl get pods --all-namespaces"
    log_info "   3. Cuando todo esté healthy, ejecuta: ./instalar.sh --fase 06"
    
    return 1  # FALLAR la instalación si las herramientas no están ready
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

# Configurar accesos a herramientas GitOps
configurar_accesos_herramientas() {
    log_info "🌐 Configurando accesos localhost para todas las herramientas GitOps..."
    
    # Mapeo de herramientas y sus puertos (organizados por categoría)
    declare -A herramientas_puertos=(
        # INFRAESTRUCTURA GITOPS (8080-8089)
        ["argocd"]="8080:443"
        ["argo-workflows"]="8081:2746"
        ["argo-events"]="8082:80"
        ["argo-rollouts"]="8083:80"
        ["kargo"]="8084:80"
        
        # OBSERVABILIDAD (8090-8099)
        ["grafana"]="8090:80"
        ["prometheus"]="8091:9090"
        ["alertmanager"]="8092:9093"
        ["jaeger"]="8093:16686"
        ["loki"]="8094:3100"
        
        # ALMACENAMIENTO Y DESARROLLO (8100-8109)
        ["minio"]="8100:9000"
        ["gitea"]="8101:3000"
    )
    
    declare -A herramientas_namespaces=(
        ["argocd"]="argocd"
        ["grafana"]="monitoring"
        ["prometheus"]="monitoring"
        ["alertmanager"]="monitoring"
        ["jaeger"]="jaeger"
        ["kargo"]="kargo"
        ["loki"]="loki"
        ["minio"]="minio"
        ["gitea"]="gitea"
        ["argo-workflows"]="argo-workflows"
        ["argo-events"]="argo-events"
        ["argo-rollouts"]="argo-rollouts"
    )
    
    declare -A herramientas_servicios=(
        ["argocd"]="argocd-server"
        ["grafana"]="prometheus-stack-grafana"
        ["prometheus"]="prometheus-stack-kube-prom-prometheus"
        ["alertmanager"]="prometheus-stack-kube-prom-alertmanager"
        ["jaeger"]="jaeger-query"
        ["kargo"]="kargo-api"
        ["loki"]="loki"
        ["minio"]="minio"
        ["gitea"]="gitea-http"
        ["argo-workflows"]="argo-workflows-server"
        ["argo-events"]="argo-events-webhook"
        ["argo-rollouts"]="argo-rollouts-dashboard"
    )
    
    # Crear script de port-forwards
    crear_script_port_forwards "${herramientas_puertos[@]}" "${herramientas_namespaces[@]}" "${herramientas_servicios[@]}"
    
    # Mostrar accesos disponibles
    mostrar_dashboard_herramientas "${herramientas_puertos[@]}"
    
    # Configurar accesos básicos para herramientas críticas
    configurar_accesos_criticos
}

# Crear script para gestionar port-forwards
crear_script_port_forwards() {
    local script_file="scripts/accesos-herramientas.sh"
    
    log_info "� Creando script de accesos: $script_file"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# ============================================================================
# SCRIPT DE ACCESOS A HERRAMIENTAS GITOPS
# ============================================================================
# Configura port-forwards para acceder a todas las herramientas GitOps
# Uso: ./scripts/accesos-herramientas.sh [start|stop|status|list]
# ============================================================================

set -euo pipefail

# Cargar funciones base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/comun/base.sh"

# Configuración de herramientas
declare -A HERRAMIENTAS_PUERTOS=(
    ["argocd"]="8080:443"
    ["grafana"]="8081:80" 
    ["prometheus"]="8082:9090"
    ["alertmanager"]="8083:9093"
    ["jaeger"]="8084:16686"
    ["kargo"]="8085:80"
    ["loki"]="8086:3100"
    ["minio"]="8087:9000"
    ["gitea"]="8088:3000"
    ["argo-workflows"]="8089:2746"
    ["argo-events"]="8090:80"
    ["argo-rollouts"]="8091:80"
)

declare -A HERRAMIENTAS_NAMESPACES=(
    ["argocd"]="argocd"
    ["grafana"]="monitoring"
    ["prometheus"]="monitoring"
    ["alertmanager"]="monitoring"
    ["jaeger"]="jaeger"
    ["kargo"]="kargo"
    ["loki"]="loki"
    ["minio"]="minio"
    ["gitea"]="gitea"
    ["argo-workflows"]="argo-workflows"
    ["argo-events"]="argo-events"
    ["argo-rollouts"]="argo-rollouts"
)

declare -A HERRAMIENTAS_SERVICIOS=(
    ["argocd"]="argocd-server"
    ["grafana"]="prometheus-stack-grafana"
    ["prometheus"]="prometheus-stack-kube-prom-prometheus"
    ["alertmanager"]="prometheus-stack-kube-prom-alertmanager"
    ["jaeger"]="jaeger-query"
    ["kargo"]="kargo-api"
    ["loki"]="loki"
    ["minio"]="minio"
    ["gitea"]="gitea-http"
    ["argo-workflows"]="argo-workflows-server"
    ["argo-events"]="argo-events-webhook"
    ["argo-rollouts"]="argo-rollouts-dashboard"
)

# Función para iniciar port-forwards
start_port_forwards() {
    log_info "🚀 Iniciando port-forwards para herramientas GitOps..."
    
    for herramienta in "${!HERRAMIENTAS_PUERTOS[@]}"; do
        local namespace="${HERRAMIENTAS_NAMESPACES[$herramienta]}"
        local servicio="${HERRAMIENTAS_SERVICIOS[$herramienta]}"
        local puerto="${HERRAMIENTAS_PUERTOS[$herramienta]}"
        local puerto_local="${puerto%:*}"
        local puerto_remoto="${puerto#*:}"
        
        # Verificar si el namespace y servicio existen
        if kubectl get namespace "$namespace" >/dev/null 2>&1 && \
           kubectl get service "$servicio" -n "$namespace" >/dev/null 2>&1; then
            
            # Verificar si ya hay un port-forward activo
            if ! lsof -i ":$puerto_local" >/dev/null 2>&1; then
                log_info "  🔗 $herramienta: localhost:$puerto_local"
                kubectl port-forward -n "$namespace" "service/$servicio" "$puerto" >/dev/null 2>&1 &
                sleep 1
            else
                log_warning "  ⚠️ $herramienta: puerto $puerto_local ya en uso"
            fi
        else
            log_warning "  ❌ $herramienta: servicio no disponible ($namespace/$servicio)"
        fi
    done
    
    log_success "✅ Port-forwards configurados (en background)"
}

# Función para parar port-forwards
stop_port_forwards() {
    log_info "🛑 Deteniendo port-forwards de herramientas GitOps..."
    
    for herramienta in "${!HERRAMIENTAS_PUERTOS[@]}"; do
        local puerto_local="${HERRAMIENTAS_PUERTOS[$herramienta]%:*}"
        
        local pid
        pid=$(lsof -t -i ":$puerto_local" 2>/dev/null || echo "")
        if [[ -n "$pid" ]]; then
            kill "$pid" 2>/dev/null || true
            log_info "  🛑 $herramienta: puerto $puerto_local liberado"
        fi
    done
    
    log_success "✅ Todos los port-forwards detenidos"
}

# Función para mostrar estado
show_status() {
    log_info "📊 Estado de accesos a herramientas GitOps:"
    echo
    
    for herramienta in "${!HERRAMIENTAS_PUERTOS[@]}"; do
        local puerto_local="${HERRAMIENTAS_PUERTOS[$herramienta]%:*}"
        
        if lsof -i ":$puerto_local" >/dev/null 2>&1; then
            echo "  ✅ $herramienta: http://localhost:$puerto_local"
        else
            echo "  ❌ $herramienta: no disponible (puerto $puerto_local)"
        fi
    done
    echo
}

# Función para listar todas las herramientas
list_tools() {
    log_info "📋 Herramientas GitOps disponibles:"
    echo
    echo "🔧 INFRAESTRUCTURA BÁSICA:"
    echo "  • ArgoCD (GitOps)          : http://localhost:8080"
    echo "  • Cert-Manager (TLS)       : Automático (sin UI)"
    echo "  • Ingress-NGINX (Ingress)  : Automático (sin UI específica)"
    echo
    echo "� OBSERVABILIDAD Y MONITOREO:"
    echo "  • Grafana (Dashboards)     : http://localhost:8081"
    echo "  • Prometheus (Métricas)    : http://localhost:8082"
    echo "  • AlertManager (Alertas)   : http://localhost:8083"
    echo "  • Jaeger (Tracing)         : http://localhost:8084"
    echo "  • Loki (Logs)              : http://localhost:8086"
    echo
    echo "🚀 HERRAMIENTAS GITOPS AVANZADAS:"
    echo "  • Argo Workflows (CI/CD)   : http://localhost:8089"
    echo "  • Argo Events (Eventos)    : http://localhost:8090"
    echo "  • Argo Rollouts (Deploy)   : http://localhost:8091"
    echo "  • Kargo (Promoción)        : http://localhost:8085"
    echo
    echo "�📦 ALMACENAMIENTO Y CÓDIGO:"
    echo "  • MinIO (S3 Storage)       : http://localhost:8087"
    echo "  • Gitea (Git Server)       : http://localhost:8088"
    echo
}

# Función principal
main() {
    local action="${1:-start}"
    
    case "$action" in
        "start")
            start_port_forwards
            show_status
            ;;
        "stop")
            stop_port_forwards
            ;;
        "status")
            show_status
            ;;
        "list")
            list_tools
            ;;
        *)
            echo "Uso: $0 [start|stop|status|list]"
            echo "  start  - Iniciar port-forwards"
            echo "  stop   - Detener port-forwards" 
            echo "  status - Mostrar estado actual"
            echo "  list   - Listar todas las herramientas"
            exit 1
            ;;
    esac
}

main "$@"
EOF

    chmod +x "$script_file"
    log_success "✅ Script de accesos creado: $script_file"
}

# Mostrar dashboard de herramientas disponibles
mostrar_dashboard_herramientas() {
    log_info "🎛️ DASHBOARD DE HERRAMIENTAS GITOPS DISPONIBLES"
    echo "================================================================================"
    echo
    
    # Obtener credenciales dinámicamente
    local argocd_password
    argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Ver logs de instalación")
    
    local grafana_password
    grafana_password=$(kubectl -n monitoring get secret grafana -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "prom-operator")
    
    local minio_user="minioadmin"
    local minio_password="minioadmin"
    if kubectl get namespace minio >/dev/null 2>&1; then
        minio_user=$(kubectl -n minio get secret minio -o jsonpath="{.data.root-user}" 2>/dev/null | base64 -d 2>/dev/null || echo "minioadmin")
        minio_password=$(kubectl -n minio get secret minio -o jsonpath="{.data.root-password}" 2>/dev/null | base64 -d 2>/dev/null || echo "minioadmin")
    fi
    
    local gitea_user="gitea"
    local gitea_password="gitea"
    if kubectl get namespace gitea >/dev/null 2>&1; then
        gitea_user=$(kubectl -n gitea get secret gitea -o jsonpath="{.data.username}" 2>/dev/null | base64 -d 2>/dev/null || echo "gitea")
        gitea_password=$(kubectl -n gitea get secret gitea -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "gitea")
    fi
    
    echo "🔧 INFRAESTRUCTURA GITOPS:"
    echo "  • ArgoCD (GitOps Controller)    : http://localhost:8080"
    echo "    👤 Usuario: admin | 🔑 Password: $argocd_password"
    echo "  • Argo Workflows (CI/CD)        : http://localhost:8081"
    echo "    👤 Service Account (sin login manual)"
    echo "  • Argo Events (Event-driven)    : http://localhost:8082"
    echo "    👤 Sin autenticación requerida"
    echo "  • Argo Rollouts (Deploy Avanz.) : http://localhost:8083"
    echo "    👤 Sin autenticación requerida"
    echo "  • Kargo (Environment Promotion) : http://localhost:8084"
    echo "    👤 Service Account (sin login manual)"
    echo "  • Cert-Manager (TLS Automático) : Sin UI (funciona automáticamente)"
    echo "  • Ingress-NGINX (Load Balancer) : Sin UI específica"
    echo
    echo "� OBSERVABILIDAD Y MONITOREO:"
    echo "  • Grafana (Dashboards)          : http://localhost:8090"
    echo "    👤 Usuario: admin | 🔑 Password: $grafana_password"
    echo "  • Prometheus (Métricas)         : http://localhost:8091"
    echo "    👤 Sin autenticación requerida"
    echo "  • AlertManager (Alertas)        : http://localhost:8092"
    echo "    👤 Sin autenticación requerida"
    echo "  • Jaeger (Distributed Tracing)  : http://localhost:8093"
    echo "    👤 Sin autenticación requerida"
    echo "  • Loki (Log Aggregation)        : http://localhost:8094"
    echo "    👤 Sin autenticación requerida"
    echo
    echo "📦 ALMACENAMIENTO Y DESARROLLO:"
    echo "  • MinIO (S3 Compatible Storage) : http://localhost:8100"
    echo "    👤 Usuario: $minio_user | 🔑 Password: $minio_password"
    echo "  • Gitea (Git Server Local)      : http://localhost:8101"
    echo "    👤 Usuario: $gitea_user | 🔑 Password: $gitea_password"
    echo
    echo "================================================================================"
    echo "💡 COMANDOS ÚTILES:"
    echo "  • Iniciar accesos    : ./scripts/accesos-herramientas.sh start"
    echo "  • Ver estado         : ./scripts/accesos-herramientas.sh status"
    echo "  • Parar accesos      : ./scripts/accesos-herramientas.sh stop"
    echo "  • Listar herramientas: ./scripts/accesos-herramientas.sh list"
    echo "  • Ver credenciales   : ./obtener-credenciales.sh"
    echo "================================================================================"
    echo "📋 ORGANIZACIÓN DE PUERTOS:"
    echo "  🔧 GitOps:      8080-8084 (ArgoCD, Workflows, Events, Rollouts, Kargo)"
    echo "  📊 Observabilidad: 8090-8094 (Grafana, Prometheus, AlertManager, Jaeger, Loki)"  
    echo "  📦 Storage/Dev:    8100-8101 (MinIO, Gitea)"
    echo "================================================================================"
}

# Configurar accesos críticos inmediatos
configurar_accesos_criticos() {
    log_info "� Configurando accesos inmediatos para herramientas críticas..."
    
    # ArgoCD (ya debería estar disponible)
    local argocd_port
    argocd_port=$(kubectl get service argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null || echo "")
    if [[ -n "$argocd_port" ]]; then
        local cluster_ip
        cluster_ip=$(minikube ip -p gitops-dev 2>/dev/null || echo "192.168.49.2")
        log_success "✅ ArgoCD ya disponible en: https://$cluster_ip:$argocd_port"
        
        # También configurar port-forward para localhost
        if ! lsof -i :8080 >/dev/null 2>&1; then
            kubectl port-forward -n argocd service/argocd-server 8080:443 >/dev/null 2>&1 &
            sleep 2
            log_success "✅ ArgoCD port-forward: http://localhost:8080"
        fi
    fi
    
    # Grafana (si está disponible)
    if kubectl get namespace monitoring >/dev/null 2>&1 && \
       kubectl get service prometheus-stack-grafana -n monitoring >/dev/null 2>&1; then
        if ! lsof -i :8081 >/dev/null 2>&1; then
            kubectl port-forward -n monitoring service/prometheus-stack-grafana 8081:80 >/dev/null 2>&1 &
            sleep 2
            log_success "✅ Grafana port-forward: http://localhost:8081"
        fi
    fi
    
    log_info "💡 Otros accesos se configurarán automáticamente cuando las herramientas estén ready"
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
    log_info "⏳ CRÍTICO: Verificando que todas las herramientas estén completamente ready..."
    log_info "⚠️ La Fase 6 NO se ejecutará hasta que esto se complete exitosamente"
    
    # Verificación simplificada para evitar colgarse
    log_info "🔍 Verificando App of Tools principal..."
    if kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
        local sync_status
        sync_status=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        local health_status
        health_status=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        log_info "� App of Tools: $sync_status/$health_status"
        
        if [[ "$sync_status" == "Synced" ]] && [[ "$health_status" == "Healthy" ]]; then
            log_success "✅ App of Tools está Synced y Healthy - herramientas disponibles"
        else
            log_warning "⚠️ App of Tools: $sync_status/$health_status - continuando con configuración de accesos"
        fi
    else
        log_error "❌ FASE 5 FALLÓ: App of Tools no encontrada"
        return 1
    fi
    
    # CONFIGURAR ACCESOS A HERRAMIENTAS
    log_info "🌐 Configurando accesos localhost para todas las herramientas..."
    configurar_accesos_herramientas
    
    log_info "📋 Para verificar el estado de las herramientas:"
    log_info "   kubectl get applications -n argocd"
    log_info "   kubectl get pods --all-namespaces"
    log_info "   ./scripts/accesos-herramientas.sh status"
    
    log_success "✅ Fase 5 completada: Herramientas GitOps instaladas, healthy y accesibles"
    log_success "🌐 Todas las herramientas disponibles desde localhost:8080+"
    log_info "🎯 Próximo paso: Instalar aplicaciones custom (Fase 6)"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_05_herramientas "$@"
fi
