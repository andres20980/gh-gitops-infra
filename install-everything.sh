#!/bin/bash

# 🚀 Complete GitOps Infrastructure Auto-Installer
# One-command installation: prerequisites + GitOps stack
# Compatible with: Ubuntu 20.04+, WSL2, Ubuntu Server, Ubuntu Desktop

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
    
    # Start docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    rm -f get-docker.sh
    log_success "Docker installed successfully"
    log_warning "You may need to logout/login or restart terminal for docker group changes"
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
    
    log_warning "Docker group access not working yet"
    log_info "Attempting to refresh group membership..."
    
    # Try newgrp docker
    if ! newgrp docker <<< 'docker version' &> /dev/null; then
        log_error "Cannot access Docker without sudo"
        log_error "Please logout/login or restart your terminal, then run this script again"
        exit 1
    fi
    
    log_success "Docker access refreshed"
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
    
    # Phase 6: Make bootstrap executable and run it
    log_step "Running GitOps multi-cluster infrastructure bootstrap..."
    chmod +x bootstrap-multi-cluster.sh cleanup-multi-cluster.sh
    chmod +x scripts/*.sh 2>/dev/null || true
    
    echo ""
    echo "🎯================================================"
    echo "   ✅ PREREQUISITES INSTALLATION COMPLETED!"
    echo "   🚀 STARTING MULTI-CLUSTER GITOPS DEPLOYMENT..."
    echo "================================================"
    echo ""
    
    # Run the multi-cluster GitOps bootstrap
    ./bootstrap-multi-cluster.sh
    
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
