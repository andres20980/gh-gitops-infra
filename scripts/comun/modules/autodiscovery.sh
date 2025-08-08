#!/bin/bash
# ============================================================================
# MÓDULO DE AUTODESCUBRIMIENTO GITOPS - v3.0.0
# ============================================================================
# Especializado en descubrimiento automático de herramientas GitOps
# Máximo: 300 líneas - Principio de Responsabilidad Única

set +u  # Desactivar verificación de variables no definidas

# Arrays globales para autodescubrimiento
declare -a GITOPS_TOOLS_DISCOVERED
declare -A GITOPS_CHART_INFO

# Función principal de autodescubrimiento
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
    
    # Buscar información del repositorio Helm en el YAML
    local repo_url=$(grep -E '^\s*repoURL:' "$archivo_yaml" | head -1 | sed 's/.*repoURL:\s*//' | tr -d '"' | tr -d "'")
    local chart_name=$(grep -E '^\s*chart:' "$archivo_yaml" | head -1 | sed 's/.*chart:\s*//' | tr -d '"' | tr -d "'")
    
    # Si no hay información del chart, usar detección inteligente
    if [[ -z "$repo_url" || -z "$chart_name" ]]; then
        echo "   ⚠️  No se encontró info de chart en $archivo_yaml, usando detección inteligente"
        detectar_chart_inteligente "$herramienta"
    else
        # Extraer nombre del repositorio de la URL - manejo seguro
        local repo_name
        repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|\.github\.io/.*||' | sed 's|.*github\.com/||' | sed 's|/.*||' 2>/dev/null || echo "unknown")
        
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

# Función para mostrar resumen de herramientas descubiertas
mostrar_resumen_herramientas() {
    echo "📋 Resumen de herramientas GitOps autodescubiertas:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        local key_repo="${herramienta}_repo"
        local key_chart="${herramienta}_chart"
        local repo="${GITOPS_CHART_INFO[$key_repo]:-unknown}"
        local chart="${GITOPS_CHART_INFO[$key_chart]:-unknown}"
        echo "   📦 $herramienta → $repo/$chart"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: ${#GITOPS_TOOLS_DISCOVERED[@]} herramientas"
}
