#!/bin/bash

# ============================================================================
# INSTALLER FRAMEWORK DRY - Framework Universal de Instalación
# ============================================================================
# Responsabilidad: Framework genérico y reutilizable para instalaciones
# Principios: DRY, Template Method Pattern, Idempotente, Rollback-ready
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN FRAMEWORK
# ============================================================================

# Estados de instalación
readonly INSTALL_STATE_NOT_INSTALLED="NOT_INSTALLED"
readonly INSTALL_STATE_INSTALLED="INSTALLED"
readonly INSTALL_STATE_OUTDATED="OUTDATED"
readonly INSTALL_STATE_ERROR="ERROR"

# ============================================================================
# FUNCIONES TEMPLATE (DRY Pattern)
# ============================================================================

# Template method para instalación genérica
install_tool_template() {
    local tool_name="$1"
    local min_version="$2"
    local description="$3"
    local install_function="$4"
    
    log_info "🔧 Procesando: $description..."
    
    # 1. Verificar estado actual
    local current_state
    current_state=$(get_tool_install_state "$tool_name" "$min_version")
    
    case "$current_state" in
        "$INSTALL_STATE_INSTALLED")
            log_success "✅ $description ya está instalado y actualizado"
            return 0
            ;;
        "$INSTALL_STATE_OUTDATED")
            log_warning "⚠️ $description necesita actualización"
            ;;
        "$INSTALL_STATE_NOT_INSTALLED")
            log_info "📦 $description no está instalado"
            ;;
        "$INSTALL_STATE_ERROR")
            log_error "❌ Error verificando $description"
            return 1
            ;;
    esac
    
    # 2. Ejecutar instalación
    log_info "🚀 Instalando $description..."
    
    if "$install_function"; then
        log_success "✅ $description instalado correctamente"
        
        # 3. Verificar instalación
        if check_tool_version "$tool_name" "$min_version" "$description"; then
            return 0
        else
            log_error "❌ Verificación post-instalación falló para $description"
            return 1
        fi
    else
        log_error "❌ Falló la instalación de $description"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE ESTADO DRY
# ============================================================================

# Determinar estado de instalación de herramienta
get_tool_install_state() {
    local tool="$1"
    local min_version="$2"
    
    if ! command_exists "$tool"; then
        echo "$INSTALL_STATE_NOT_INSTALLED"
        return
    fi
    
    local current_version
    current_version=$(get_tool_version "$tool" 2>/dev/null) || {
        echo "$INSTALL_STATE_ERROR"
        return
    }
    
    local comparison
    comparison=$(version_compare "$current_version" "$min_version")
    
    if [[ "$comparison" -ge 0 ]]; then
        echo "$INSTALL_STATE_INSTALLED"
    else
        echo "$INSTALL_STATE_OUTDATED"
    fi
}

# ============================================================================
# INSTALADORES ESPECÍFICOS DRY
# ============================================================================

# Instalador Docker (DRY)
install_docker() {
    log_info "🐳 Instalando Docker Engine..."
    
    # Remover versiones conflictivas
    sudo apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc 2>/dev/null || true
    
    # Actualizar repositorios
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    
    # Añadir clave GPG oficial de Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Añadir repositorio
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Configurar usuario
    sudo usermod -aG docker "$USER"
    
    # Iniciar servicio
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log_success "✅ Docker instalado correctamente"
}

# Instalador kubectl (DRY)
install_kubectl() {
    log_info "☸️ Instalando kubectl..."
    
    local kubectl_version
    kubectl_version=$(curl -L -s https://dl.k8s.io/release/stable.txt | sed 's/v//')
    
    # Descargar kubectl
    curl -LO "https://dl.k8s.io/release/v${kubectl_version}/bin/linux/amd64/kubectl"
    
    # Instalar
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    
    log_success "✅ kubectl v$kubectl_version instalado"
}

# Instalador minikube (DRY)
install_minikube() {
    log_info "🎯 Instalando minikube..."
    
    local minikube_version
    minikube_version=$(curl -s https://api.github.com/repos/kubernetes/minikube/releases/latest | grep -oP '(?<="tag_name": "v)\d+\.\d+\.\d+')
    
    # Descargar minikube
    curl -Lo minikube "https://github.com/kubernetes/minikube/releases/download/v${minikube_version}/minikube-linux-amd64"
    
    # Instalar
    chmod +x minikube
    sudo mv minikube /usr/local/bin/
    
    log_success "✅ minikube v$minikube_version instalado"
}

# Instalador Helm (DRY)
install_helm() {
    log_info "⚓ Instalando Helm..."
    
    # Usar script oficial de Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    log_success "✅ Helm instalado correctamente"
}

# Instalador Git (DRY)
install_git() {
    log_info "📝 Instalando Git..."
    
    sudo apt-get update
    sudo apt-get install -y git
    
    log_success "✅ Git instalado correctamente"
}

# ============================================================================
# API PÚBLICA DE INSTALACIÓN DRY
# ============================================================================

# Instalar herramienta específica
install_tool() {
    local tool="$1"
    local min_version="$2"
    local description="$3"
    
    case "$tool" in
        "docker")
            install_tool_template "$tool" "$min_version" "$description" "install_docker"
            ;;
        "kubectl")
            install_tool_template "$tool" "$min_version" "$description" "install_kubectl"
            ;;
        "minikube")
            install_tool_template "$tool" "$min_version" "$description" "install_minikube"
            ;;
        "helm")
            install_tool_template "$tool" "$min_version" "$description" "install_helm"
            ;;
        "git")
            install_tool_template "$tool" "$min_version" "$description" "install_git"
            ;;
        *)
            log_error "❌ Herramienta no soportada: $tool"
            return 1
            ;;
    esac
}

# Instalar múltiples herramientas
install_multiple_tools() {
    local tools_spec=("$@")
    local all_ok=true
    
    for spec in "${tools_spec[@]}"; do
        IFS=':' read -r tool min_version description <<< "$spec"
        
        if ! install_tool "$tool" "$min_version" "$description"; then
            all_ok=false
        fi
    done
    
    $all_ok
}

# Instalar dependencias completas del sistema
install_system_dependencies() {
    local system_tools=(
        "git:2.30:Control de versiones"
        "docker:20.10:Docker Engine"
        "kubectl:1.25:Cliente Kubernetes"
        "minikube:1.30:Kubernetes local"
        "helm:3.8:Gestor de paquetes K8s"
    )
    
    log_section "📦 Instalando Dependencias del Sistema"
    
    if install_multiple_tools "${system_tools[@]}"; then
        log_success "✅ Todas las dependencias del sistema instaladas"
        show_tools_summary
        return 0
    else
        log_error "❌ Falló la instalación de algunas dependencias"
        return 1
    fi
}

# ============================================================================
# UTILIDADES DE GESTIÓN
# ============================================================================

# Verificar conectividad a internet
check_internet_connectivity() {
    log_info "🌐 Verificando conectividad a internet..."
    
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "✅ Conectividad a internet verificada"
        return 0
    else
        log_error "❌ Sin conectividad a internet"
        return 1
    fi
}

# Verificar privilegios sudo
check_sudo_privileges() {
    log_info "🔐 Verificando privilegios sudo..."
    
    if sudo -n true 2>/dev/null; then
        log_success "✅ Privilegios sudo disponibles"
        return 0
    else
        log_warning "⚠️ Privilegios sudo requeridos"
        
        if sudo -v; then
            log_success "✅ Privilegios sudo activados"
            return 0
        else
            log_error "❌ No se pudieron obtener privilegios sudo"
            return 1
        fi
    fi
}
