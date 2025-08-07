#!/bin/bash

# ============================================================================
# MÓDULO DE CLUSTER - Gestión de clusters Kubernetes
# ============================================================================
# Configura y gestiona clusters Kubernetes (minikube, kind, etc.)
# Incluye configuración automática y optimización para GitOps
# ============================================================================

set -euo pipefail

# Cargar módulo base
GESTOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../comun/base.sh
source "$GESTOR_SCRIPT_DIR/../comun/base.sh"
# shellcheck source=../instalacion/dependencias.sh
source "$GESTOR_SCRIPT_DIR/../instalacion/dependencias.sh"

# ============================================================================
# CONFIGURACIÓN DE MINIKUBE
# ============================================================================

obtener_version_kubernetes_compatible() {
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

crear_cluster_minikube() {
    local cluster_name="${1:-gitops-dev}"
    
    log_section "🚀 Configuración de Cluster Minikube"
    
    # Auto-instalar herramientas con kubectl compatible
    auto_instalar_docker
    auto_instalar_minikube
    auto_instalar_kubectl_compatible
    
    log_success "✅ Herramientas básicas verificadas"
    
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
            log_info "🔄 Reiniciando cluster existente (manteniendo imágenes)..."
            
            # Reiniciar sin borrar imágenes
            if minikube start -p "$cluster_name"; then
                log_success "✅ Cluster reiniciado correctamente"
                
                # Configurar kubectl context
                minikube update-context -p "$cluster_name"
                kubectl config use-context "$cluster_name"
                log_success "✅ Contexto de kubectl reconfigurado: $cluster_name"
                
                # Verificar que todo está funcionando
                if kubectl cluster-info >/dev/null 2>&1; then
                    log_success "✅ Cluster reiniciado y operativo"
                    local nodes
                    nodes=$(kubectl get nodes --no-headers | wc -l)
                    log_info "📊 Nodos disponibles: $nodes"
                    return 0
                fi
            else
                log_error "❌ Error reiniciando cluster"
                return 1
            fi
        fi
    else
        log_info "🆕 Creando nuevo cluster minikube: $cluster_name"
        
        # Obtener versión de Kubernetes compatible dinámicamente
        log_info "🔍 Consultando versión de Kubernetes compatible con minikube..."
        local k8s_version
        k8s_version=$(obtener_version_kubernetes_compatible)
        log_success "✅ Versión de Kubernetes seleccionada: $k8s_version"
        
        # Configuración optimizada para GitOps en WSL (usando variables de config.sh)
        local minikube_config=(
            "--driver=docker"
            "--cpus=${CLUSTER_DEV_CPUS:-4}"
            "--memory=${CLUSTER_DEV_MEMORY:-4096}mb"
            "--disk-size=${CLUSTER_DEV_DISK:-40g}"
            "--kubernetes-version=$k8s_version"
            "--extra-config=apiserver.service-node-port-range=30000-32767"
            "--extra-config=kubelet.cgroup-driver=cgroupfs"
            "--force"
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
    
    # Habilitar addons esenciales después de la creación
    log_info "🔧 Habilitando addons esenciales..."
    minikube -p "$cluster_name" addons enable ingress >/dev/null 2>&1 || log_warning "⚠️ ingress addon falló"
    minikube -p "$cluster_name" addons enable dashboard >/dev/null 2>&1 || log_warning "⚠️ dashboard addon falló"
    
    # Habilitar metrics-server automáticamente
    log_info "🔧 Habilitando metrics-server para observabilidad completa..."
    if minikube -p "$cluster_name" addons enable metrics-server >/dev/null 2>&1; then
        log_success "✅ metrics-server habilitado correctamente"
        
        # Aplicar patch para WSL si es necesario
        log_info "🔧 Configurando metrics-server para WSL..."
        kubectl patch deployment metrics-server -n kube-system --patch='
        spec:
          template:
            spec:
              containers:
              - name: metrics-server
                args:
                - --cert-dir=/tmp
                - --secure-port=4443
                - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
                - --kubelet-use-node-status-port
                - --metric-resolution=15s
                - --kubelet-insecure-tls' 2>/dev/null || log_warning "⚠️ metrics-server patch falló"
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
        
        # Esperar a que los addons estén listos con feedback detallado
        log_info "⏳ Esperando addons de minikube..."
        
        # Verificar ingress-nginx con timeout y feedback
        log_info "🔍 Verificando ingress-nginx..."
        if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=60s >/dev/null 2>&1; then
            log_success "✅ ingress-nginx está listo"
        else
            log_warning "⚠️ ingress-nginx no está completamente listo (puede necesitar más tiempo)"
        fi
        
        # Verificar dashboard si está habilitado
        log_info "🔍 Verificando dashboard..."
        if kubectl get pods -n kubernetes-dashboard >/dev/null 2>&1; then
            if kubectl wait --for=condition=ready pod -l k8s-app=kubernetes-dashboard -n kubernetes-dashboard --timeout=30s >/dev/null 2>&1; then
                log_success "✅ dashboard está listo"
            else
                log_warning "⚠️ dashboard no está completamente listo"
            fi
        else
            log_info "ℹ️ dashboard no está desplegado"
        fi
        
        # Verificar metrics-server
        log_info "🔍 Verificando metrics-server..."
        if kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=30s >/dev/null 2>&1; then
            log_success "✅ metrics-server está listo"
        else
            log_warning "⚠️ metrics-server no está completamente listo"
        fi
        
        log_success "🎉 Cluster $cluster_name configurado exitosamente!"
        log_info "📌 Para acceder al dashboard: minikube dashboard -p $cluster_name"
        
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
    local force_purge="${3:-false}"
    
    log_section "🗑️ Eliminando Cluster"
    
    case "$provider" in
        "minikube")
            if minikube status -p "$cluster_name" >/dev/null 2>&1; then
                log_info "🗑️ Eliminando cluster minikube: $cluster_name"
                
                if [[ "$force_purge" == "true" ]]; then
                    log_warning "⚠️ Eliminación completa (incluyendo imágenes en caché)"
                    minikube delete -p "$cluster_name" --purge
                else
                    log_info "🔄 Eliminación suave (manteniendo imágenes en caché)"
                    minikube delete -p "$cluster_name"
                fi
                
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
        "purge")
            eliminar_cluster "$cluster_name" "$provider" "true"
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
        log_info "  action: create|validate|delete|purge|list (default: create)"
        log_info "    delete: Elimina cluster manteniendo imágenes en caché"
        log_info "    purge:  Elimina cluster incluyendo imágenes en caché"
        exit 1
    fi
    
    configurar_cluster "$@"
fi
