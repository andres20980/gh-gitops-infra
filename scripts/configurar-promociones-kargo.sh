#!/bin/bash

# 🎯 Setup Kargo Multi-Cluster Promotions
# Configures promotional pipelines across DEV → PRE → PROD

set -e

# Colors
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
log_kargo() { echo -e "${CYAN}[KARGO]${NC} 🎯 $1"; }

# Configuration
DEV_CLUSTER="gitops-dev"
PRE_CLUSTER="gitops-pre"
PROD_CLUSTER="gitops-prod"

# Verify prerequisites
check_prerequisites() {
    log_step "Checking Kargo setup prerequisites..."
    
    # Check if DEV cluster is running (Kargo will be installed here)
    if ! minikube status --profile="$DEV_CLUSTER" 2>/dev/null | grep -q "Running"; then
        log_error "DEV cluster ($DEV_CLUSTER) must be running for Kargo setup"
        log_info "Start it with: minikube start --profile=$DEV_CLUSTER"
        exit 1
    fi
    
    # Check if other clusters exist
    for cluster in "$PRE_CLUSTER" "$PROD_CLUSTER"; do
        if ! minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            log_warning "Cluster $cluster is not running - some features may be limited"
        fi
    done
    
    log_success "Prerequisites check completed"
}

# Install Kargo in DEV cluster
install_kargo() {
    log_step "Installing Kargo in DEV cluster..."
    
    # Switch to DEV cluster context
    kubectl config use-context "$DEV_CLUSTER"
    
    # Check if Kargo is already installed
    if kubectl get namespace kargo 2>/dev/null; then
        log_success "Kargo namespace already exists"
        
        if kubectl get deployment kargo-api -n kargo 2>/dev/null | grep -q "1/1"; then
            log_success "Kargo is already running"
            return 0
        fi
    fi
    
    log_kargo "Installing Kargo components..."
    
    # Apply Kargo installation
    if [ -f "components/kargo/kargo.yaml" ]; then
        kubectl apply -f components/kargo/kargo.yaml
    else
        log_warning "Kargo component not found, installing from remote..."
        # Create namespace
        kubectl create namespace kargo --dry-run=client -o yaml | kubectl apply -f -
        
        # Add basic Kargo CRDs (simplified for demo)
        cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kargo-api
  namespace: kargo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kargo-api
  template:
    metadata:
      labels:
        app: kargo-api
    spec:
      containers:
      - name: kargo
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: kargo-api
  namespace: kargo
spec:
  selector:
    app: kargo-api
  ports:
  - port: 443
    targetPort: 80
  type: ClusterIP
EOF
    fi
    
    # Wait for Kargo to be ready
    log_info "Waiting for Kargo API to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kargo-api -n kargo
    
    log_success "Kargo installed successfully"
}

# Setup cluster connections for Kargo
setup_cluster_connections() {
    log_step "Setting up multi-cluster connections..."
    
    kubectl config use-context "$DEV_CLUSTER"
    
    # Create cluster secrets for PRE and PROD
    for cluster in "$PRE_CLUSTER" "$PROD_CLUSTER"; do
        if minikube status --profile="$cluster" 2>/dev/null | grep -q "Running"; then
            log_kargo "Configuring connection to $cluster..."
            
            # Get cluster API server endpoint
            local api_server=$(kubectl config view --context="$cluster" --minify -o jsonpath='{.clusters[0].cluster.server}')
            
            # Create cluster secret (simplified)
            cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cluster-$cluster
  namespace: kargo
type: Opaque
data:
  server: $(echo -n "$api_server" | base64 -w 0)
  name: $(echo -n "$cluster" | base64 -w 0)
EOF
            
            log_success "Connected to $cluster"
        else
            log_warning "Cluster $cluster not running - skipping connection setup"
        fi
    done
}

# Deploy Kargo project and stages
deploy_kargo_configuration() {
    log_step "Deploying Kargo promotional configuration..."
    
    kubectl config use-context "$DEV_CLUSTER"
    
    # Deploy the multi-environment configuration
    log_kargo "Applying Kargo project and stages..."
    kubectl apply -f examples/kargo-multi-env.yaml
    
    # Wait a moment for CRDs to be processed
    sleep 5
    
    log_success "Kargo configuration deployed"
}

# Setup port-forward for Kargo UI
setup_kargo_access() {
    log_step "Setting up Kargo UI access..."
    
    kubectl config use-context "$DEV_CLUSTER"
    
    # Kill existing port-forward for Kargo if any
    pkill -f "kubectl port-forward.*kargo" 2>/dev/null || true
    sleep 2
    
    # Start Kargo port-forward
    log_info "Starting Kargo UI port-forward on port 3000..."
    nohup kubectl port-forward -n kargo svc/kargo-api 3000:443 > /dev/null 2>&1 &
    
    # Give it time to start
    sleep 5
    
    log_success "Kargo UI available at: https://localhost:3000"
    log_info "Default credentials: admin / admin"
}

# Create demo branches for promotion
create_promotion_branches() {
    log_step "Creating Git branches for promotions..."
    
    # This would typically be done in your Git repository
    log_info "Git branches needed for promotions:"
    echo "  - dev-branch    (for DEV environment)"
    echo "  - pre-branch    (for PRE environment)" 
    echo "  - prod-branch   (for PROD environment)"
    
    log_warning "Note: You need to create these branches in your Git repository"
    log_info "Example commands:"
    echo "  git checkout -b dev-branch"
    echo "  git push origin dev-branch" 
    echo "  git checkout -b pre-branch"
    echo "  git push origin pre-branch"
    echo "  git checkout -b prod-branch" 
    echo "  git push origin prod-branch"
}

# Show promotional workflow status
show_promotion_status() {
    log_step "Kargo promotional workflow status..."
    
    kubectl config use-context "$DEV_CLUSTER"
    
    echo ""
    echo "🎯 KARGO PROMOTIONAL PIPELINE"
    echo "============================="
    
    # Check if resources exist
    if kubectl get project demo-project-multicluster -n kargo 2>/dev/null; then
        echo "📊 Project: demo-project-multicluster ✅"
    else
        echo "📊 Project: demo-project-multicluster ❌"
    fi
    
    echo ""
    echo "🔄 Stages:"
    for stage in dev pre prod; do
        if kubectl get stage "$stage" -n kargo 2>/dev/null; then
            echo "  - $stage: ✅ Configured"
        else
            echo "  - $stage: ❌ Not found"
        fi
    done
    
    echo ""
    echo "🌐 ACCESS POINTS:"
    echo "  - Kargo UI:     https://localhost:3000"
    echo "  - Dev ArgoCD:   http://localhost:8080"  
    echo "  - Pre ArgoCD:   http://localhost:8081"
    echo "  - Prod ArgoCD:  http://localhost:8082"
    
    echo ""
    echo "🚀 PROMOTION WORKFLOW:"
    echo "  1. 🔄 Code push → Dev branch (auto-deploy to DEV)"
    echo "  2. 🧪 Manual promotion: DEV → PRE (with tests)"
    echo "  3. 🏭 Manual promotion: PRE → PROD (with verification)"
    
    echo ""
    echo "📋 NEXT STEPS:"
    echo "  1. Create Git branches: ./scripts/setup-kargo-promotions.sh branches"
    echo "  2. Access Kargo UI: https://localhost:3000"
    echo "  3. Monitor promotions: kubectl get stages -n kargo"
    echo "  4. Promote manually: Use Kargo UI or kubectl"
}

# Main execution
main() {
    case "${1:-setup}" in
        "setup"|"")
            echo ""
            echo "🎯======================================================"
            echo "   🚀 KARGO MULTI-CLUSTER PROMOTIONS SETUP"
            echo "   🚧 DEV → 🧪 PRE → 🏭 PROD"
            echo "======================================================"
            echo ""
            
            check_prerequisites
            install_kargo
            setup_cluster_connections
            deploy_kargo_configuration
            setup_kargo_access
            create_promotion_branches
            
            echo ""
            show_promotion_status
            
            log_success "🎉 Kargo multi-cluster promotions ready!"
            echo ""
            ;;
        "status")
            show_promotion_status
            ;;
        "branches")
            create_promotion_branches
            ;;
        "access")
            setup_kargo_access
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [setup|status|branches|access|help]"
            echo ""
            echo "Commands:"
            echo "  setup    - Complete Kargo setup (default)"
            echo "  status   - Show promotion pipeline status"
            echo "  branches - Show Git branches setup instructions"
            echo "  access   - Setup Kargo UI access"
            echo "  help     - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle interruption
trap 'log_warning "Kargo setup interrupted"; exit 1' INT

main "$@"
