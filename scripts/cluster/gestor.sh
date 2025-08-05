#!/bin/bash

# ============================================================================
# MÓDULO DE CLUSTER - Gestión de clusters Kubernetes
# ============================================================================
# Configura y gestiona clusters Kubernetes (minikube, kind, etc.)
# Incluye configuración automática y optimización para GitOps
# ============================================================================

set -euo pipefail

# Cargar módulos comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMUN_DIR="$(dirname "$SCRIPT_DIR")/comun"
# shellcheck source=../comun/base.sh
source "$COMUN_DIR/base.sh"
# shellcheck source=../instalacion/dependencias.sh
source "$(dirname "$SCRIPT_DIR")/instalacion/dependencias.sh"

# ============================================================================
# CONFIGURACIÓN DE MINIKUBE
# ============================================================================

crear_cluster_minikube() {
    local cluster_name="${1:-gitops-dev}"
    
    log_section "🚀 Configuración de Cluster Minikube"
    
    # Auto-instalar herramientas si no están disponibles
    auto_instalar_docker
    auto_instalar_kubectl
    auto_instalar_minikube
    
    log_success "✅ Herramientas de minikube verificadas"
    
    # Verificar si el cluster ya existe
    if minikube status -p "$cluster_name" >/dev/null 2>&1; then
        local cluster_state
        cluster_state=$(minikube status -p "$cluster_name" -o json 2>/dev/null | jq -r '.Host' 2>/dev/null || echo "Unknown")
        
        if [[ "$cluster_state" == "Running" ]]; then
            log_info "✅ Cluster $cluster_name ya está ejecutándose"
            
            # Configurar kubectl context
            minikube update-context -p "$cluster_name"
            kubectl config use-context "$cluster_name"
            log_success "✅ Contexto de kubectl configurado: $cluster_name"
            
            return 0
        else
            log_warning "⚠️ Cluster $cluster_name existe pero no está corriendo"
            log_info "🔄 Reiniciando cluster..."
            minikube start -p "$cluster_name"
        fi
    else
        log_info "🆕 Creando nuevo cluster minikube: $cluster_name"
        
        # Configuración optimizada para GitOps
        local minikube_config=(
            "--driver=docker"
            "--cpus=4"
            "--memory=8192mb"
            "--disk-size=50gb"
            "--kubernetes-version=stable"
            "--addons=ingress,dashboard,metrics-server"
            "--extra-config=apiserver.service-node-port-range=80-32767"
        )
        
        # Crear cluster con configuración optimizada
        if minikube start -p "$cluster_name" "${minikube_config[@]}"; then
            log_success "✅ Cluster $cluster_name creado exitosamente"
        else
            log_error "❌ Error creando cluster minikube"
            return 1
        fi
    fi
    
    # Configurar kubectl context inmediatamente
    log_info "🔧 Configurando contexto de kubectl..."
    minikube update-context -p "$cluster_name"
    kubectl config use-context "$cluster_name"
    log_success "✅ Contexto de kubectl configurado: $cluster_name"
    
    # Habilitar metrics-server automáticamente
    log_info "🔧 Habilitando metrics-server para observabilidad completa..."
    if minikube -p "$cluster_name" addons enable metrics-server >/dev/null 2>&1; then
        log_success "✅ metrics-server habilitado correctamente"
    else
        log_warning "⚠️ metrics-server puede estar ya habilitado"
    fi
    
    # Verificar que metrics-server se habilite correctamente
    log_info "⏳ Verificando estado de metrics-server..."
    local retry_count=0
    while [[ $retry_count -lt 30 ]]; do
        if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
            log_success "✅ metrics-server deployado correctamente"
            break
        fi
        sleep 2
        ((retry_count++))
    done
    
    # Verificar conectividad del cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "✅ Conectividad al cluster verificada"
        
        # Mostrar información del cluster
        local nodes
        nodes=$(kubectl get nodes --no-headers | wc -l)
        log_info "📊 Nodos disponibles: $nodes"
        
        # Esperar a que los addons estén listos
        log_info "⏳ Esperando addons de minikube..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s 2>/dev/null || true
        
        return 0
    else
        log_error "❌ No se puede conectar al cluster"
        return 1
    fi
}

# ============================================================================
# CONFIGURACIÓN DE KIND
# ============================================================================

crear_cluster_kind() {
    local cluster_name="${1:-gitops-dev}"
    
    log_section "🚀 Configuración de Cluster Kind"
    
    # Auto-instalar herramientas si no están disponibles
    auto_instalar_docker
    auto_instalar_kubectl
    
    # Instalar kind si no está disponible
    if ! comando_existe kind; then
        log_info "⬇️ Instalando kind..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
    
    log_success "✅ Herramientas de kind verificadas"
    
    # Configuración de kind para GitOps
    local kind_config="/tmp/kind-config.yaml"
    cat > "$kind_config" << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
    
    # Crear cluster
    if kind get clusters | grep -q "^$cluster_name$"; then
        log_info "✅ Cluster $cluster_name ya existe"
    else
        log_info "🆕 Creando nuevo cluster kind: $cluster_name"
        kind create cluster --name "$cluster_name" --config "$kind_config"
        log_success "✅ Cluster $cluster_name creado exitosamente"
    fi
    
    # Configurar kubectl context
    kubectl config use-context "kind-$cluster_name"
    log_success "✅ Contexto de kubectl configurado: kind-$cluster_name"
    
    # Limpiar archivo temporal
    rm -f "$kind_config"
    
    return 0
}

# ============================================================================
# VALIDACIÓN DE CLUSTER
# ============================================================================

validar_cluster() {
    log_section "🔍 Validación de Cluster"
    
    # Verificar conectividad
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ No se puede conectar al cluster Kubernetes"
        log_info "💡 Asegúrate de que kubectl esté configurado correctamente"
        return 1
    fi
    
    log_success "✅ Conectividad al cluster verificada"
    
    # Verificar nodos
    local nodes_ready
    nodes_ready=$(kubectl get nodes --no-headers | grep -c " Ready " || echo "0")
    if [[ $nodes_ready -gt 0 ]]; then
        log_success "✅ Nodos del cluster están listos: $nodes_ready"
    else
        log_error "❌ No hay nodos listos en el cluster"
        return 1
    fi
    
    # Verificar componentes del sistema
    local system_pods_ready
    system_pods_ready=$(kubectl get pods -n kube-system --no-headers | grep -c " Running " || echo "0")
    log_info "📊 Pods del sistema ejecutándose: $system_pods_ready"
    
    return 0
}

# ============================================================================
# GESTIÓN DE CLUSTERS
# ============================================================================

eliminar_cluster() {
    local cluster_name="${1:-gitops-dev}"
    local provider="${2:-minikube}"
    
    log_section "🗑️ Eliminando Cluster"
    
    case "$provider" in
        "minikube")
            if minikube status -p "$cluster_name" >/dev/null 2>&1; then
                log_info "🗑️ Eliminando cluster minikube: $cluster_name"
                minikube delete -p "$cluster_name"
                log_success "✅ Cluster $cluster_name eliminado"
            else
                log_info "ℹ️ Cluster $cluster_name no existe"
            fi
            ;;
        "kind")
            if kind get clusters | grep -q "^$cluster_name$"; then
                log_info "🗑️ Eliminando cluster kind: $cluster_name"
                kind delete cluster --name "$cluster_name"
                log_success "✅ Cluster $cluster_name eliminado"
            else
                log_info "ℹ️ Cluster $cluster_name no existe"
            fi
            ;;
        *)
            log_error "❌ Proveedor de cluster no soportado: $provider"
            return 1
            ;;
    esac
    
    return 0
}

listar_clusters() {
    log_section "📋 Clusters Disponibles"
    
    # Listar clusters de minikube
    if comando_existe minikube; then
        log_info "→ Clusters Minikube:"
        minikube profile list 2>/dev/null || log_info "  No hay clusters minikube"
    fi
    
    # Listar clusters de kind
    if comando_existe kind; then
        log_info "→ Clusters Kind:"
        kind get clusters 2>/dev/null | sed 's/^/  /' || log_info "  No hay clusters kind"
    fi
    
    # Mostrar contexto actual
    log_info "→ Contexto actual de kubectl:"
    kubectl config current-context 2>/dev/null | sed 's/^/  /' || log_info "  No hay contexto configurado"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

configurar_cluster() {
    local cluster_name="${1:-gitops-dev}"
    local provider="${2:-minikube}"
    local action="${3:-create}"
    
    case "$action" in
        "create")
            case "$provider" in
                "minikube")
                    crear_cluster_minikube "$cluster_name"
                    ;;
                "kind")
                    crear_cluster_kind "$cluster_name"
                    ;;
                *)
                    log_error "❌ Proveedor no soportado: $provider"
                    return 1
                    ;;
            esac
            ;;
        "validate")
            validar_cluster
            ;;
        "delete")
            eliminar_cluster "$cluster_name" "$provider"
            ;;
        "list")
            listar_clusters
            ;;
        *)
            log_error "❌ Acción no soportada: $action"
            return 1
            ;;
    esac
}

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

inicializar_modulo_cluster() {
    log_debug "Módulo de cluster cargado - Gestión de clusters Kubernetes disponible"
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inicializar_modulo_cluster
    
    # Ejemplo de uso
    if [[ $# -eq 0 ]]; then
        log_info "Uso: $0 [cluster_name] [provider] [action]"
        log_info "  cluster_name: Nombre del cluster (default: gitops-dev)"
        log_info "  provider: minikube|kind (default: minikube)"
        log_info "  action: create|validate|delete|list (default: create)"
        exit 1
    fi
    
    configurar_cluster "$@"
fi
