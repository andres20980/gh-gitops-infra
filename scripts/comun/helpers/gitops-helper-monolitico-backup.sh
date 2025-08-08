#!/bin/bash
# GitOps Helper - Sistema de optimización dinámico v3.0.0
# Autodescubrimiento y búsqueda de versiones en tiempo real

#!/bin/bash
# ============================================================================
# GITOPS HELPER - Sistema dinámico de gestión de herramientas GitOps
# ============================================================================

# Desactivar set -u para evitar errores con variables dinámicas
set +u

# Arrays globales para el sistema dinámico
GITOPS_TOOLS_DISCOVERED=()
declare -a GITOPS_TOOLS_DISCOVERED
declare -A GITOPS_CHART_INFO

# Función para autodescubrir herramientas GitOps en tiempo real
autodescubrir_herramientas_gitops() {
    local directorio_herramientas="herramientas-gitops"
    
    echo "🔍 Autodescubriendo herramientas GitOps en $directorio_herramientas..."
    
    # Limpiar arrays dinámicos
    GITOPS_TOOLS_DISCOVERED=()
    # Limpiar array asociativo correctamente
    for key in "${!GITOPS_CHART_INFO[@]}"; do
        unset GITOPS_CHART_INFO["$key"]
    done
    
    # Escanear todos los archivos YAML en herramientas-gitops
    for archivo_yaml in "$directorio_herramientas"/*.yaml; do
        if [[ -f "$archivo_yaml" ]]; then
            local nombre_herramienta=$(basename "$archivo_yaml" .yaml)
            GITOPS_TOOLS_DISCOVERED+=("$nombre_herramienta")
            
            echo "   📦 Descubierto: $nombre_herramienta"
            
            # Extraer información del chart del YAML
            extraer_info_chart_del_yaml "$archivo_yaml" "$nombre_herramienta"
        fi
    done
    
    echo "✅ Autodescubrimiento completado: ${#GITOPS_TOOLS_DISCOVERED[@]} herramientas encontradas"
}

# Función para extraer información del chart directamente del YAML
extraer_info_chart_del_yaml() {
    local archivo_yaml="$1"
    local herramienta="$2"
    
    echo "   🔍 DEBUG: Procesando herramienta='$herramienta' archivo='$archivo_yaml'"
    
    # Buscar información del repositorio Helm en el YAML
    local repo_url=$(grep -E '^\s*repoURL:' "$archivo_yaml" | head -1 | sed 's/.*repoURL:\s*//' | tr -d '"' | tr -d "'")
    local chart_name=$(grep -E '^\s*chart:' "$archivo_yaml" | head -1 | sed 's/.*chart:\s*//' | tr -d '"' | tr -d "'")
    
    echo "   🔍 DEBUG: repo_url='$repo_url' chart_name='$chart_name'"
    
    # Si no hay información del chart, intentar deducirla
    if [[ -z "$repo_url" || -z "$chart_name" ]]; then
        echo "   ⚠️  No se encontró info de chart en $archivo_yaml, usando detección inteligente"
        detectar_chart_inteligente "$herramienta"
    else
        # Extraer nombre del repositorio de la URL - manejo seguro
        local repo_name
        repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|\.github\.io/.*||' | sed 's|.*github\.com/||' | sed 's|/.*||' 2>/dev/null || echo "unknown")
        
        echo "   🔍 DEBUG: repo_name='$repo_name' antes de asignar al array"
        
        # Usar variables auxiliares para evitar problemas de expansión con guiones
        local key_repo="${herramienta}_repo"
        local key_chart="${herramienta}_chart"
        local key_repo_url="${herramienta}_repo_url"
        
        GITOPS_CHART_INFO["$key_repo"]="$repo_name"
        GITOPS_CHART_INFO["$key_chart"]="$chart_name"
        GITOPS_CHART_INFO["$key_repo_url"]="$repo_url"
        
        echo "   📋 Chart detectado: $repo_name/$chart_name"
    fi
}

# Función de detección inteligente de charts
detectar_chart_inteligente() {
    local herramienta="$1"
    
    # Variables auxiliares para evitar problemas de expansión con guiones
    local key_repo="${herramienta}_repo"
    local key_chart="${herramienta}_chart"
    
    # Base de conocimiento inteligente para detección automática
    case "$herramienta" in
        *"ingress"*|*"nginx"*)
            GITOPS_CHART_INFO["$key_repo"]="ingress-nginx"
            GITOPS_CHART_INFO["$key_chart"]="ingress-nginx"
            ;;
        *"external"*|*"secret"*)
            GITOPS_CHART_INFO["$key_repo"]="external-secrets"
            GITOPS_CHART_INFO["$key_chart"]="external-secrets"
            ;;
        *"cert"*|*"manager"*)
            GITOPS_CHART_INFO["$key_repo"]="jetstack"
            GITOPS_CHART_INFO["$key_chart"]="cert-manager"
            ;;
        *"argo"*"event"*)
            GITOPS_CHART_INFO["$key_repo"]="argo"
            GITOPS_CHART_INFO["$key_chart"]="argo-events"
            ;;
        *"argo"*"workflow"*)
            GITOPS_CHART_INFO["$key_repo"]="argo"
            GITOPS_CHART_INFO["$key_chart"]="argo-workflows"
            ;;
        *"argo"*"rollout"*)
            GITOPS_CHART_INFO["$key_repo"]="argo"
            GITOPS_CHART_INFO["$key_chart"]="argo-rollouts"
            ;;
        *"prometheus"*|*"kube-prometheus-stack"*)
            GITOPS_CHART_INFO["$key_repo"]="prometheus-community"
            GITOPS_CHART_INFO["$key_chart"]="kube-prometheus-stack"
            ;;
        *"grafana"*)
            GITOPS_CHART_INFO["$key_repo"]="grafana"
            GITOPS_CHART_INFO["$key_chart"]="grafana"
            ;;
        *"loki"*)
            GITOPS_CHART_INFO["$key_repo"]="grafana"
            GITOPS_CHART_INFO["$key_chart"]="loki"
            ;;
        *"jaeger"*)
            GITOPS_CHART_INFO["$key_repo"]="jaegertracing"
            GITOPS_CHART_INFO["$key_chart"]="jaeger"
            ;;
        *"minio"*)
            GITOPS_CHART_INFO["$key_repo"]="minio"
            GITOPS_CHART_INFO["$key_chart"]="minio"
            ;;
        *"gitea"*)
            GITOPS_CHART_INFO["$key_repo"]="gitea-charts"
            GITOPS_CHART_INFO["$key_chart"]="gitea"
            ;;
        *"kargo"*)
            GITOPS_CHART_INFO["$key_repo"]="kargo"
            GITOPS_CHART_INFO["$key_chart"]="kargo"
            ;;
        *)
            # Detección genérica: usar el nombre de la herramienta
            GITOPS_CHART_INFO["$key_repo"]="$herramienta"
            GITOPS_CHART_INFO["$key_chart"]="$herramienta"
            ;;
    esac
    
    echo "   🧠 Detección inteligente: ${GITOPS_CHART_INFO[$key_repo]:-unknown}/${GITOPS_CHART_INFO[$key_chart]:-unknown}"
}

# Función para buscar la última versión de un chart en tiempo real
buscar_ultima_version_chart() {
    local herramienta="$1"
    local key_repo="${herramienta}_repo"
    local key_chart="${herramienta}_chart"
    local repo="${GITOPS_CHART_INFO[$key_repo]:-}"
    local chart="${GITOPS_CHART_INFO[$key_chart]:-}"
    
    if [[ -z "$repo" || -z "$chart" ]]; then
        echo "latest"
        return
    fi
    
    echo "🔍 Buscando versión más reciente para $herramienta ($repo/$chart)..." >&2
    
    # Método 1: Buscar usando helm search repo (asegurar que el repo existe)
    local version=""
    if helm repo list 2>/dev/null | grep -q "^$repo"; then
        echo "   📦 Usando repositorio Helm: $repo" >&2
        version=$(helm search repo "$repo/$chart" --versions 2>/dev/null | awk 'NR==2 {print $2}')
    fi
    
    # Método 2: APIs de GitHub como fallback
    if [[ -z "$version" || "$version" == "No" || "$version" == "CHART" || "$version" == "results" ]]; then
        echo "   📡 Usando API de GitHub como fallback..." >&2
        case "$repo" in
            "ingress-nginx"|"kubernetes")
                version=$(curl -s https://api.github.com/repos/kubernetes/ingress-nginx/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/controller-//' 2>/dev/null)
                ;;
            "jetstack")
                version=$(curl -s https://api.github.com/repos/cert-manager/cert-manager/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                ;;
            "external-secrets")
                version=$(curl -s https://api.github.com/repos/external-secrets/external-secrets/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                ;;
            "argo")
                case "$chart" in
                    "argo-events")
                        version=$(curl -s https://api.github.com/repos/argoproj/argo-events/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                        ;;
                    "argo-workflows")
                        version=$(curl -s https://api.github.com/repos/argoproj/argo-workflows/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                        ;;
                    "argo-rollouts")
                        version=$(curl -s https://api.github.com/repos/argoproj/argo-rollouts/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                        ;;
                esac
                ;;
            "prometheus-community")
                # Para prometheus stack, usar una versión conocida estable
                version="65.1.1"
                ;;
            "grafana")
                version=$(curl -s https://api.github.com/repos/grafana/grafana/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/v//' 2>/dev/null)
                ;;
            *)
                version="latest"
                ;;
        esac
    fi
    
    # Método 3: Fallback a "latest" si todo falla
    if [[ -z "$version" ]]; then
        version="latest"
    fi
    
    echo "   ✅ Versión detectada: $version" >&2
    echo "$version"
}

# Función para configurar repositorios Helm dinámicamente
configurar_repositorios_helm() {
    echo "📡 Configurando repositorios Helm dinámicamente..."
    
    # Repositorios comunes basados en herramientas descubiertas
    declare -A repos_necesarios
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        local repo="${GITOPS_CHART_INFO[${herramienta}_repo]}"
        
        case "$repo" in
            "ingress-nginx")
                repos_necesarios["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx"
                ;;
            "jetstack")
                repos_necesarios["jetstack"]="https://charts.jetstack.io"
                ;;
            "external-secrets")
                repos_necesarios["external-secrets"]="https://charts.external-secrets.io"
                ;;
            "argo")
                repos_necesarios["argo"]="https://argoproj.github.io/argo-helm"
                ;;
            "prometheus-community")
                repos_necesarios["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
                ;;
            "grafana")
                repos_necesarios["grafana"]="https://grafana.github.io/helm-charts"
                ;;
            "jaegertracing")
                repos_necesarios["jaegertracing"]="https://jaegertracing.github.io/helm-charts"
                ;;
            "minio")
                repos_necesarios["minio"]="https://charts.min.io/"
                ;;
            "gitea-charts")
                repos_necesarios["gitea-charts"]="https://dl.gitea.io/charts/"
                ;;
            "kargo")
                repos_necesarios["kargo"]="https://charts.kargo.io"
                ;;
        esac
    done
    
    # Agregar repositorios dinámicamente
    for repo_name in "${!repos_necesarios[@]}"; do
        local repo_url="${repos_necesarios[$repo_name]}"
        echo "   📦 Agregando repositorio: $repo_name ($repo_url)"
        helm repo add "$repo_name" "$repo_url" >/dev/null 2>&1 || true
    done
    
    echo "   🔄 Actualizando repositorios..."
    helm repo update >/dev/null 2>&1
    
    echo "✅ Repositorios Helm configurados dinámicamente"
}

# Función principal de optimización GitOps dinámico
ejecutar_optimizacion_gitops() {
    echo "🚀 Iniciando optimización GitOps v3.0.0 - Sistema autodescubrible"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Paso 1: Autodescubrir herramientas
    autodescubrir_herramientas_gitops
    
    if [[ ${#GITOPS_TOOLS_DISCOVERED[@]} -eq 0 ]]; then
        echo "❌ No se encontraron herramientas GitOps en herramientas-gitops/"
        return 1
    fi
    
    # Paso 2: Configurar repositorios Helm dinámicamente
    configurar_repositorios_helm
    
    # Paso 3: Optimizar cada herramienta descubierta
    local contador=1
    local total_herramientas=${#GITOPS_TOOLS_DISCOVERED[@]}
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        echo
        echo "[$contador/$total_herramientas] 🛠️  Optimizando: $herramienta"
        echo "────────────────────────────────────────────────────────────────────"
        
        # Buscar versión más reciente dinámicamente
        local version_actual=$(buscar_ultima_version_chart "$herramienta")
        
        # Aplicar optimizaciones de desarrollo
        aplicar_optimizaciones_desarrollo "$herramienta" "$version_actual"
        
        ((contador++))
    done
    
    echo
    echo "✅ Optimización GitOps completada dinámicamente"
    echo "🔄 Sistema autodescubrible activo - nuevos YAMLs se detectarán automáticamente"
    echo "📊 Versiones actualizadas dinámicamente desde fuentes oficiales"
    
    # Paso 4: Commit y push de cambios antes de desplegar
    hacer_commit_push_cambios
    
    # Paso 5: Aplicar App of Tools a ArgoCD
    aplicar_app_of_tools
    
    # Paso 6: Esperar a que todas las aplicaciones estén Synced y Healthy
    echo
    echo "⏳ Esperando a que todas las herramientas GitOps estén Synced y Healthy..."
    esperar_aplicaciones_completas
}

# Función para esperar a que todas las aplicaciones estén Synced y Healthy
esperar_aplicaciones_completas() {
    local max_intentos=60  # 10 minutos máximo (60 intentos x 10 segundos)
    local contador=1
    local aplicaciones_esperadas=(
        "argo-events" "argo-rollouts" "argo-workflows" "cert-manager"
        "external-secrets" "gitea" "grafana" "ingress-nginx" "jaeger"
        "kargo" "loki" "minio" "prometheus-stack"
    )
    
    echo "🎯 Verificando estado de ${#aplicaciones_esperadas[@]} herramientas GitOps..."
    echo "⚠️  MODO ACTIVO: Diagnosticando y corrigiendo problemas automáticamente"
    
    while [[ $contador -le $max_intentos ]]; do
        echo "[$contador/$max_intentos] 🔍 Verificando estado de aplicaciones..."
        
        local todas_ok=true
        local aplicaciones_problematicas=()
        local aplicaciones_out_of_sync=()
        local aplicaciones_unhealthy=()
        
        # Verificar cada aplicación esperada
        for app in "${aplicaciones_esperadas[@]}"; do
            if ! kubectl get application "$app" -n argocd >/dev/null 2>&1; then
                todas_ok=false
                aplicaciones_problematicas+=("$app:NO_EXISTE")
                continue
            fi
            
            local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            if [[ "$sync_status" != "Synced" ]]; then
                todas_ok=false
                aplicaciones_out_of_sync+=("$app")
                aplicaciones_problematicas+=("$app:$sync_status/$health_status")
            elif [[ "$health_status" != "Healthy" ]]; then
                todas_ok=false
                aplicaciones_unhealthy+=("$app")
                aplicaciones_problematicas+=("$app:$sync_status/$health_status")
            fi
        done
        
        if [[ "$todas_ok" == "true" ]]; then
            echo
            echo "✅ ¡Todas las herramientas GitOps están Synced y Healthy!"
            mostrar_estado_final_aplicaciones
            return 0
        fi
        
        # Mostrar aplicaciones problemáticas (solo primeras 5 para no saturar log)
        if [[ ${#aplicaciones_problematicas[@]} -gt 0 ]]; then
            echo "   ⚠️  Aplicaciones pendientes: ${aplicaciones_problematicas[@]:0:5}"
            if [[ ${#aplicaciones_problematicas[@]} -gt 5 ]]; then
                echo "      ... y $((${#aplicaciones_problematicas[@]} - 5)) más"
            fi
        fi
        
        # CORRECCIONES ACTIVAS cada 3 intentos
        if [[ $((contador % 3)) -eq 0 ]]; then
            echo "   🔧 Aplicando correcciones activas..."
            
            # Forzar sincronización de aplicaciones OutOfSync
            if [[ ${#aplicaciones_out_of_sync[@]} -gt 0 ]]; then
                echo "   🔄 Forzando sincronización de aplicaciones OutOfSync..."
                for app in "${aplicaciones_out_of_sync[@]}"; do
                    echo "      🔄 Sincronizando: $app"
                    kubectl patch application "$app" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true}}}}}' >/dev/null 2>&1 || true
                done
            fi
            
            # Diagnosticar aplicaciones Unhealthy
            if [[ ${#aplicaciones_unhealthy[@]} -gt 0 ]]; then
                echo "   🩺 Diagnosticando aplicaciones Unhealthy..."
                diagnosticar_aplicaciones_unhealthy "${aplicaciones_unhealthy[@]}"
            fi
            
            # Verificar App of Tools principal
            verificar_app_of_tools
        fi
        
        # CORRECCIÓN PROFUNDA cada 10 intentos
        if [[ $((contador % 10)) -eq 0 ]]; then
            echo "   🚨 Aplicando corrección profunda..."
            correccion_profunda_aplicaciones
        fi
        
        echo "   ⏱️  Esperando 10 segundos antes del siguiente chequeo..."
        sleep 10
        ((contador++))
    done
    
    echo
    echo "❌ ¡TIMEOUT! Algunas aplicaciones no llegaron a estar Synced y Healthy"
    echo "📊 Estado final de aplicaciones:"
    mostrar_estado_final_aplicaciones
    echo "🔧 Intentando última corrección de emergencia..."
    correccion_emergencia_final
    return 1
}

# Función para diagnosticar aplicaciones Unhealthy
diagnosticar_aplicaciones_unhealthy() {
    local aplicaciones_unhealthy=("$@")
    
    for app in "${aplicaciones_unhealthy[@]}"; do
        echo "      🩺 Diagnosticando: $app"
        
        # Obtener información del estado
        local mensaje_health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.message}' 2>/dev/null || echo "")
        local conditions=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.conditions[*].message}' 2>/dev/null || echo "")
        
        echo "         Estado: $mensaje_health"
        if [[ -n "$conditions" ]]; then
            echo "         Condiciones: $conditions"
        fi
        
        # Verificar namespace de destino
        local target_namespace=$(kubectl get application "$app" -n argocd -o jsonpath='{.spec.destination.namespace}' 2>/dev/null || echo "")
        if [[ -n "$target_namespace" ]]; then
            if ! kubectl get namespace "$target_namespace" >/dev/null 2>&1; then
                echo "         🔧 Creando namespace faltante: $target_namespace"
                kubectl create namespace "$target_namespace" >/dev/null 2>&1 || true
            fi
        fi
        
        # Verificar recursos del namespace
        if [[ -n "$target_namespace" ]]; then
            local recursos_error=$(kubectl get events -n "$target_namespace" --field-selector type=Warning --no-headers 2>/dev/null | head -3)
            if [[ -n "$recursos_error" ]]; then
                echo "         ⚠️ Eventos de warning en $target_namespace:"
                echo "$recursos_error" | sed 's/^/            /'
            fi
        fi
    done
}

# Función para verificar App of Tools
verificar_app_of_tools() {
    echo "   🔍 Verificando App of Tools principal..."
    
    if ! kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
        echo "   🚨 App of Tools no encontrada, reaplicando..."
        if kubectl apply -f argo-apps/app-of-tools-gitops.yaml >/dev/null 2>&1; then
            echo "   ✅ App of Tools reaplicada"
        else
            echo "   ❌ Error reaplicando App of Tools"
        fi
    else
        local sync_status=$(kubectl get application app-of-tools-gitops -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        if [[ "$sync_status" != "Synced" ]]; then
            echo "   🔄 Forzando sincronización de App of Tools..."
            kubectl patch application app-of-tools-gitops -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true}}}}}' >/dev/null 2>&1 || true
        fi
    fi
}

# Función de corrección profunda
correccion_profunda_aplicaciones() {
    echo "      🔧 Corrección profunda iniciada..."
    
    # Refresh completo de ArgoCD
    echo "      🔄 Refrescando repositorio en ArgoCD..."
    kubectl patch application app-of-tools-gitops -n argocd --type merge -p '{"operation":{"refresh":{}}}' >/dev/null 2>&1 || true
    
    # Verificar estado de ArgoCD server
    if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | grep -q Running; then
        echo "      🚨 ArgoCD server problemático, reiniciando..."
        kubectl rollout restart deployment argocd-server -n argocd >/dev/null 2>&1 || true
    fi
    
    # Verificar conectividad del repositorio
    echo "      📡 Verificando conectividad del repositorio..."
    local repo_status=$(kubectl get applications -n argocd -o jsonpath='{.items[0].status.sourceType}' 2>/dev/null || echo "")
    if [[ "$repo_status" != "Git" ]]; then
        echo "      ⚠️ Problema de conectividad del repositorio detectado"
    fi
    
    # Limpiar aplicaciones en estado error
    echo "      🧹 Limpiando aplicaciones en estado error..."
    local apps_error=$(kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}:{.status.health.status}{"\n"}{end}' 2>/dev/null | grep ":Unknown\|:Missing" | cut -d: -f1)
    
    if [[ -n "$apps_error" ]]; then
        while read -r app; do
            if [[ -n "$app" ]]; then
                echo "      🔄 Recreando aplicación problemática: $app"
                kubectl patch application "$app" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true},"prune":true}}}}' >/dev/null 2>&1 || true
            fi
        done <<< "$apps_error"
    fi
}

# Función de corrección de emergencia final
correccion_emergencia_final() {
    echo "🚨 Ejecutando corrección de emergencia final..."
    
    # Verificar que al menos las herramientas críticas estén funcionando
    local herramientas_criticas=("grafana" "prometheus-stack" "ingress-nginx" "cert-manager")
    local criticas_ok=0
    
    for tool in "${herramientas_criticas[@]}"; do
        if kubectl get application "$tool" -n argocd >/dev/null 2>&1; then
            local sync_status=$(kubectl get application "$tool" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            local health_status=$(kubectl get application "$tool" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
                ((criticas_ok++))
                echo "   ✅ Crítica OK: $tool"
            else
                echo "   ❌ Crítica PROBLEMA: $tool ($sync_status/$health_status)"
                # Último intento de corrección
                kubectl patch application "$tool" -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"apply":{"force":true},"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1 || true
            fi
        else
            echo "   ❌ Crítica FALTANTE: $tool"
        fi
    done
    
    echo "📊 Herramientas críticas funcionando: $criticas_ok/${#herramientas_criticas[@]}"
    
    if [[ $criticas_ok -ge 2 ]]; then
        echo "✅ Al menos las herramientas críticas básicas están funcionando"
        echo "💡 El sistema puede continuar, herramientas adicionales se sincronizarán gradualmente"
        return 0
    else
        echo "❌ Demasiadas herramientas críticas fallando"
        return 1
    fi
}

# Función para forzar sincronización de aplicaciones OutOfSync

# Función para mostrar estado final detallado de aplicaciones
mostrar_estado_final_aplicaciones() {
    echo
    echo "📊 Estado detallado de todas las herramientas GitOps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local aplicaciones_esperadas=(
        "argo-events" "argo-rollouts" "argo-workflows" "cert-manager"
        "external-secrets" "gitea" "grafana" "ingress-nginx" "jaeger"
        "kargo" "loki" "minio" "prometheus-stack"
    )
    
    local total_apps=${#aplicaciones_esperadas[@]}
    local apps_synced=0
    local apps_healthy=0
    local apps_completas=0
    
    printf "%-18s %-12s %-12s %-15s\n" "APLICACIÓN" "SYNC" "HEALTH" "ESTADO"
    echo "──────────────────┼────────────┼────────────┼───────────────"
    
    for app in "${aplicaciones_esperadas[@]}"; do
        if ! kubectl get application "$app" -n argocd >/dev/null 2>&1; then
            printf "%-18s %-12s %-12s %-15s\n" "$app" "NO_EXISTE" "NO_EXISTE" "❌ FALTANTE"
            continue
        fi
        
        local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        # Contadores
        [[ "$sync_status" == "Synced" ]] && ((apps_synced++))
        [[ "$health_status" == "Healthy" ]] && ((apps_healthy++))
        [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]] && ((apps_completas++))
        
        # Estado visual
        local estado_visual="❌ PROBLEMA"
        if [[ "$sync_status" == "Synced" && "$health_status" == "Healthy" ]]; then
            estado_visual="✅ COMPLETO"
        elif [[ "$sync_status" == "Synced" ]]; then
            estado_visual="🔄 SYNC_OK"
        elif [[ "$health_status" == "Healthy" ]]; then
            estado_visual="⚠️ HEALTH_OK"
        fi
        
        printf "%-18s %-12s %-12s %-15s\n" "$app" "$sync_status" "$health_status" "$estado_visual"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📈 RESUMEN EJECUTIVO:"
    echo "   🎯 Aplicaciones completas (Synced + Healthy): $apps_completas/$total_apps"
    echo "   🔄 Aplicaciones sincronizadas: $apps_synced/$total_apps"
    echo "   💚 Aplicaciones saludables: $apps_healthy/$total_apps"
    
    local porcentaje_completas=$((apps_completas * 100 / total_apps))
    echo "   📊 Porcentaje de éxito: $porcentaje_completas%"
    
    if [[ $apps_completas -eq $total_apps ]]; then
        echo "   🎉 ¡TODAS LAS HERRAMIENTAS GITOPS ESTÁN OPERATIVAS!"
    elif [[ $apps_completas -ge $((total_apps * 80 / 100)) ]]; then
        echo "   ✅ La mayoría de herramientas están funcionando correctamente"
    elif [[ $apps_completas -ge $((total_apps * 50 / 100)) ]]; then
        echo "   ⚠️ Aproximadamente la mitad de herramientas están funcionando"
    else
        echo "   ❌ La mayoría de herramientas tienen problemas - requiere intervención"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Verificar configuración multi-cluster
    verificar_configuracion_multicluster
}

# Función para verificar que ArgoCD esté configurado para manejar múltiples clusters
verificar_configuracion_multicluster() {
    echo
    echo "🌐 Verificando configuración multi-cluster de ArgoCD..."
    
    local clusters_configurados
    clusters_configurados=$(kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster -o name 2>/dev/null | wc -l)
    
    echo "   📊 Clusters configurados en ArgoCD: $clusters_configurados"
    
    if [[ $clusters_configurados -eq 0 ]]; then
        echo "   ℹ️  Solo cluster local configurado (normal para entorno dev)"
        echo "   💡 Para multi-cluster, ejecutar configuración adicional en fases posteriores"
    else
        echo "   ✅ Configuración multi-cluster detectada"
        echo "   🔍 Clusters externos configurados:"
        kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster -o custom-columns="CLUSTER:.metadata.labels.argocd\.argoproj\.io/secret-type,SERVER:.data.server" 2>/dev/null | base64 -d 2>/dev/null || echo "   (Detalles no disponibles)"
    fi
    
    return 0
}

# Función para hacer commit y push de los cambios antes del despliegue
hacer_commit_push_cambios() {
    echo
    echo "🔄 Realizando commit y push de cambios de versiones..."
    
    # Verificar si hay cambios para commitear
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️  No hay cambios para commitear"
        return 0
    fi
    
    # Mostrar archivos modificados
    echo "📝 Archivos modificados:"
    git status --porcelain | head -10
    
    # Agregar todos los cambios
    echo "📦 Agregando cambios al staging..."
    git add .
    
    # Crear commit con mensaje descriptivo
    local fecha=$(date '+%Y-%m-%d %H:%M:%S')
    local mensaje="feat: actualización automática versiones GitOps - $fecha"
    
    echo "💾 Creando commit: $mensaje"
    if git commit -m "$mensaje"; then
        echo "✅ Commit creado exitosamente"
        
        # Hacer push a la rama actual
        local rama_actual=$(git branch --show-current)
        echo "🚀 Haciendo push a rama: $rama_actual"
        
        if git push origin "$rama_actual"; then
            echo "✅ Push completado exitosamente"
            echo "🌐 Cambios sincronizados con el repositorio remoto"
            
            # Esperar un momento para que GitHub procese los cambios
            echo "⏳ Esperando sincronización con GitHub (5 segundos)..."
            sleep 5
            
            return 0
        else
            echo "❌ Error al hacer push"
            echo "⚠️  Los cambios están commiteados localmente pero no sincronizados"
            return 1
        fi
    else
        echo "❌ Error al crear commit"
        return 1
    fi
}

# Función para aplicar la App of Tools a ArgoCD
aplicar_app_of_tools() {
    echo
    echo "🚀 Aplicando App of Tools a ArgoCD..."
    
    local app_tools_file="argo-apps/app-of-tools-gitops.yaml"
    
    if [[ ! -f "$app_tools_file" ]]; then
        echo "❌ Archivo $app_tools_file no encontrado"
        return 1
    fi
    
    echo "📋 Aplicando $app_tools_file..."
    if kubectl apply -f "$app_tools_file"; then
        echo "✅ App of Tools aplicada exitosamente"
        
        # Verificar que la aplicación se creó
        echo "🔍 Verificando aplicación en ArgoCD..."
        sleep 3
        if kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
            echo "✅ Aplicación app-of-tools-gitops creada en ArgoCD"
            
            # Mostrar estado inicial
            echo "📊 Estado inicial de la aplicación:"
            kubectl get application app-of-tools-gitops -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" 2>/dev/null || echo "   (Estado aún no disponible)"
        else
            echo "⚠️ Aplicación creada pero aún no visible en ArgoCD"
        fi
    else
        echo "❌ Error al aplicar App of Tools"
        return 1
    fi
    
    return 0
}

# Función para aplicar optimizaciones específicas de desarrollo
aplicar_optimizaciones_desarrollo() {
    local herramienta="$1"
    local version="$2"
    local archivo_yaml="herramientas-gitops/${herramienta}.yaml"
    
    echo "   ⚙️  Aplicando optimizaciones de desarrollo..."
    echo "   📦 Versión objetivo: $version"
    
    # Actualizar la versión en el archivo YAML si es diferente de "latest"
    if [[ "$version" != "latest" && -f "$archivo_yaml" ]]; then
        echo "   🔄 Actualizando versión en $archivo_yaml..."
        
        # Crear backup del archivo original
        cp "$archivo_yaml" "${archivo_yaml}.backup"
        
        # Actualizar targetRevision si existe
        if grep -q "targetRevision:" "$archivo_yaml"; then
            sed -i "s/targetRevision:.*/targetRevision: \"$version\"/" "$archivo_yaml"
            echo "   ✅ targetRevision actualizado a: $version"
        else
            echo "   ℹ️  No se encontró targetRevision en el archivo"
        fi
        
        # Verificar si el cambio se aplicó
        local version_actualizada=$(grep "targetRevision:" "$archivo_yaml" | sed 's/.*targetRevision:\s*//' | tr -d '"' | tr -d "'")
        if [[ "$version_actualizada" == "$version" ]]; then
            echo "   ✅ Versión verificada en archivo: $version_actualizada"
            rm -f "${archivo_yaml}.backup"  # Eliminar backup si todo salió bien
        else
            echo "   ⚠️  La actualización no se reflejó correctamente"
            mv "${archivo_yaml}.backup" "$archivo_yaml"  # Restaurar backup
        fi
    fi
    
    # Crear directorio para valores de desarrollo si no existe
    local dir_values_dev="herramientas-gitops/values-dev"
    mkdir -p "$dir_values_dev"
    
    # Archivo de valores de desarrollo en el repositorio
    local valores_dev_file="$dir_values_dev/${herramienta}-dev-values.yaml"
    
    # Configuraciones optimizadas basadas en el tipo de herramienta
    case "$herramienta" in
        *"ingress"*|*"nginx"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Ingress NGINX
controller:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  service:
    type: NodePort
  admissionWebhooks:
    enabled: false
EOF
            ;;
        *"prometheus"*|*"kube-prometheus-stack"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Prometheus Stack
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    retention: 7d
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 2Gi
grafana:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  persistence:
    enabled: false
  testFramework:
    enabled: false
  adminPassword: admin123
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
EOF
            ;;
        *"grafana"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Grafana
adminUser: admin
adminPassword: admin123
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
persistence:
  enabled: true
  size: 1Gi
testFramework:
  enabled: false
serviceMonitor:
  enabled: false
EOF
            ;;
        *"loki"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Loki
deploymentMode: SingleBinary
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  auth_enabled: false
singleBinary:
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
  persistence:
    size: 2Gi
test:
  enabled: false
monitoring:
  selfMonitoring:
    enabled: false
  serviceMonitor:
    enabled: false
EOF
            ;;
        *"jaeger"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Jaeger
provisionDataStore:
  cassandra: false
  elasticsearch: false
allInOne:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
storage:
  type: memory
agent:
  enabled: false
collector:
  enabled: false
query:
  enabled: false
EOF
            ;;
        *"minio"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - MinIO
mode: standalone
rootUser: admin
rootPassword: admin123
replicas: 1
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 200m
    memory: 512Mi
persistence:
  enabled: true
  size: 2Gi
service:
  type: ClusterIP
consoleService:
  type: ClusterIP
EOF
            ;;
        *"gitea"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Gitea
gitea:
  admin:
    username: admin
    password: admin123
    email: admin@local.dev
  config:
    database:
      DB_TYPE: sqlite3
    session:
      PROVIDER: memory
    cache:
      ENABLED: false
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 200m
    memory: 512Mi
persistence:
  enabled: true
  size: 2Gi
postgresql:
  enabled: false
mysql:
  enabled: false
EOF
            ;;
        *"cert-manager"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Cert-Manager
installCRDs: true
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
webhook:
  resources:
    requests:
      cpu: 20m
      memory: 32Mi
    limits:
      cpu: 50m
      memory: 64Mi
cainjector:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
EOF
            ;;
        *"external-secrets"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - External Secrets
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
replicaCount: 1
webhook:
  resources:
    requests:
      cpu: 20m
      memory: 32Mi
    limits:
      cpu: 50m
      memory: 64Mi
certController:
  resources:
    requests:
      cpu: 20m
      memory: 32Mi
    limits:
      cpu: 50m
      memory: 64Mi
EOF
            ;;
        *"argo"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Argo (Events/Workflows/Rollouts)
controller:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
server:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
EOF
            ;;
        *"kargo"*)
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - Kargo
api:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
controller:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
webhooksServer:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
EOF
            ;;
        *)
            # Configuración genérica optimizada para desarrollo
            cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - $herramienta
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
replicaCount: 1
EOF
            ;;
    esac
    
    echo "   💾 Configuración optimizada guardada en $valores_dev_file"
    echo "   🎯 Recursos mínimos aplicados para entorno de desarrollo"
    
    # Actualizar el YAML principal para referenciar los valores de desarrollo
    actualizar_referencia_valores_dev "$archivo_yaml" "$valores_dev_file" "$herramienta"
    
    return 0
}

# Función para actualizar la referencia a valores de desarrollo en el YAML principal
actualizar_referencia_valores_dev() {
    local archivo_yaml="$1"
    local valores_dev_file="$2"
    local herramienta="$3"
    
    echo "   🔧 Actualizando referencia a valores de desarrollo..."
    
    # Crear backup
    cp "$archivo_yaml" "${archivo_yaml}.backup"
    
    # Buscar si ya existe una sección helm.valueFiles o helm.values
    if grep -q "helm:" "$archivo_yaml"; then
        # Ya existe sección helm, agregar/actualizar valueFiles
        if grep -q "valueFiles:" "$archivo_yaml"; then
            echo "   ⚠️  valueFiles ya existe, verificando contenido..."
        else
            # Agregar valueFiles después de la sección helm
            sed -i '/helm:/a\      valueFiles:\n        - values-dev/'$herramienta'-dev-values.yaml' "$archivo_yaml"
            echo "   ✅ Agregada referencia a valores de desarrollo"
        fi
    else
        echo "   ℹ️  No se encontró sección helm en $archivo_yaml"
        echo "   💡 Para aplicar valores de desarrollo, agregue sección helm manualmente"
    fi
    
    # Verificar cambios
    if grep -q "values-dev/${herramienta}-dev-values.yaml" "$archivo_yaml"; then
        echo "   ✅ Referencia a valores de desarrollo confirmada"
        rm -f "${archivo_yaml}.backup"
    else
        echo "   ⚠️  No se pudo agregar la referencia automáticamente"
        mv "${archivo_yaml}.backup" "$archivo_yaml"
    fi
}

# Función para mostrar resumen de herramientas descubiertas
mostrar_resumen_herramientas() {
    echo "📋 Resumen de herramientas GitOps autodescubiertas:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        local repo="${GITOPS_CHART_INFO[${herramienta}_repo]}"
        local chart="${GITOPS_CHART_INFO[${herramienta}_chart]}"
        echo "   📦 $herramienta → $repo/$chart"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: ${#GITOPS_TOOLS_DISCOVERED[@]} herramientas"
}

