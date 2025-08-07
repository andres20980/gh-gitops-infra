#!/bin/bash

# ============================================================================
# MÓDULO DE INSTALACIÓN - Instalación automática de dependencias
# ============================================================================
# Instala automáticamente todas las herramientas necesarias para GitOps
# ============================================================================

set -euo pipefail

# Cargar funciones comunes
DEPENDENCIAS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../comun/base.sh
source "$DEPENDENCIAS_SCRIPT_DIR/../comun/base.sh"

# ============================================================================
# INSTALACIÓN DE DOCKER
# ============================================================================

instalar_docker() {
    log_info "🐳 Instalando Docker..."
    
    if comando_existe docker; then
        log_info "Docker ya está instalado"
        return 0
    fi
    
    # Actualizar índice de paquetes
    log_debug "Actualizando índice de paquetes..."
    sudo apt update -qq
    
    # Instalar prerequisitos
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Agregar clave GPG de Docker
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Agregar repositorio de Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Actualizar e instalar Docker
    sudo apt update -qq
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Agregar usuario al grupo docker
    sudo usermod -aG docker "$USER"
    
    # Habilitar y iniciar servicio
    if tiene_systemd; then
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    
    log_success "Docker instalado correctamente"
}

# ============================================================================
# INSTALACIÓN DE KUBECTL
# ============================================================================

instalar_kubectl() {
    log_info "⚓ Instalando kubectl..."
    
    if comando_existe kubectl; then
        log_info "kubectl ya está instalado"
        return 0
    fi
    
    # Descargar la última versión estable
    local version
    version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    
    curl -LO "https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl.sha256"
    
    # Verificar checksum
    if ! printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum --check --quiet; then
        log_error "❌ Verificación de checksum falló para kubectl"
        rm -f kubectl kubectl.sha256
        return 1
    fi
    
    # Instalar kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    # Limpiar archivos temporales
    rm -f kubectl kubectl.sha256
    
    log_success "kubectl instalado correctamente"
}

# ============================================================================
# INSTALACIÓN DE HELM
# ============================================================================

instalar_helm() {
    log_info "⚙️ Instalando Helm..."
    
    if comando_existe helm; then
        log_info "Helm ya está instalado"
        return 0
    fi
    
    # Descargar e instalar Helm usando el script oficial
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "Helm instalado correctamente"
}

# ============================================================================
# INSTALACIÓN DE MINIKUBE
# ============================================================================

obtener_version_minikube_latest() {
    # Obtener la última versión desde GitHub API
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | jq -r '.tag_name' 2>/dev/null || echo "")
    
    if [[ -n "$latest_version" && "$latest_version" != "null" ]]; then
        echo "$latest_version"
    else
        echo "v1.36.0"  # Fallback
    fi
}

instalar_minikube() {
    log_info "🚀 Instalando/Actualizando Minikube..."
    
    local latest_version
    latest_version=$(obtener_version_minikube_latest)
    
    local current_version=""
    if comando_existe minikube; then
        current_version=$(minikube version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "")
    fi
    
    if [[ -n "$current_version" && "$current_version" == "$latest_version" ]]; then
        log_success "✅ Minikube ya está actualizado ($current_version)"
        return 0
    fi
    
    if [[ -n "$current_version" ]]; then
        log_info "🔄 Actualizando Minikube de $current_version a $latest_version"
    else
        log_info "📦 Instalando Minikube $latest_version"
    fi
    
    # Descargar la última versión de minikube
    if curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" 2>/dev/null; then
        # Instalar minikube
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        
        # Limpiar archivo temporal
        rm -f minikube-linux-amd64
        
        log_success "✅ Minikube $latest_version instalado correctamente"
    else
        if [[ -n "$current_version" ]]; then
            log_warning "⚠️ No se pudo actualizar minikube, manteniendo versión actual ($current_version)"
        else
            log_error "❌ Error descargando minikube"
            return 1
        fi
    fi
}

# ============================================================================
# INSTALACIÓN DE HERRAMIENTAS ADICIONALES
# ============================================================================

instalar_herramientas_adicionales() {
    log_info "🔧 Instalando herramientas adicionales..."
    
    # Limpiar paquetes obsoletos antes de instalar nuevos
    log_debug "🧹 Limpiando paquetes obsoletos..."
    sudo apt autoremove -y -qq 2>/dev/null || true
    sudo apt autoclean -qq 2>/dev/null || true
    
    # Instalar herramientas útiles para desarrollo
    sudo apt update -qq
    sudo apt install -y \
        bash-completion \
        vim \
        nano \
        htop \
        tree \
        watch \
        bc
    
    # Configurar autocompletado para kubectl
    if comando_existe kubectl; then
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    fi
    
    # Configurar autocompletado para helm
    if comando_existe helm; then
        helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null
    fi
    
    # Configurar autocompletado para minikube
    if comando_existe minikube; then
        minikube completion bash | sudo tee /etc/bash_completion.d/minikube > /dev/null
    fi
    
    log_success "✅ Herramientas adicionales instaladas"
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE INSTALACIÓN
# ============================================================================

instalar_dependencias() {
    log_section "📦 Instalando Dependencias del Sistema"
    
    # Verificar permisos de administrador
    if ! es_root && ! sudo -n true 2>/dev/null; then
        log_error "Se requieren permisos de administrador para instalar dependencias"
        return 1
    fi
    
    # Actualizar sistema
    log_info "🔄 Actualizando sistema..."
    sudo apt update -qq
    sudo apt upgrade -y -qq
    
    # Instalar dependencias básicas del sistema
    log_info "📋 Instalando dependencias básicas..."
    sudo apt install -y \
        curl \
        wget \
        jq \
        git \
        unzip \
        tar \
        gzip \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common
    
    # Instalar herramientas GitOps
    instalar_docker
    instalar_minikube  # Instalar minikube primero
    instalar_kubectl_compatible  # Luego kubectl compatible con minikube
    instalar_helm
    instalar_herramientas_adicionales
    
    # Limpieza final del sistema
    log_info "🧹 Realizando limpieza final del sistema..."
    sudo apt autoremove -y -qq 2>/dev/null || true
    sudo apt autoclean -qq 2>/dev/null || true
    
    log_success "✅ Todas las dependencias instaladas correctamente"
    log_info "🔄 Reinicia la sesión para aplicar cambios de grupo de Docker"
    
    return 0
}

# ============================================================================
# FUNCIONES DE AUTO-INSTALACIÓN ESPECÍFICAS
# ============================================================================

obtener_version_kubernetes_minikube() {
    # Obtener lista de versiones soportadas por minikube (silencioso)
    local versiones_disponibles
    versiones_disponibles=$(minikube config defaults kubernetes-version 2>/dev/null)
    
    if [[ -z "$versiones_disponibles" ]]; then
        echo "v1.31.0"  # Fallback conservador
        return
    fi
    
    # Filtrar solo versiones estables (sin rc, beta, alpha)
    local version_estable
    version_estable=$(echo "$versiones_disponibles" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | head -1)
    
    # Si no encontramos versión estable, usar la primera disponible
    if [[ -z "$version_estable" ]]; then
        version_estable=$(echo "$versiones_disponibles" | head -1)
    fi
    
    # Validar formato de versión
    if [[ "$version_estable" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "$version_estable"
    else
        echo "v1.31.0"
    fi
}

instalar_kubectl_compatible() {
    local k8s_version="${1:-}"
    
    # Si no se especifica versión, detectar la compatible con minikube
    if [[ -z "$k8s_version" ]] && comando_existe minikube; then
        log_info "🔍 Detectando versión de Kubernetes compatible con minikube..."
        k8s_version=$(obtener_version_kubernetes_minikube)
        log_info "📋 Versión detectada: $k8s_version"
    fi
    
    # Fallback si no pudimos detectar la versión
    if [[ -z "$k8s_version" ]]; then
        k8s_version="v1.31.0"
        log_warning "⚠️ Usando versión fallback: $k8s_version"
    fi
    
    log_info "🔧 Instalando kubectl compatible ($k8s_version)..."
    
    # Eliminar kubectl anterior si existe
    sudo rm -f /usr/local/bin/kubectl /usr/bin/kubectl 2>/dev/null || true
    
    # Descargar kubectl compatible
    if curl -LO "https://dl.k8s.io/release/$k8s_version/bin/linux/amd64/kubectl" 2>/dev/null; then
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/kubectl
        log_success "✅ kubectl $k8s_version instalado"
    else
        log_warning "⚠️ No se pudo instalar kubectl $k8s_version, instalando versión estable"
        instalar_kubectl  # Fallback a la función original
    fi
}

auto_instalar_docker() {
    if ! comando_existe docker; then
        log_info "⬇️ Auto-instalando Docker..."
        instalar_docker
    fi
}

auto_instalar_kubectl() {
    if ! comando_existe kubectl; then
        log_info "⬇️ Auto-instalando kubectl..."
        instalar_kubectl
    fi
}

auto_instalar_kubectl_compatible() {
    if ! comando_existe kubectl; then
        log_info "⬇️ Auto-instalando kubectl compatible con minikube..."
        instalar_kubectl_compatible
    elif comando_existe minikube; then
        # Verificar si el kubectl actual es compatible con minikube
        local minikube_version
        minikube_version=$(obtener_version_kubernetes_minikube)
        
        local kubectl_version
        kubectl_version=$(kubectl version --output=yaml 2>/dev/null | grep "gitVersion" | head -1 | awk '{print $2}' 2>/dev/null || echo "")
        
        if [[ "$kubectl_version" != "$minikube_version" ]]; then
            log_warning "⚠️ kubectl ($kubectl_version) no es compatible con minikube ($minikube_version)"
            log_info "🔧 Actualizando kubectl a versión compatible..."
            instalar_kubectl_compatible "$minikube_version"
        else
            log_success "✅ kubectl ya es compatible con minikube ($kubectl_version)"
        fi
    fi
}

auto_instalar_helm() {
    if ! comando_existe helm; then
        log_info "⬇️ Auto-instalando Helm..."
        instalar_helm
    fi
}

auto_instalar_minikube() {
    # Siempre instalar/actualizar minikube a la última versión
    log_info "⬇️ Auto-instalando/actualizando Minikube..."
    instalar_minikube
}

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

inicializar_modulo_instalacion() {
    log_debug "Módulo de instalación cargado - Funciones de auto-instalación disponibles"
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inicializar_modulo_instalacion
    instalar_dependencias
fi
