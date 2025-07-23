#!/bin/bash

# 🚀 Instalación Automático Completo de Infraestructura GitOps
# Instalación con un comando: prerrequisitos + stack GitOps
# Compatible con: Ubuntu 20.04+, WSL2, Ubuntu Server, Ubuntu Desktop

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} 🔍 $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ❌ $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} 🚀 $1"
}

log_install() {
    echo -e "${CYAN}[INSTALL]${NC} 📦 $1"
}

# Check if running as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "This script should NOT be run as root (don't use sudo)"
        log_info "Run it as your regular user. It will ask for sudo when needed."
        exit 1
    fi
}

# Update system
update_system() {
    log_step "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git apt-transport-https ca-certificates gnupg lsb-release
    log_success "System updated"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    if command -v docker &> /dev/null; then
        log_success "Docker already installed"
        return 0
    fi
    
    log_install "Downloading and installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    
    log_install "Adding user to docker group..."
    sudo usermod -aG docker $USER
    
    # Start docker service (handle WSL2 case gracefully)
    log_install "Starting Docker service..."
    sudo systemctl enable docker || log_warning "Failed to enable Docker service (normal in some environments)"
    
    if ! sudo systemctl start docker; then
        log_warning "Docker service failed to start automatically (common in WSL2)"
        log_install "Attempting alternative Docker startup methods..."
        
        # Try to start Docker daemon directly (common in WSL2)
        if command -v dockerd &> /dev/null; then
            log_install "Starting Docker daemon directly..."
            sudo dockerd > /dev/null 2>&1 &
            sleep 5
        fi
        
        # Check if Docker is working now
        if ! docker version &> /dev/null; then
            log_warning "Docker installed but not running. Attempting manual start..."
            sudo service docker start || true
            sleep 3
        fi
    fi
    
    rm -f get-docker.sh
    log_success "Docker installation completed"
}

# Install kubectl
install_kubectl() {
    log_step "Installing kubectl..."
    if command -v kubectl &> /dev/null; then
        log_success "kubectl already installed"
        return 0
    fi
    
    log_install "Downloading kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    log_success "kubectl installed successfully"
}

# Install Minikube
install_minikube() {
    log_step "Installing Minikube..."
    if command -v minikube &> /dev/null; then
        log_success "Minikube already installed"
        return 0
    fi
    
    log_install "Downloading Minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
    log_success "Minikube installed successfully"
}

# Install Helm
install_helm() {
    log_step "Installing Helm..."
    if command -v helm &> /dev/null; then
        log_success "Helm already installed"
        return 0
    fi
    
    log_install "Downloading Helm installation script..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_success "Helm installed successfully"
}

# Verify Docker group access
verify_docker_access() {
    log_step "Verifying Docker access..."
    
    # Try to run docker without sudo
    if docker version &> /dev/null; then
        log_success "Docker access verified"
        return 0
    fi
    
    log_warning "Docker requires additional configuration..."
    log_install "Attempting to fix Docker access automatically..."
    
    # Try multiple approaches to get Docker working
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        log_install "Attempt $attempts/$max_attempts to fix Docker access..."
        
        # Method 1: Try to start Docker service
        sudo systemctl start docker &> /dev/null || true
        sudo service docker start &> /dev/null || true
        
        # Method 2: Try to refresh group membership
        newgrp docker <<< 'echo "Group refreshed"' &> /dev/null || true
        
        # Method 3: For WSL2, try starting dockerd directly
        if [ $attempts -eq 2 ]; then
            log_install "Trying WSL2-specific Docker startup..."
            sudo dockerd &> /dev/null &
            sleep 5
        fi
        
        # Test if Docker is working now
        if docker version &> /dev/null; then
            log_success "Docker access fixed successfully"
            return 0
        fi
        
        sleep 2
    done
    
    # If all attempts failed, check if we can at least use sudo docker
    if sudo docker version &> /dev/null; then
        log_warning "Docker works with sudo but not without it"
        log_warning "This may cause issues with some operations"
        log_info "Continuing installation - Docker functionality is available"
        return 0
    fi
    
    log_error "Docker is not functioning properly after all attempts"
    log_error "Please check Docker installation and try again"
    exit 1
}

# Verify all installations
verify_installations() {
    log_step "Verifying all installations..."
    
    local tools=("docker" "kubectl" "minikube" "helm" "git")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version=$($tool version --short 2>/dev/null || $tool version 2>/dev/null | head -1)
            log_success "$tool: $version"
        else
            missing+=("$tool")
            log_error "$tool: NOT FOUND"
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing tools: ${missing[*]}"
        exit 1
    fi
    
    log_success "All prerequisites verified!"
}

# Main installation function
main() {
    echo ""
    echo "🚀================================================"
    echo "   📦 COMPLETE GITOPS AUTO-INSTALLER"
    echo "   🔧 Prerequisites + Infrastructure Deployment"
    echo "================================================"
    echo ""
    
    log_step "Starting complete installation..."
    
    # Phase 1: Checks
    check_not_root
    
    # Phase 2: System preparation
    update_system
    
    # Phase 3: Install prerequisites
    install_docker
    install_kubectl
    install_minikube
    install_helm
    
    # Phase 4: Verify Docker access
    verify_docker_access
    
    # Phase 5: Verify installations
    verify_installations
    
    # Phase 6: Generate configuration
    log_step "Generating GitOps environment configuration..."
    chmod +x scripts/configurar-entorno.sh
    ./scripts/configurar-entorno.sh --auto
    
    # Phase 7: Make bootstrap executable and run it
    log_step "Running GitOps multi-cluster infrastructure bootstrap..."
    chmod +x scripts/arrancar-multi-cluster.sh scripts/limpiar-multi-cluster.sh
    chmod +x scripts/*.sh 2>/dev/null || true
    
    echo ""
    echo "🎯================================================"
    echo "   ✅ PREREQUISITES INSTALLATION COMPLETED!"
    echo "   🚀 STARTING MULTI-CLUSTER GITOPS DEPLOYMENT..."
    echo "================================================"
    echo ""
    
    # Run the multi-cluster GitOps bootstrap
    ./scripts/arrancar-multi-cluster.sh
    
    echo ""
    echo "🏆================================================"
    echo "   🎉 COMPLETE INSTALLATION FINISHED!"
    echo "   📊 18 GitOps Applications Ready!"
    echo "================================================"
    echo ""
}

# Handle Ctrl+C gracefully
trap 'log_error "Installation interrupted by user"; exit 1' INT

# Run main function
main "$@"
