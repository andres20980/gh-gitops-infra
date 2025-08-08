#!/bin/bash
# ============================================================================
# MÓDULO DE GESTIÓN DE VERSIONES GITOPS - v3.0.0
# ============================================================================
# Especializado en búsqueda y gestión de versiones de charts
# Máximo: 300 líneas - Principio de Responsabilidad Única

set +u  # Desactivar verificación de variables no definidas

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
    
    # Método 1: Buscar usando helm search repo
    local version=""
    if helm repo list 2>/dev/null | grep -q "^$repo"; then
        echo "   📦 Usando repositorio Helm: $repo" >&2
        version=$(helm search repo "$repo/$chart" --versions 2>/dev/null | awk 'NR==2 {print $2}')
    fi
    
    # Método 2: APIs de GitHub como fallback
    if [[ -z "$version" || "$version" == "No" || "$version" == "CHART" || "$version" == "results" ]]; then
        echo "   📡 Usando API de GitHub como fallback..." >&2
        version=$(buscar_version_desde_github "$repo" "$chart")
    fi
    
    # Método 3: Fallback a "latest" si todo falla
    if [[ -z "$version" ]]; then
        version="latest"
    fi
    
    echo "   ✅ Versión detectada: $version" >&2
    echo "$version"
}

# Función especializada para buscar versiones desde GitHub API
buscar_version_desde_github() {
    local repo="$1"
    local chart="$2"
    local version=""
    
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
            version=$(buscar_version_argo "$chart")
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
    
    echo "$version"
}

# Función especializada para versiones de Argo
buscar_version_argo() {
    local chart="$1"
    local version=""
    
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
        *)
            version="latest"
            ;;
    esac
    
    echo "$version"
}

# Función para configurar repositorios Helm dinámicamente
configurar_repositorios_helm() {
    echo "📡 Configurando repositorios Helm dinámicamente..."
    
    # Repositorios comunes basados en herramientas descubiertas
    declare -A repos_necesarios
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        local key_repo="${herramienta}_repo"
        local repo="${GITOPS_CHART_INFO[$key_repo]:-}"
        
        # Mapear repositorios
        mapear_repositorio_helm "$repo" repos_necesarios
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

# Función para mapear repositorios Helm
mapear_repositorio_helm() {
    local repo="$1"
    local -n repos_ref="$2"
    
    case "$repo" in
        "ingress-nginx")
            repos_ref["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx"
            ;;
        "jetstack")
            repos_ref["jetstack"]="https://charts.jetstack.io"
            ;;
        "external-secrets")
            repos_ref["external-secrets"]="https://charts.external-secrets.io"
            ;;
        "argo")
            repos_ref["argo"]="https://argoproj.github.io/argo-helm"
            ;;
        "prometheus-community")
            repos_ref["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
            ;;
        "grafana")
            repos_ref["grafana"]="https://grafana.github.io/helm-charts"
            ;;
        "jaegertracing")
            repos_ref["jaegertracing"]="https://jaegertracing.github.io/helm-charts"
            ;;
        "minio")
            repos_ref["minio"]="https://charts.min.io/"
            ;;
        "gitea-charts")
            repos_ref["gitea-charts"]="https://dl.gitea.io/charts/"
            ;;
        "kargo")
            repos_ref["kargo"]="https://charts.kargo.io"
            ;;
    esac
}
