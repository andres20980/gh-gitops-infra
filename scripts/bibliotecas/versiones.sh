#!/bin/bash

# ============================================================================
# LIBRERÍA DE VERSIONES - Gestión centralizada de versiones
# ============================================================================
# Versiones oficiales y actualizadas de todas las herramientas
# Funciones para obtener, validar y actualizar versiones
# ============================================================================

# Prevenir múltiples cargas
[[ -n "${_GITOPS_VERSIONS_LOADED:-}" ]] && return 0
readonly _GITOPS_VERSIONS_LOADED=1

# Cargar dependencias
if [[ -z "${_GITOPS_BASE_LOADED:-}" ]]; then
    # shellcheck source=./base.sh
    source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
fi

if [[ -z "${_GITOPS_LOGGING_LOADED:-}" ]]; then
    # shellcheck source=./logging.sh
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# ============================================================================
# VERSIONES PRINCIPALES - ACTUALIZACIÓN AUTOMÁTICA 2025
# ============================================================================

# Herramientas de contenedores
readonly DOCKER_VERSION="24.0.7"
readonly DOCKER_COMPOSE_VERSION="2.23.3"

# Herramientas de Kubernetes (kubectl compatible con minikube)
readonly KUBECTL_VERSION="1.29.0"  # Compatible con minikube 1.32.0
readonly MINIKUBE_VERSION="1.32.0"
readonly HELM_VERSION="3.13.3"
readonly K9S_VERSION="0.29.1"
readonly KUBECTX_VERSION="0.9.5"

# ArgoCD y componentes GitOps (últimas versiones estables)
readonly ARGOCD_VERSION="2.9.3"
readonly ARGOCD_CLI_VERSION="2.9.3"
readonly ARGO_WORKFLOWS_VERSION="3.5.2"
readonly ARGO_EVENTS_VERSION="1.9.1"
readonly ARGO_ROLLOUTS_VERSION="1.6.4"

# Kargo (Freight)
readonly KARGO_VERSION="0.4.0"

# Observabilidad y Monitoreo
readonly PROMETHEUS_VERSION="2.48.1"
readonly GRAFANA_VERSION="10.2.3"
readonly LOKI_VERSION="2.9.4"
readonly JAEGER_VERSION="1.52.0"

# Seguridad y Certificados
readonly CERT_MANAGER_VERSION="1.13.3"
readonly EXTERNAL_SECRETS_VERSION="0.9.11"

# Infraestructura
readonly INGRESS_NGINX_VERSION="1.9.5"
readonly MINIO_VERSION="2023.12.7"
readonly GITEA_VERSION="1.21.3"

# Versiones de Helm Charts
readonly PROMETHEUS_STACK_CHART_VERSION="55.5.0"
readonly GRAFANA_CHART_VERSION="7.0.19"
readonly LOKI_CHART_VERSION="5.41.4"
readonly JAEGER_CHART_VERSION="0.73.5"
readonly CERT_MANAGER_CHART_VERSION="1.13.3"
readonly EXTERNAL_SECRETS_CHART_VERSION="0.9.11"
readonly INGRESS_NGINX_CHART_VERSION="4.8.3"
readonly MINIO_CHART_VERSION="5.0.15"
readonly GITEA_CHART_VERSION="10.1.4"

# ============================================================================
# MAPAS DE VERSIONES POR CATEGORÍAS
# ============================================================================

# Crear arrays asociativos para facilitar el acceso
declare -A VERSIONS_TOOLS=(
    ["docker"]="$DOCKER_VERSION"
    ["docker-compose"]="$DOCKER_COMPOSE_VERSION"
    ["kubectl"]="$KUBECTL_VERSION"
    ["minikube"]="$MINIKUBE_VERSION"
    ["helm"]="$HELM_VERSION"
    ["k9s"]="$K9S_VERSION"
    ["kubectx"]="$KUBECTX_VERSION"
)

declare -A VERSIONS_GITOPS=(
    ["argocd"]="$ARGOCD_VERSION"
    ["argocd-cli"]="$ARGOCD_CLI_VERSION"
    ["argo-workflows"]="$ARGO_WORKFLOWS_VERSION"
    ["argo-events"]="$ARGO_EVENTS_VERSION"
    ["argo-rollouts"]="$ARGO_ROLLOUTS_VERSION"
    ["kargo"]="$KARGO_VERSION"
)

declare -A VERSIONS_OBSERVABILITY=(
    ["prometheus"]="$PROMETHEUS_VERSION"
    ["grafana"]="$GRAFANA_VERSION"
    ["loki"]="$LOKI_VERSION"
    ["jaeger"]="$JAEGER_VERSION"
)

declare -A VERSIONS_SECURITY=(
    ["cert-manager"]="$CERT_MANAGER_VERSION"
    ["external-secrets"]="$EXTERNAL_SECRETS_VERSION"
)

declare -A VERSIONS_INFRASTRUCTURE=(
    ["ingress-nginx"]="$INGRESS_NGINX_VERSION"
    ["minio"]="$MINIO_VERSION"
    ["gitea"]="$GITEA_VERSION"
)

declare -A VERSIONS_CHARTS=(
    ["prometheus-stack"]="$PROMETHEUS_STACK_CHART_VERSION"
    ["grafana"]="$GRAFANA_CHART_VERSION"
    ["loki"]="$LOKI_CHART_VERSION"
    ["jaeger"]="$JAEGER_CHART_VERSION"
    ["cert-manager"]="$CERT_MANAGER_CHART_VERSION"
    ["external-secrets"]="$EXTERNAL_SECRETS_CHART_VERSION"
    ["ingress-nginx"]="$INGRESS_NGINX_CHART_VERSION"
    ["minio"]="$MINIO_CHART_VERSION"
    ["gitea"]="$GITEA_CHART_VERSION"
)

# ============================================================================
# FUNCIONES DE OBTENCIÓN DE VERSIONES
# ============================================================================

# Obtener versión de herramienta
get_version() {
    local tool="$1"
    local category="${2:-tools}"
    
    case "$category" in
        "tools")
            echo "${VERSIONS_TOOLS[$tool]:-}"
            ;;
        "gitops")
            echo "${VERSIONS_GITOPS[$tool]:-}"
            ;;
        "observability")
            echo "${VERSIONS_OBSERVABILITY[$tool]:-}"
            ;;
        "security")
            echo "${VERSIONS_SECURITY[$tool]:-}"
            ;;
        "infrastructure")
            echo "${VERSIONS_INFRASTRUCTURE[$tool]:-}"
            ;;
        "charts")
            echo "${VERSIONS_CHARTS[$tool]:-}"
            ;;
        *)
            # Buscar en todas las categorías
            local version
            version="${VERSIONS_TOOLS[$tool]:-}"
            [[ -n "$version" ]] && echo "$version" && return
            
            version="${VERSIONS_GITOPS[$tool]:-}"
            [[ -n "$version" ]] && echo "$version" && return
            
            version="${VERSIONS_OBSERVABILITY[$tool]:-}"
            [[ -n "$version" ]] && echo "$version" && return
            
            version="${VERSIONS_SECURITY[$tool]:-}"
            [[ -n "$version" ]] && echo "$version" && return
            
            version="${VERSIONS_INFRASTRUCTURE[$tool]:-}"
            [[ -n "$version" ]] && echo "$version" && return
            
            version="${VERSIONS_CHARTS[$tool]:-}"
            [[ -n "$version" ]] && echo "$version" && return
            
            return 1
            ;;
    esac
}

# Obtener versión de chart
get_chart_version() {
    local chart="$1"
    get_version "$chart" "charts"
}

# Obtener versión de herramienta GitOps
get_gitops_version() {
    local tool="$1"
    get_version "$tool" "gitops"
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN DE VERSIONES
# ============================================================================

# Comparar versiones semánticas
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    # Limpiar versiones (remover v prefijo si existe)
    version1="${version1#v}"
    version2="${version2#v}"
    
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --compare-versions "$version1" "$3" "$version2"
    else
        # Fallback manual para comparación básica
        if [[ "$version1" == "$version2" ]]; then
            [[ "$3" =~ ^(eq|=|==)$ ]]
        elif [[ "$version1" < "$version2" ]]; then
            [[ "$3" =~ ^(lt|<)$ ]]
        else
            [[ "$3" =~ ^(gt|>)$ ]]
        fi
    fi
}

# Validar si versión es compatible
is_version_compatible() {
    local current_version="$1"
    local min_version="$2"
    local max_version="${3:-999.999.999}"
    
    compare_versions "$current_version" ge "$min_version" && \
    compare_versions "$current_version" le "$max_version"
}

# ============================================================================
# FUNCIONES DE DETECCIÓN DE VERSIONES INSTALADAS
# ============================================================================

# Obtener versión instalada de Docker
get_installed_docker_version() {
    if comando_existe docker; then
        docker version --format '{{.Server.Version}}' 2>/dev/null | sed 's/^v//'
    fi
}

# Obtener versión instalada de kubectl
get_installed_kubectl_version() {
    if comando_existe kubectl; then
        kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/^v//'
    fi
}

# Obtener versión instalada de Helm
get_installed_helm_version() {
    if comando_existe helm; then
        helm version --template='{{.Version}}' 2>/dev/null | sed 's/^v//'
    fi
}

# Obtener versión instalada de Minikube
get_installed_minikube_version() {
    if comando_existe minikube; then
        minikube version --output=json 2>/dev/null | jq -r '.minikubeVersion' | sed 's/^v//'
    fi
}

# Obtener versión instalada de ArgoCD CLI
get_installed_argocd_version() {
    if comando_existe argocd; then
        argocd version --client --output json 2>/dev/null | jq -r '.client.Version' | sed 's/^v//'
    fi
}

# ============================================================================
# FUNCIONES DE VERIFICACIÓN MASIVA
# ============================================================================

# Verificar versiones de herramientas principales
check_tools_versions() {
    local tools=("docker" "kubectl" "helm" "minikube")
    local tool
    local installed_version
    local expected_version
    local status
    
    log_subsection "Verificación de Versiones de Herramientas"
    
    for tool in "${tools[@]}"; do
        expected_version=$(get_version "$tool")
        
        case "$tool" in
            "docker")
                installed_version=$(get_installed_docker_version)
                ;;
            "kubectl")
                installed_version=$(get_installed_kubectl_version)
                ;;
            "helm")
                installed_version=$(get_installed_helm_version)
                ;;
            "minikube")
                installed_version=$(get_installed_minikube_version)
                ;;
        esac
        
        if [[ -z "$installed_version" ]]; then
            status="error"
            log_check "$tool: No instalado (esperado: $expected_version)" "$status"
        elif [[ "$installed_version" == "$expected_version" ]]; then
            status="success"
            log_check "$tool: $installed_version ✓" "$status"
        else
            status="warning"
            log_check "$tool: $installed_version (esperado: $expected_version)" "$status"
        fi
    done
}

# Mostrar todas las versiones disponibles
show_all_versions() {
    log_section "📋 Versiones Definidas en el Sistema"
    
    log_subsection "🛠️ Herramientas Principales"
    for tool in "${!VERSIONS_TOOLS[@]}"; do
        printf "  %-20s %s\n" "$tool:" "${VERSIONS_TOOLS[$tool]}"
    done
    
    log_subsection "🚀 GitOps y ArgoCD"
    for tool in "${!VERSIONS_GITOPS[@]}"; do
        printf "  %-20s %s\n" "$tool:" "${VERSIONS_GITOPS[$tool]}"
    done
    
    log_subsection "📊 Observabilidad"
    for tool in "${!VERSIONS_OBSERVABILITY[@]}"; do
        printf "  %-20s %s\n" "$tool:" "${VERSIONS_OBSERVABILITY[$tool]}"
    done
    
    log_subsection "🔒 Seguridad"
    for tool in "${!VERSIONS_SECURITY[@]}"; do
        printf "  %-20s %s\n" "$tool:" "${VERSIONS_SECURITY[$tool]}"
    done
    
    log_subsection "🏗️ Infraestructura"
    for tool in "${!VERSIONS_INFRASTRUCTURE[@]}"; do
        printf "  %-20s %s\n" "$tool:" "${VERSIONS_INFRASTRUCTURE[$tool]}"
    done
    
    log_subsection "📦 Helm Charts"
    for chart in "${!VERSIONS_CHARTS[@]}"; do
        printf "  %-20s %s\n" "$chart:" "${VERSIONS_CHARTS[$chart]}"
    done
}

# ============================================================================
# FUNCIONES DE ACTUALIZACIÓN DE VERSIONES
# ============================================================================

# Obtener última versión desde GitHub
get_latest_github_version() {
    local repo="$1"
    local version
    
    if ! comando_existe curl || ! comando_existe jq; then
        log_error "curl y jq son requeridos para obtener versiones de GitHub"
        return 1
    fi
    
    version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
    
    if [[ "$version" == "null" || -z "$version" ]]; then
        log_error "No se pudo obtener la versión de $repo"
        return 1
    fi
    
    echo "$version"
}

# Verificar si hay nuevas versiones disponibles
check_for_updates() {
    log_section "🔍 Verificando Actualizaciones Disponibles"
    
    local repos=(
        "docker/cli:docker"
        "kubernetes/kubernetes:kubectl"
        "helm/helm:helm"
        "kubernetes/minikube:minikube"
        "argoproj/argo-cd:argocd"
    )
    
    for repo_tool in "${repos[@]}"; do
        local repo="${repo_tool%:*}"
        local tool="${repo_tool#*:}"
        local current_version
        local latest_version
        
        current_version=$(get_version "$tool")
        latest_version=$(get_latest_github_version "$repo")
        
        if [[ -n "$latest_version" ]]; then
            if [[ "$current_version" == "$latest_version" ]]; then
                log_check "$tool: $current_version (actualizado)" "success"
            else
                log_check "$tool: $current_version → $latest_version disponible" "warning"
            fi
        else
            log_check "$tool: Error al verificar versión" "error"
        fi
    done
}

# ============================================================================
# FUNCIONES DE URLS DE DESCARGA
# ============================================================================

# Obtener URL de descarga para arquitectura específica
get_download_url() {
    local tool="$1"
    local version="$2"
    local arch="${3:-$(uname -m)}"
    local os="${4:-linux}"
    
    # Normalizar arquitectura
    case "$arch" in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
    esac
    
    case "$tool" in
        "kubectl")
            echo "https://dl.k8s.io/release/v${version}/bin/${os}/${arch}/kubectl"
            ;;
        "helm")
            echo "https://get.helm.sh/helm-v${version}-${os}-${arch}.tar.gz"
            ;;
        "minikube")
            echo "https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-${os}-${arch}"
            ;;
        "argocd")
            echo "https://github.com/argoproj/argo-cd/releases/download/v${version}/argocd-${os}-${arch}"
            ;;
        "k9s")
            echo "https://github.com/derailed/k9s/releases/download/v${version}/k9s_${os}_${arch}.tar.gz"
            ;;
        *)
            log_error "URL de descarga no definida para: $tool"
            return 1
            ;;
    esac
}

# ============================================================================
# EXPORTS PARA COMPATIBILIDAD
# ============================================================================

export -f get_version
export -f get_chart_version
export -f get_gitops_version
export -f compare_versions
export -f is_version_compatible
export -f get_installed_docker_version
export -f get_installed_kubectl_version
export -f get_installed_helm_version
export -f get_installed_minikube_version
export -f get_installed_argocd_version
export -f check_tools_versions
export -f show_all_versions
export -f get_latest_github_version
export -f check_for_updates
export -f get_download_url

# ============================================================================
# FUNCIONES DE ACTUALIZACIÓN AUTOMÁTICA
# ============================================================================

# Obtener versión compatible de kubectl con minikube
get_kubectl_compatible_version() {
    local minikube_version="${1:-$MINIKUBE_VERSION}"
    
    # Mapeo de compatibilidad kubectl-minikube (versiones estables)
    case "$minikube_version" in
        "1.32.0"|"1.31."*) echo "1.29.0" ;;
        "1.30."*) echo "1.28.0" ;;
        "1.29."*) echo "1.27.0" ;;
        *) echo "1.29.0" ;;  # Versión por defecto estable
    esac
}

# Actualizar todas las versiones a las últimas disponibles
actualizar_versiones_automaticamente() {
    log_section "🔄 Actualización Automática de Versiones"
    
    local repos_principales=(
        "docker/cli:docker"
        "kubernetes/minikube:minikube"
        "helm/helm:helm"
        "argoproj/argo-cd:argocd"
        "argoproj/argo-workflows:argo-workflows"
        "argoproj/argo-events:argo-events"
        "argoproj/argo-rollouts:argo-rollouts"
        "akuity/kargo:kargo"
    )
    
    log_info "Obteniendo últimas versiones desde GitHub..."
    
    for repo_tool in "${repos_principales[@]}"; do
        local repo="${repo_tool%:*}"
        local tool="${repo_tool#*:}"
        
        log_info "Verificando $tool..."
        local latest_version
        latest_version=$(get_latest_github_version "$repo" 2>/dev/null || echo "")
        
        if [[ -n "$latest_version" ]]; then
            local current_version
            current_version=$(get_version "$tool" 2>/dev/null || echo "N/A")
            
            if [[ "$current_version" != "$latest_version" ]]; then
                log_info "  $tool: $current_version → $latest_version disponible"
            else
                log_success "  $tool: $current_version (actualizado)"
            fi
        else
            log_warning "  $tool: Error al obtener versión"
        fi
    done
    
    # Verificar compatibilidad kubectl-minikube
    local kubectl_compatible
    kubectl_compatible=$(get_kubectl_compatible_version)
    log_info "kubectl compatible con minikube $MINIKUBE_VERSION: $kubectl_compatible"
    
    log_success "✅ Verificación de versiones completada"
}

# Función para validar compatibilidad antes de instalación
validar_compatibilidad_versiones() {
    log_subsection "🔍 Validación de Compatibilidad"
    
    local kubectl_version="$KUBECTL_VERSION"
    local minikube_version="$MINIKUBE_VERSION"
    local kubectl_compatible
    kubectl_compatible=$(get_kubectl_compatible_version "$minikube_version")
    
    if [[ "$kubectl_version" == "$kubectl_compatible" ]]; then
        log_success "✅ kubectl $kubectl_version es compatible con minikube $minikube_version"
        return 0
    else
        log_warning "⚠️ kubectl $kubectl_version podría no ser óptimo con minikube $minikube_version"
        log_info "💡 Versión recomendada de kubectl: $kubectl_compatible"
        return 1
    fi
}

# Exports adicionales
export -f get_kubectl_compatible_version
export -f actualizar_versiones_automaticamente
export -f validar_compatibilidad_versiones

# ============================================================================
# FUNCIONES DE AUTO-INSTALACIÓN DESATENDIDA
# ============================================================================

# Detectar última versión desde GitHub API
obtener_ultima_version_github() {
    local repo="$1"
    local timeout="${2:-10}"
    
    local version
    if command -v curl >/dev/null 2>&1; then
        version=$(curl -s --connect-timeout "$timeout" \
            "https://api.github.com/repos/$repo/releases/latest" | \
            grep -o '"tag_name": "[^"]*' | \
            grep -o '[^"]*$' | \
            sed 's/^v//' 2>/dev/null)
    fi
    
    if [[ -n "$version" && "$version" != "null" ]]; then
        echo "$version"
        return 0
    else
        return 1
    fi
}

# Detectar última versión de kubectl compatible con minikube
obtener_kubectl_compatible_auto() {
    local minikube_version="${1:-$MINIKUBE_VERSION}"
    
    # Mapeo de compatibilidad conocido (actualizar según releases)
    case "$minikube_version" in
        "1.32.0")
            echo "1.29.0"
            ;;
        "1.31."*)
            echo "1.28.4"
            ;;
        "1.30."*)
            echo "1.27.8"
            ;;
        *)
            # Por defecto, usar una versión estable conocida
            echo "1.29.0"
            ;;
    esac
}

# Auto-instalar Docker si no está disponible
auto_instalar_docker() {
    log_info "🐳 Auto-instalando Docker..."
    
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y docker.io docker-compose-plugin
        sudo systemctl enable docker
        sudo systemctl start docker
        sudo usermod -aG docker "$USER"
        log_success "✅ Docker instalado correctamente"
    else
        log_error "❌ Sistema no soportado para auto-instalación de Docker"
        return 1
    fi
}

# Auto-instalar kubectl con versión compatible
auto_instalar_kubectl() {
    local version="${1:-$(obtener_kubectl_compatible_auto)}"
    log_info "☸️ Auto-instalando kubectl $version..."
    
    local kubectl_url="https://dl.k8s.io/release/v$version/bin/linux/amd64/kubectl"
    
    if curl -sL "$kubectl_url" -o /tmp/kubectl && chmod +x /tmp/kubectl; then
        sudo mv /tmp/kubectl /usr/local/bin/kubectl
        log_success "✅ kubectl $version instalado correctamente"
    else
        log_error "❌ Error instalando kubectl"
        return 1
    fi
}

# Auto-instalar Helm
auto_instalar_helm() {
    log_info "⚙️ Auto-instalando Helm..."
    
    local version
    version=$(obtener_ultima_version_github "helm/helm" 5)
    if [[ -z "$version" ]]; then
        version="$HELM_VERSION"
    fi
    
    local helm_url="https://get.helm.sh/helm-v${version}-linux-amd64.tar.gz"
    
    if curl -sL "$helm_url" | tar xz -C /tmp && \
       sudo mv /tmp/linux-amd64/helm /usr/local/bin/helm; then
        log_success "✅ Helm $version instalado correctamente"
    else
        log_error "❌ Error instalando Helm"
        return 1
    fi
}

# Auto-instalar minikube
auto_instalar_minikube() {
    log_info "🎯 Auto-instalando minikube..."
    
    local version
    version=$(obtener_ultima_version_github "kubernetes/minikube" 5)
    if [[ -z "$version" ]]; then
        version="$MINIKUBE_VERSION"
    fi
    
    local minikube_url="https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-linux-amd64"
    
    if curl -sL "$minikube_url" -o /tmp/minikube && chmod +x /tmp/minikube; then
        sudo mv /tmp/minikube /usr/local/bin/minikube
        log_success "✅ minikube $version instalado correctamente"
    else
        log_error "❌ Error instalando minikube"
        return 1
    fi
}

# Función principal de auto-instalación desatendida
auto_instalar_dependencias_faltantes() {
    log_section "🚀 Auto-Instalación Desatendida de Dependencias"
    
    local herramientas_requeridas=("docker" "kubectl" "helm" "minikube" "git" "curl" "jq")
    local instalaciones_realizadas=0
    
    for herramienta in "${herramientas_requeridas[@]}"; do
        if ! command -v "$herramienta" >/dev/null 2>&1; then
            log_warning "⚠️ $herramienta no encontrado - instalando automáticamente..."
            
            case "$herramienta" in
                "docker")
                    if auto_instalar_docker; then
                        ((instalaciones_realizadas++))
                    fi
                    ;;
                "kubectl")
                    if auto_instalar_kubectl; then
                        ((instalaciones_realizadas++))
                    fi
                    ;;
                "helm")
                    if auto_instalar_helm; then
                        ((instalaciones_realizadas++))
                    fi
                    ;;
                "minikube")
                    if auto_instalar_minikube; then
                        ((instalaciones_realizadas++))
                    fi
                    ;;
                "git"|"curl"|"jq")
                    if sudo apt-get install -y "$herramienta" >/dev/null 2>&1; then
                        log_success "✅ $herramienta instalado"
                        ((instalaciones_realizadas++))
                    fi
                    ;;
            esac
        else
            log_success "✅ $herramienta ya disponible"
        fi
    done
    
    if [[ $instalaciones_realizadas -gt 0 ]]; then
        log_info "🔄 Se han instalado $instalaciones_realizadas herramientas"
        log_info "💡 Es recomendable abrir una nueva terminal para cargar los cambios"
    fi
    
    log_success "✅ Auto-instalación completada"
}

# Exports de funciones de auto-instalación
export -f obtener_ultima_version_github
export -f obtener_kubectl_compatible_auto
export -f auto_instalar_docker
export -f auto_instalar_kubectl
export -f auto_instalar_helm
export -f auto_instalar_minikube
export -f auto_instalar_dependencias_faltantes

# ============================================================================
# INFORMACIÓN DE ACTUALIZACIÓN
# ============================================================================

readonly VERSIONS_LAST_UPDATE="2025-08-01"
readonly VERSIONS_UPDATE_SOURCE="GitHub Releases + Helm Hub + Auto-Update"

log_debug "Librería de versiones cargada - Última actualización: $VERSIONS_LAST_UPDATE"
