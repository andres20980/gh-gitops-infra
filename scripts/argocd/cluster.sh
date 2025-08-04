#!/bin/bash

# ============================================================================
# MÓDULO DE CLUSTER - Auto-instalación desatendida de Kubernetes
# ============================================================================
# Auto-detección y configuración de clusters Kubernetes
# Soporte para minikube con auto-instalación de dependencias
# ============================================================================

set -euo pipefail

# Directorio del módulo
readonly MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BIBLIOTECAS_DIR="$(dirname "$MODULE_DIR")/bibliotecas"

# Cargar bibliotecas
for lib in "base" "logging" "validacion" "versiones"; do
    lib_path="$BIBLIOTECAS_DIR/${lib}.sh"
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
    fi
done

# ============================================================================
# AUTO-DETECCIÓN Y CONFIGURACIÓN DE MINIKUBE
# ============================================================================

# Auto-instalar minikube si no está disponible
auto_configurar_minikube() {
    log_section "🎯 Auto-Configuración de Minikube"
    
    # Verificar si minikube está instalado
    if ! command -v minikube >/dev/null 2>&1; then
        log_warning "⚠️ minikube no encontrado - instalando automáticamente..."
        if declare -f auto_instalar_minikube >/dev/null 2>&1; then
            auto_instalar_minikube
        else
            log_error "❌ Función de auto-instalación no disponible"
            return 1
        fi
    fi
    
    # Verificar si kubectl está instalado con versión compatible
    if ! command -v kubectl >/dev/null 2>&1; then
        log_warning "⚠️ kubectl no encontrado - instalando versión compatible..."
        if declare -f auto_instalar_kubectl >/dev/null 2>&1; then
            auto_instalar_kubectl
        else
            log_error "❌ Función de auto-instalación no disponible"
            return 1
        fi
    fi
    
    log_success "✅ Herramientas de minikube verificadas"
}

# Crear cluster minikube de forma desatendida
configurar_cluster_minikube() {
    log_section "🚀 Configuración Automática de Cluster Principal (gitops-dev)"
    
    local cluster_name="${CLUSTER_NAME:-gitops-dev}"
    
    # Auto-configurar herramientas necesarias
    auto_configurar_minikube
    
    # Verificar si el cluster ya existe
    if minikube status -p "$cluster_name" >/dev/null 2>&1; then
        local cluster_state
        cluster_state=$(minikube status -p "$cluster_name" -o json 2>/dev/null | jq -r '.Host' 2>/dev/null || echo "Unknown")
        
        if [[ "$cluster_state" == "Running" ]]; then
            log_info "✅ Cluster $cluster_name ya está ejecutándose"
            
            # Configurar kubectl context
            minikube update-context -p "$cluster_name"
            kubectl config use-context "$cluster_name"
            
            return 0
        else
            log_warning "⚠️ Cluster $cluster_name existe pero no está corriendo"
            log_info "🔄 Reiniciando cluster..."
            minikube start -p "$cluster_name"
        fi
    else
        log_info "🆕 Creando nuevo cluster minikube: $cluster_name"
        
        # Configuración automática optimizada para GitOps con versión estable de Kubernetes
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
            
            # Habilitar metrics-server automáticamente para observabilidad completa
            log_info "🔧 Habilitando metrics-server para observabilidad completa..."
            if minikube -p "$cluster_name" addons enable metrics-server >/dev/null 2>&1; then
                log_success "✅ metrics-server habilitado correctamente"
            else
                log_warning "⚠️ Error habilitando metrics-server (puede estar ya habilitado)"
            fi
        else
            log_error "❌ Error creando cluster minikube"
            return 1
        fi
    fi
    
    # Configurar kubectl context
    minikube update-context -p "$cluster_name"
    kubectl config use-context "$cluster_name"
    
    # Verificar conectividad
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

# Validar cluster existente
validar_cluster_existente() {
    log_section "🔍 Validación de Cluster Existente"
    
    # Verificar si kubectl puede conectar
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ No se puede conectar al cluster Kubernetes"
        log_info "💡 Asegúrate de que kubectl esté configurado correctamente"
        return 1
    fi
    
    # Obtener información del cluster
    local cluster_info
    cluster_info=$(kubectl config current-context 2>/dev/null || echo "Unknown")
    log_info "📊 Cluster actual: $cluster_info"
    
    # Verificar nodos
    local nodes
    nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [[ $nodes -gt 0 ]]; then
        log_success "✅ Cluster con $nodes nodos disponible"
        return 0
    else
        log_error "❌ No hay nodos disponibles en el cluster"
        return 1
    fi
}

# Auto-detectar y configurar cluster
auto_detectar_cluster() {
    log_section "🔍 Auto-Detección de Cluster"
    
    # Intentar conectar a cluster existente
    if kubectl cluster-info >/dev/null 2>&1; then
        log_info "✅ Cluster Kubernetes detectado"
        validar_cluster_existente
        return $?
    fi
    
    # Si no hay cluster, crear minikube automáticamente
    log_info "🎯 No se detectó cluster - configurando minikube automáticamente"
    configurar_cluster_minikube
    return $?
}

# ============================================================================
# FUNCIONES PÚBLICAS DEL MÓDULO
# ============================================================================

# ============================================================================
# CLUSTERS MÍNIMOS PARA PROMOCIONES
# ============================================================================

# Crear cluster mínimo con recursos reducidos
crear_cluster_minimo() {
    local cluster_name="${1:-gitops-mini}"
    
    log_info "Creando cluster mínimo: $cluster_name"
    
    # Parar el cluster si ya existe
    if minikube status -p "$cluster_name" >/dev/null 2>&1; then
        log_info "Cluster $cluster_name ya existe, recreando..."
        minikube delete -p "$cluster_name" >/dev/null 2>&1 || true
    fi
    
    # Crear cluster con recursos mínimos y versión estable
    local minikube_cmd=(
        minikube start
        --profile="$cluster_name"
        --driver=docker
        --cpus=1
        --memory=1024
        --disk-size=5GB
        --kubernetes-version=stable
        --container-runtime=containerd
        --addons=dashboard,metrics-server
    )
    
    if "${minikube_cmd[@]}"; then
        log_success "✅ Cluster mínimo $cluster_name creado"
        
        # Configurar contexto
        local context_name="$cluster_name"
        kubectl config rename-context "$cluster_name" "$context_name" 2>/dev/null || true
        
        return 0
    else
        log_error "❌ Error creando cluster mínimo $cluster_name"
        return 1
    fi
}

# Configurar contextos para Kargo
configurar_contextos_kargo() {
    log_info "Configurando contextos para promociones Kargo..."
    
    # Lista de clusters esperados
    local clusters=("gitops-dev" "gitops-pre" "gitops-pro")
    local contextos_ok=0
    
    for cluster in "${clusters[@]}"; do
        if kubectl config get-contexts "$cluster" >/dev/null 2>&1; then
            log_success "✅ Contexto $cluster disponible"
            ((contextos_ok++))
        else
            log_warning "⚠️ Contexto $cluster no disponible"
        fi
    done
    
    if [[ $contextos_ok -ge 2 ]]; then
        log_success "✅ Suficientes contextos para promociones Kargo"
        
        # Volver al contexto principal
        kubectl config use-context gitops-dev >/dev/null 2>&1 || true
        
        return 0
    else
        log_warning "⚠️ Contextos insuficientes para promociones Kargo"
        return 1
    fi
}

# Función principal del módulo
configurar_cluster() {
    local provider="${1:-auto}"
    
    case "$provider" in
        "minikube")
            configurar_cluster_minikube
            ;;
        "existente")
            validar_cluster_existente
            ;;
        "auto"|*)
            auto_detectar_cluster
            ;;
    esac
}

# Exports para uso externo
export -f configurar_cluster_minikube
export -f validar_cluster_existente
export -f auto_detectar_cluster
export -f configurar_cluster
export -f crear_cluster_minimo
export -f configurar_contextos_kargo

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configurar_cluster "${1:-auto}"
fi
