#!/bin/bash

# ============================================================================
# PREPARACIÓN DEL ENTORNO - Configuración inicial del cluster y herramientas
# ============================================================================

set -euo pipefail

# Directorio base del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar librerías
source "${SCRIPT_DIR}/lib/comun.sh"
source "${SCRIPT_DIR}/lib/registro.sh"

# Función para instalar minikube si no existe
setup_minikube() {
    log_subsection "Configuración de Minikube"
    
    if ! command_exists minikube; then
        log_info "Instalando Minikube..."
        execute_command "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" "Descargando Minikube"
        execute_command "sudo install minikube-linux-amd64 /usr/local/bin/minikube" "Instalando Minikube"
        execute_command "rm minikube-linux-amd64" "Limpiando archivos temporales"
    else
        log_success "✅ Minikube ya está instalado"
    fi
    
    # Verificar si hay un cluster activo
    if minikube status >/dev/null 2>&1; then
        log_success "✅ Cluster Minikube activo detectado"
        local profile=$(minikube profile)
        log_info "   Perfil activo: $profile"
    else
        log_info "Creando nuevo cluster Minikube..."
        
        # Configuración optimizada según recursos
        local memory_mb="4096"
        local cpus="2"
        
        if [[ "${LOW_RESOURCES_MODE:-false}" == "true" ]]; then
            memory_mb="2048"
            cpus="2"
            log_info "   Modo recursos limitados: ${memory_mb}MB RAM, ${cpus} CPUs"
        else
            memory_mb="6144"
            cpus="4"
            log_info "   Modo recursos normales: ${memory_mb}MB RAM, ${cpus} CPUs"
        fi
        
        execute_command "minikube start --memory=${memory_mb} --cpus=${cpus} --driver=docker --profile=gitops-dev" "Creando cluster Minikube"
        execute_command "minikube addons enable ingress --profile=gitops-dev" "Habilitando Ingress addon"
        execute_command "minikube addons enable metrics-server --profile=gitops-dev" "Habilitando Metrics Server"
    fi
}

# Función para configurar kubectl context
setup_kubectl_context() {
    log_subsection "Configuración de kubectl"
    
    # Asegurar que kubectl esté configurado para minikube
    execute_command "kubectl config use-context gitops-dev" "Configurando contexto kubectl"
    
    # Verificar conectividad
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "✅ Conectividad a cluster verificada"
        local server=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name=="gitops-dev") | .cluster.server')
        log_info "   Server: $server"
    else
        log_error "❌ No se puede conectar al cluster"
        return 1
    fi
}

# Función para configurar repositorios Helm
setup_helm_repos() {
    log_subsection "Configuración de Repositorios Helm"
    
    # Actualizar repos existentes
    execute_command "helm repo update" "Actualizando repositorios existentes"
    
    # Agregar repositorios necesarios
    for repo_name in "${!HELM_REPOS[@]}"; do
        add_helm_repo_if_not_exists "$repo_name" "${HELM_REPOS[$repo_name]}"
    done
    
    # Actualización final
    execute_command "helm repo update" "Actualización final de repositorios"
    
    log_success "✅ Repositorios Helm configurados"
}

# Función para crear namespaces base
setup_base_namespaces() {
    log_subsection "Creación de Namespaces Base"
    
    local base_namespaces=(
        "$ARGOCD_NAMESPACE"
        "$KARGO_NAMESPACE"
        "$MONITORING_NAMESPACE"
        "$INGRESS_NAMESPACE"
        "$CERT_MANAGER_NAMESPACE"
        "$EXTERNAL_SECRETS_NAMESPACE"
    )
    
    for namespace in "${base_namespaces[@]}"; do
        create_namespace_if_not_exists "$namespace"
    done
    
    log_success "✅ Namespaces base configurados"
}

# Función para verificar recursos del cluster
verify_cluster_resources() {
    log_subsection "Verificación de Recursos del Cluster"
    
    # Verificar nodos
    local node_count=$(kubectl get nodes --no-headers | wc -l)
    log_info "🔍 Nodos disponibles: $node_count"
    
    if [[ $node_count -eq 0 ]]; then
        log_error "❌ No hay nodos disponibles"
        return 1
    fi
    
    # Verificar recursos computacionales
    check_cluster_resources
    
    # Verificar storage classes
    local storage_classes=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
    if [[ $storage_classes -eq 0 ]]; then
        log_warning "⚠️  No hay StorageClasses configuradas"
        log_info "   Configurando StorageClass por defecto..."
        # Minikube debería tener una StorageClass por defecto
        kubectl get storageclass
    else
        log_success "✅ StorageClasses disponibles: $storage_classes"
        kubectl get storageclass --no-headers | while read -r line; do
            log_info "   → $line"
        done
    fi
}

# Función para configurar RBAC básico
setup_basic_rbac() {
    log_subsection "Configuración RBAC Básica"
    
    # Crear ServiceAccount para ArgoCD si no existe
    if ! kubectl get serviceaccount argocd-server -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
        create_namespace_if_not_exists "$ARGOCD_NAMESPACE"
        execute_command "kubectl create serviceaccount argocd-server -n $ARGOCD_NAMESPACE" "Creando ServiceAccount ArgoCD"
    fi
    
    # Verificar permisos cluster-admin
    if kubectl auth can-i '*' '*' --all-namespaces >/dev/null 2>&1; then
        log_success "✅ Permisos cluster-admin verificados"
    else
        log_warning "⚠️  Permisos limitados detectados"
        log_info "   Algunos componentes pueden requerir permisos adicionales"
    fi
}

# Función principal
main() {
    log_header "Preparación del Entorno GitOps" "v2.2.0"
    
    # Verificar prerequisitos básicos
    if ! command_exists kubectl; then
        log_error "kubectl no está instalado"
        exit 1
    fi
    
    if ! command_exists helm; then
        log_error "helm no está instalado"
        exit 1
    fi
    
    # Ejecutar configuración paso a paso
    setup_minikube
    setup_kubectl_context
    setup_helm_repos
    setup_base_namespaces
    verify_cluster_resources
    setup_basic_rbac
    
    # Resumen final
    echo ""
    log_section "✅ Entorno Preparado Exitosamente"
    
    log_info "📋 Resumen de configuración:"
    log_info "  • Cluster: $(kubectl config current-context)"
    log_info "  • Nodos: $(kubectl get nodes --no-headers | wc -l)"
    log_info "  • Namespaces: $(kubectl get namespaces --no-headers | wc -l)"
    log_info "  • StorageClasses: $(kubectl get storageclass --no-headers | wc -l)"
    log_info "  • Repos Helm: $(helm repo list 2>/dev/null | wc -l)"
    log_info "  • Modo recursos: ${LOW_RESOURCES_MODE:-false}"
    
    echo ""
    log_success "🎉 Entorno listo para instalación de componentes GitOps"
}

# Ejecutar si el script se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
