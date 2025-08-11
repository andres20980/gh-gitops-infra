#!/bin/bash

# ============================================================================
# DEPENDENCIES LIB - Gestión Universal de Dependencias del Sistema
# ============================================================================
# Responsabilidad: Instalación y verificación DRY de dependencias críticas
# Principios: DRY, SOLID, Idempotente, WSL-optimizado
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly REQUIRED_TOOLS=(
    "docker:latest:Docker Engine para containers"
    "minikube:latest:Kubernetes local cluster"
    "kubectl:auto:Cliente Kubernetes (compatible con minikube)"
    "helm:latest:Gestor de paquetes Kubernetes"
    "git:latest:Control de versiones"
)

readonly DOCKER_SOURCES="/etc/apt/sources.list.d/docker.list"
readonly HELM_SCRIPT="/tmp/get_helm.sh"

# ============================================================================
# FUNCIONES DE DETECCIÓN DE VERSIONES
# ============================================================================

# Formateador delegado a versions.sh
format_version() { formatear_version "$1"; }

# Obtener última versión disponible de una herramienta
get_latest_version() { obtener_ultima_version "$1"; }

# Obtener versión estable de Kubernetes según minikube (sin arrancar cluster)
get_minikube_stable_k8s() { obtener_k8s_estable_minikube; }

# Verificar compatibilidad kubectl-minikube
get_compatible_kubectl_version() { obtener_version_kubectl_compatible "$@"; }

# Obtener versión de kubectl de forma robusta (full o short)
get_kubectl_version() { obtener_version_kubectl_instalada "$@"; }

# ============================================================================
# FUNCIONES DE VERIFICACIÓN MEJORADAS
# ============================================================================

# Verificar herramienta con versión más reciente
check_tool() {
    local tool="$1"
    local version_requirement="$2"  # "latest", "auto", o versión específica
    local description="$3"
    
    if ! command -v "$tool" >/dev/null 2>&1; then
    log_debug "$tool no instalado"
        return 1
    fi
    
    local current_version
    case "$tool" in
        "docker")
            current_version=$(docker --version 2>/dev/null | grep -oP '(?<=version )\d+\.\d+\.\d+' || echo "0.0.0")
            ;;
        "minikube")
            current_version=$(minikube version 2>/dev/null | grep -oP '(?<=version: v)\d+\.\d+\.\d+' || echo "0.0.0")
            ;;
        "kubectl")
            # Verificar integridad básica del binario
            local kubectl_path
            kubectl_path=$(command -v kubectl || true)
            if [[ -z "$kubectl_path" ]] || ! file "$kubectl_path" 2>/dev/null | grep -qi 'ELF'; then
                log_debug "kubectl ausente o binario corrupto"
                return 1
            fi
            # kubectl version output varies; delegamos al helper
            if ! current_version=$(get_kubectl_version full 2>/dev/null); then
                log_debug "kubectl presente pero no responde correctamente"
                return 1
            fi
            ;;
        "helm")
            current_version=$(helm version 2>/dev/null | grep -oP '(?<=Version:"v)\d+\.\d+\.\d+' || echo "0.0.0")
            ;;
        "git")
            current_version=$(git --version 2>/dev/null | grep -oP '(?<=version )\d+\.\d+\.\d+' || echo "0.0.0")
            ;;
        *)
            log_error "Herramienta no soportada: $tool"
            return 1
            ;;
    esac
    
    # Para versión "latest" o "auto", solo verificamos que esté instalado
    if [[ "$version_requirement" == "latest" || "$version_requirement" == "auto" ]]; then
    log_success "$description v$(format_version "$current_version") (instalado)"
        return 0
    fi
    
    # Comparar versiones específicas
    local curr_major curr_minor curr_patch min_major min_minor min_patch
    curr_major=$(echo "$current_version" | cut -d'.' -f1)
    curr_minor=$(echo "$current_version" | cut -d'.' -f2)
    curr_patch=$(echo "$current_version" | cut -d'.' -f3)
    min_major=$(echo "$version_requirement" | cut -d'.' -f1)
    min_minor=$(echo "$version_requirement" | cut -d'.' -f2)
    min_patch=$(echo "$version_requirement" | cut -d'.' -f3 2>/dev/null || echo "0")
    
    local curr_int=$((curr_major * 10000 + curr_minor * 100 + curr_patch))
    local min_int=$((min_major * 10000 + min_minor * 100 + min_patch))
    
    if [[ $curr_int -ge $min_int ]]; then
    log_success "$description v$(format_version "$current_version")"
        return 0
    else
    log_warning "$description v$(format_version "$current_version") < v$version_requirement"
        return 1
    fi
}

# Verificar todas las dependencias
check_all_dependencies() {
    log_info "Verificando dependencias del sistema..."
    
    local all_ok=true
    for spec in "${REQUIRED_TOOLS[@]}"; do
        IFS=':' read -r tool min_version description <<< "$spec"
        
        if ! check_tool "$tool" "$min_version" "$description"; then
            all_ok=false
        fi
    done
    
    if $all_ok; then
    log_success "Todas las dependencias están disponibles"
        return 0
    else
    log_error "Faltan dependencias críticas"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN
# ============================================================================

# Instalar Docker
install_docker() {
    log_info "Instalando Docker Engine..."
    
    # Remover conflictos
    sudo apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null || true
    
    # Dependencias
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    
    # Clave GPG
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Repositorio
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee "$DOCKER_SOURCES" > /dev/null
    
    # Instalar
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Configurar usuario
    sudo usermod -aG docker "$USER"
    # Arranque/enable solo si systemd está disponible
    if command -v systemctl >/dev/null 2>&1 && [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
        sudo systemctl enable docker || true
        sudo systemctl start docker || true
    else
    log_info "Entorno sin systemd: se omite systemctl enable/start docker"
    fi
    
    log_success "Docker instalado"
}

# Instalar kubectl compatible con minikube
install_kubectl() {
    log_info "Instalando kubectl compatible con minikube..."
    
    # Obtener versión compatible
    local version
    version=$(get_compatible_kubectl_version)
    if [[ -z "$version" ]]; then
        log_error "No se pudo resolver la versión de kubectl"
        return 1
    fi

    # Detectar arquitectura
    local arch
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) arch="amd64" ;;
    esac

    log_info "Descargando kubectl v$version ($arch)..."
    local tmpdir
    tmpdir=$(mktemp -d)
    (
        set -euo pipefail
        cd "$tmpdir"
        curl -fsSLo kubectl "https://dl.k8s.io/release/v${version}/bin/linux/${arch}/kubectl"
        curl -fsSLo kubectl.sha256 "https://dl.k8s.io/release/v${version}/bin/linux/${arch}/kubectl.sha256"
    if ! echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status; then
    log_error "Falló la verificación de integridad de kubectl"
            exit 1
        fi
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    )

    # Verificación post-instalación
    if kubectl version --client --short >/dev/null 2>&1; then
    log_success "kubectl v$version instalado"
    else
    log_error "kubectl no responde tras la instalación"
        return 1
    fi
}

# Instalar minikube más reciente
install_minikube() {
    log_info "Instalando minikube más reciente..."
    
    # Obtener última versión
    local version
    version=$(get_latest_version "minikube")
    
    log_info "Descargando minikube v$version..."
    curl -Lo minikube "https://github.com/kubernetes/minikube/releases/download/v${version}/minikube-linux-amd64"
    chmod +x minikube
    sudo mv minikube /usr/local/bin/
    
    log_success "minikube v$version instalado"
}

# Instalar Helm más reciente
install_helm() {
    log_info "Instalando Helm más reciente..."
    
    # Usar script oficial que siempre instala la última versión
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm instalado (última versión)"
}

# Instalar Git
install_git() {
    log_info "Instalando Git..."
    
    sudo apt-get update
    sudo apt-get install -y git
    
    log_success "Git instalado"
}

# Instalar herramienta específica
install_tool() {
    local tool="$1"
    local min_version="$2"
    local description="$3"
    
    # Verificar si ya está instalado correctamente
    if check_tool "$tool" "$min_version" "$description"; then
        return 0
    fi
    
    log_info "Instalando $description..."
    
    case "$tool" in
        "docker") install_docker ;;
        "kubectl") install_kubectl ;;
        "minikube") install_minikube ;;
        "helm") install_helm ;;
        "git") install_git ;;
        *) 
            log_error "Instalador no disponible para: $tool"
            return 1
            ;;
    esac
    
    # Verificar instalación
    if check_tool "$tool" "$min_version" "$description"; then
        return 0
    else
    log_error "Falló la verificación post-instalación de $tool"
        return 1
    fi
}

# Instalar todas las dependencias
install_all_dependencies() {
    log_section "Instalando Dependencias del Sistema"
    
    # Verificar prerequisitos
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "Sin conectividad a internet"
        return 1
    fi
    
    # Verificar sudo
    if ! sudo -n true 2>/dev/null; then
        log_info "Requiere privilegios sudo..."
        if ! sudo -v; then
            log_error "No se pudieron obtener privilegios sudo"
            return 1
        fi
    fi
    
    # Instalar cada herramienta
    local all_ok=true
    for spec in "${REQUIRED_TOOLS[@]}"; do
        IFS=':' read -r tool min_version description <<< "$spec"
        
        if ! install_tool "$tool" "$min_version" "$description"; then
            all_ok=false
        fi
    done
    
    if $all_ok; then
        log_success "Todas las dependencias instaladas correctamente"
        show_dependencies_summary
        return 0
    else
        log_error "Falló la instalación de algunas dependencias"
        return 1
    fi
}

# Mostrar resumen de dependencias
show_dependencies_summary() {
    log_section "Resumen de Dependencias"
    
    for spec in "${REQUIRED_TOOLS[@]}"; do
        IFS=':' read -r tool min_version description <<< "$spec"
        
        if command -v "$tool" >/dev/null 2>&1; then
            local version
            case "$tool" in
                "docker") version=$(docker --version 2>/dev/null | grep -oP '(?<=version )\d+\.\d+' || echo "N/A") ;;
                "minikube") version=$(minikube version 2>/dev/null | grep -oP '(?<=version: v)\d+\.\d+' || echo "N/A") ;;
                "kubectl")
                    if ! version=$(get_kubectl_version short 2>/dev/null); then
                        version="N/A"
                    fi
                    ;;
                "helm") version=$(helm version 2>/dev/null | grep -oP '(?<=Version:"v)\d+\.\d+' || echo "N/A") ;;
                "git") version=$(git --version 2>/dev/null | grep -oP '(?<=version )\d+\.\d+' || echo "N/A") ;;
                *) version="N/A" ;;
            esac
            log_info "    $tool v$version - $description"
        else
            log_info "    $tool - $description (no instalado)"
        fi
    done
}
