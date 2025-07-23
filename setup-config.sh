#!/bin/bash

# 🔧 GitOps Configuration Generator
# =================================
# This script helps users customize their GitOps environment after forking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} 🔍 $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} ❌ $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} 🚀 $1"; }

# Configuration file path
CONFIG_FILE="config/environment.conf"
CONFIG_TEMPLATE="config/environment.conf.template"

# Detect current git repository
detect_current_repo() {
    local git_url
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
        
        if [[ "$git_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
            echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Interactive configuration setup
interactive_setup() {
    log_step "Setting up your GitOps environment configuration..."
    echo ""
    
    # Detect current repository
    local current_repo=$(detect_current_repo)
    local default_username=""
    local default_repo="gh-gitops-infra"
    
    if [[ -n "$current_repo" ]]; then
        default_username=$(echo "$current_repo" | cut -d'/' -f1)
        default_repo=$(echo "$current_repo" | cut -d'/' -f2)
        log_info "Detected repository: $current_repo"
    fi
    
    # Get GitHub username
    echo -n "🐙 Enter your GitHub username"
    if [[ -n "$default_username" ]]; then
        echo -n " [$default_username]"
    fi
    echo -n ": "
    read github_username
    github_username=${github_username:-$default_username}
    
    if [[ -z "$github_username" ]]; then
        log_error "GitHub username is required!"
        exit 1
    fi
    
    # Get repository name
    echo -n "📦 Enter your repository name [$default_repo]: "
    read repo_name
    repo_name=${repo_name:-$default_repo}
    
    # Get organization name
    echo -n "🏢 Enter your organization name [$github_username]: "
    read org_name
    org_name=${org_name:-$github_username}
    
    # Resource allocation
    echo ""
    log_info "💻 Resource allocation (press Enter for defaults):"
    
    echo -n "   DEV cluster CPUs [4]: "
    read dev_cpus
    dev_cpus=${dev_cpus:-4}
    
    echo -n "   DEV cluster Memory [8g]: "
    read dev_memory
    dev_memory=${dev_memory:-8g}
    
    echo -n "   PROD cluster CPUs [6]: "
    read prod_cpus
    prod_cpus=${prod_cpus:-6}
    
    echo -n "   PROD cluster Memory [12g]: "
    read prod_memory
    prod_memory=${prod_memory:-12g}
    
    # Components selection
    echo ""
    log_info "🔧 Component selection (y/N):"
    
    echo -n "   Enable Grafana monitoring? [Y/n]: "
    read enable_grafana
    enable_grafana=${enable_grafana:-Y}
    [[ "$enable_grafana" =~ ^[Yy] ]] && enable_grafana="true" || enable_grafana="false"
    
    echo -n "   Enable Jaeger tracing? [Y/n]: "
    read enable_jaeger
    enable_jaeger=${enable_jaeger:-Y}
    [[ "$enable_jaeger" =~ ^[Yy] ]] && enable_jaeger="true" || enable_jaeger="false"
    
    echo -n "   Enable MinIO storage? [Y/n]: "
    read enable_minio
    enable_minio=${enable_minio:-Y}
    [[ "$enable_minio" =~ ^[Yy] ]] && enable_minio="true" || enable_minio="false"
    
    # Generate configuration
    generate_config_file "$github_username" "$repo_name" "$org_name" \
                        "$dev_cpus" "$dev_memory" "$prod_cpus" "$prod_memory" \
                        "$enable_grafana" "$enable_jaeger" "$enable_minio"
    
    echo ""
    log_success "Configuration generated successfully!"
    log_info "Configuration saved to: $CONFIG_FILE"
    log_warning "Please review and adjust the configuration as needed"
    echo ""
    log_step "Next steps:"
    echo "   1. Review: cat $CONFIG_FILE"
    echo "   2. Deploy: ./bootstrap-multi-cluster.sh"
    echo ""
}

# Generate configuration file
generate_config_file() {
    local username="$1"
    local repo="$2"
    local org="$3"
    local dev_cpus="$4"
    local dev_memory="$5"
    local prod_cpus="$6" 
    local prod_memory="$7"
    local grafana="$8"
    local jaeger="$9"
    local minio="${10}"
    
    # Create config directory if it doesn't exist
    mkdir -p config
    
    # Generate timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "$CONFIG_FILE" << EOF
# 🏢 GitOps Multi-Cluster Environment Configuration
# ================================================
# Generated on: $timestamp
# This file contains all customizable variables for the GitOps infrastructure.

# 📦 REPOSITORY CONFIGURATION
# ----------------------------
GITHUB_REPO_URL="https://github.com/$username/$repo.git"
GITHUB_USERNAME="$username"
GITHUB_REPO_NAME="$repo"

# 🌐 CLUSTER CONFIGURATION  
# -------------------------
DEV_CLUSTER_PROFILE="gitops-dev"
PRE_CLUSTER_PROFILE="gitops-pre" 
PROD_CLUSTER_PROFILE="gitops-prod"

# 💻 RESOURCE ALLOCATION
# -----------------------
DEV_CLUSTER_RESOURCES="$dev_cpus,${dev_memory},50g,8080"
PRE_CLUSTER_RESOURCES="3,6g,30g,8081"
PROD_CLUSTER_RESOURCES="$prod_cpus,${prod_memory},100g,8082"

# 🏷️  VERSION MANAGEMENT
# -----------------------
ARGOCD_VERSION="v2.12.3"
KARGO_VERSION="v0.8.4"
KUBERNETES_VERSION="stable"

# 🌍 NETWORKING
# -------------
ARGOCD_DEV_PORT="8080"
ARGOCD_PRE_PORT="8081" 
ARGOCD_PROD_PORT="8082"
KARGO_UI_PORT="3000"
GRAFANA_PORT="3001"

# 🏢 ENTERPRISE SETTINGS
# -----------------------
ORGANIZATION_NAME="$org"
TEAM_NAME="Platform"
DEFAULT_NAMESPACES="monitoring,demo-project,kargo"

# 🚀 DEPLOYMENT OPTIONS
# ----------------------
ENABLE_MONITORING="true"
ENABLE_GRAFANA="$grafana"
ENABLE_JAEGER="$jaeger"
ENABLE_LOKI="true"
ENABLE_MINIO="$minio"
ENABLE_CERT_MANAGER="true"
ENABLE_EXTERNAL_SECRETS="false"

# 🔐 SECURITY SETTINGS
# ---------------------
ARGOCD_ADMIN_USER="admin"
GRAFANA_ADMIN_USER="admin"
GRAFANA_ADMIN_PASSWORD="admin123"

# 📊 OBSERVABILITY
# -----------------
PROMETHEUS_RETENTION="30d"
LOKI_RETENTION="7d"

# 🎯 PROMOTION WORKFLOW
# ---------------------
AUTO_PROMOTE_TO_PRE="false"
AUTO_PROMOTE_TO_PROD="false"
PROMOTION_APPROVAL_REQUIRED="true"

# 🛠️  DEVELOPMENT OPTIONS
# ------------------------
DEBUG_MODE="false"
VERBOSE_LOGGING="false"
SKIP_RESOURCE_CHECKS="false"
EOF
}

# Non-interactive mode using git detection
auto_setup() {
    log_step "Auto-generating configuration from git repository..."
    
    local current_repo=$(detect_current_repo)
    
    if [[ -z "$current_repo" ]]; then
        log_error "Could not detect git repository. Please use interactive mode."
        log_info "Run: $0 --interactive"
        exit 1
    fi
    
    local username=$(echo "$current_repo" | cut -d'/' -f1)
    local repo=$(echo "$current_repo" | cut -d'/' -f2)
    
    log_info "Detected: $username/$repo"
    
    generate_config_file "$username" "$repo" "$username" "4" "8g" "6" "12g" "true" "true" "true"
    
    log_success "Auto-configuration completed!"
    log_warning "Please review the generated configuration: $CONFIG_FILE"
}

# Show current configuration
show_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Current configuration:"
        echo ""
        cat "$CONFIG_FILE"
    else
        log_warning "No configuration file found. Run setup first."
        log_info "Usage: $0 --setup"
    fi
}

# Main execution
main() {
    case "${1:-}" in
        --interactive|-i)
            interactive_setup
            ;;
        --auto|-a)
            auto_setup
            ;;
        --show|-s)
            show_config
            ;;
        --help|-h)
            echo "🔧 GitOps Configuration Generator"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --interactive, -i   Interactive configuration setup"
            echo "  --auto, -a         Auto-generate from git repository"
            echo "  --show, -s         Show current configuration"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --interactive   # Full interactive setup"
            echo "  $0 --auto          # Quick auto-setup"
            echo "  $0 --show          # View current config"
            ;;
        *)
            echo "🔧 GitOps Configuration Generator"
            echo ""
            log_info "Choose setup mode:"
            echo "  1. Interactive setup (recommended for first-time users)"
            echo "  2. Auto-setup (uses git repository detection)"
            echo "  3. Show current configuration"
            echo ""
            echo -n "Enter choice [1]: "
            read choice
            choice=${choice:-1}
            
            case "$choice" in
                1) interactive_setup ;;
                2) auto_setup ;;
                3) show_config ;;
                *) log_error "Invalid choice"; exit 1 ;;
            esac
            ;;
    esac
}

main "$@"
