#!/bin/bash

# 📦 Gitea Setup and Repository Initialization
# ============================================
# This script sets up Gitea with the GitOps infrastructure repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Load configuration
CONFIG_FILE="config/environment.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    GITHUB_REPO_URL="https://github.com/andres20980/gh-gitops-infra.git"
    GITEA_PORT="3002"
fi

log_info() { echo -e "${BLUE}[INFO]${NC} 🔍 $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} ✅ $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} ⚠️  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} ❌ $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} 🚀 $1"; }

# Wait for Gitea to be ready
wait_for_gitea() {
    local max_attempts=30
    local attempt=1
    
    log_step "Waiting for Gitea to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl get pods -n gitea -l app.kubernetes.io/name=gitea | grep -q "Running"; then
            log_success "Gitea pod is running"
            
            # Wait for service to be ready
            sleep 10
            if kubectl port-forward -n gitea svc/gitea-http 3002:3000 --address=0.0.0.0 &>/dev/null &
            then
                local pf_pid=$!
                sleep 5
                
                if curl -s http://localhost:3002 >/dev/null 2>&1; then
                    kill $pf_pid 2>/dev/null || true
                    log_success "Gitea is ready and accessible"
                    return 0
                fi
                kill $pf_pid 2>/dev/null || true
            fi
        fi
        
        log_info "Attempt $attempt/$max_attempts - Gitea not ready yet, waiting..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Gitea failed to become ready after $max_attempts attempts"
    return 1
}

# Setup port-forward for Gitea
setup_gitea_access() {
    log_step "Setting up Gitea access..."
    
    # Kill any existing port-forwards
    pkill -f "kubectl port-forward.*gitea" 2>/dev/null || true
    sleep 2
    
    # Start port-forward in background
    kubectl port-forward -n gitea svc/gitea-http 3002:3000 --address=0.0.0.0 >/dev/null 2>&1 &
    local pf_pid=$!
    
    sleep 5
    
    if ps -p $pf_pid > /dev/null; then
        log_success "Gitea accessible at: http://localhost:3002"
        log_info "Admin credentials: admin / admin123"
        return 0
    else
        log_error "Failed to setup Gitea port-forward"
        return 1
    fi
}

# Create GitOps repository in Gitea
create_gitops_repository() {
    log_step "Setting up GitOps repository in Gitea..."
    
    # This would require Gitea API calls or manual setup
    # For now, just provide instructions
    echo ""
    log_info "📝 Manual setup required:"
    echo "   1. Open: http://localhost:3002"
    echo "   2. Login with: admin / admin123" 
    echo "   3. Create new repository: 'gitops-infra'"
    echo "   4. Push your current repository to Gitea"
    echo ""
    log_info "🔧 To push to Gitea:"
    echo "   git remote add gitea http://localhost:3002/admin/gitops-infra.git"
    echo "   git push gitea main"
    echo ""
}

# Update ArgoCD applications to use Gitea
update_argocd_for_gitea() {
    log_step "Updating ArgoCD applications to use Gitea..."
    log_warning "This requires manual update of repository URLs in ArgoCD applications"
    echo ""
    log_info "📝 Update needed in:"
    echo "   - gitops-infra-apps.yaml"
    echo "   - projects/demo-project/app-of-apps.yaml"
    echo "   - All application manifests in projects/"
    echo ""
    log_info "🔧 Change repository URL to:"
    echo "   http://gitea-http.gitea.svc.cluster.local:3000/admin/gitops-infra.git"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "📦===================================================="
    echo "   🔧 GITEA SETUP FOR GITOPS INFRASTRUCTURE"
    echo "   🔄 Pod-based Git Server with Persistence"
    echo "===================================================="
    echo ""
    
    log_info "Setting up Gitea as internal Git server..."
    
    # Wait for Gitea to be ready
    wait_for_gitea
    
    # Setup access
    setup_gitea_access
    
    # Provide setup instructions
    create_gitops_repository
    
    # Show next steps
    update_argocd_for_gitea
    
    echo ""
    log_success "🎉 Gitea setup completed!"
    log_info "📊 Gitea Status:"
    echo "   URL: http://localhost:3002"
    echo "   Admin: admin / admin123"
    echo "   Storage: Persistent (survives pod restarts)"
    echo "   Repositories: Stored in /data/git/repositories"
    echo ""
    log_warning "⚠️  Next: Manually create and configure your GitOps repository"
    echo ""
}

# Handle interruption
trap 'log_error "Gitea setup interrupted"; exit 1' INT

main "$@"
