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
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
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

instalar_minikube() {
    log_info "🚀 Instalando Minikube..."
    
    if comando_existe minikube; then
        log_info "Minikube ya está instalado"
        return 0
    fi
    
    # Descargar la última versión de minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    
    # Instalar minikube
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    
    # Limpiar archivo temporal
    rm -f minikube-linux-amd64
    
    log_success "Minikube instalado correctamente"
}

# ============================================================================
# INSTALACIÓN DE HERRAMIENTAS ADICIONALES
# ============================================================================

instalar_herramientas_adicionales() {
    log_info "🔧 Instalando herramientas adicionales..."
    
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
    
    log_success "Herramientas adicionales instaladas"
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
    instalar_kubectl
    instalar_helm
    instalar_minikube
    instalar_herramientas_adicionales
    
    log_success "Todas las dependencias instaladas correctamente"
    log_info "🔄 Reinicia la sesión para aplicar cambios de grupo de Docker"
    
    return 0
}

# ============================================================================
# FUNCIONES DE AUTO-INSTALACIÓN ESPECÍFICAS
# ============================================================================

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

auto_instalar_helm() {
    if ! comando_existe helm; then
        log_info "⬇️ Auto-instalando Helm..."
        instalar_helm
    fi
}

auto_instalar_minikube() {
    if ! comando_existe minikube; then
        log_info "⬇️ Auto-instalando Minikube..."
        instalar_minikube
    fi
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
