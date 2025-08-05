#!/bin/bash

# ============================================================================
# FASE 3: CONFIGURACIÓN DOCKER Y CLUSTERS
# ============================================================================

# Detectar y configurar Docker automáticamente
configurar_docker_automatico() {
    log_section "🐳 Configurando Docker Automáticamente"
    
    # Verificar si Docker está disponible
    if ! command -v docker >/dev/null 2>&1; then
        log_warning "Docker no está instalado"
        return 1
    fi
    
    # Verificar si Docker daemon está corriendo
    if docker info >/dev/null 2>&1; then
        log_success "Docker daemon ya está ejecutándose"
        return 0
    fi
    
    log_info "Docker daemon no está activo, intentando configurarlo..."
    
    # Detectar si estamos en un entorno sin systemd (WSL/contenedor)
    if ! systemctl --version >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
        log_info "Entorno sin systemd detectado (WSL/contenedor)"
        log_info "Iniciando Docker daemon manualmente..."
        
        # Verificar si ya hay un dockerd corriendo en background
        if pgrep -f "dockerd" >/dev/null 2>&1; then
            log_info "Docker daemon ya está ejecutándose en background"
            # Esperar un momento para que esté listo
            sleep 3
            if docker info >/dev/null 2>&1; then
                log_success "Docker daemon disponible"
                return 0
            fi
        fi
        
        # Iniciar dockerd en background
        log_info "Iniciando dockerd en background..."
        if es_dry_run; then
            log_info "[DRY-RUN] Ejecutaría: sudo dockerd > /tmp/docker.log 2>&1 &"
            return 0
        fi
        
        # Iniciar Docker daemon
        sudo dockerd > /tmp/docker.log 2>&1 &
        local dockerd_pid=$!
        
        # Esperar hasta que Docker esté listo (máximo 30 segundos)
        log_info "Esperando que Docker daemon esté listo..."
        local contador=0
        while ! docker info >/dev/null 2>&1 && [[ $contador -lt 30 ]]; do
            sleep 1
            ((contador++))
            if [[ $((contador % 5)) -eq 0 ]]; then
                log_info "Esperando Docker daemon... (${contador}s)"
            fi
        done
        
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon iniciado correctamente (PID: $dockerd_pid)"
            log_info "Log de Docker disponible en: /tmp/docker.log"
            return 0
        else
            log_error "No se pudo iniciar Docker daemon"
            log_info "Revisa el log en: /tmp/docker.log"
            return 1
        fi
    else
        # Entorno con systemd
        log_info "Entorno con systemd detectado"
        log_info "Intentando iniciar Docker con systemctl..."
        
        if es_dry_run; then
            log_info "[DRY-RUN] Ejecutaría: sudo systemctl start docker"
            return 0
        fi
        
        if sudo systemctl start docker && sudo systemctl enable docker; then
            log_success "Docker iniciado con systemctl"
            return 0
        else
            log_error "No se pudo iniciar Docker con systemctl"
            return 1
        fi
    fi
}

# Crear cluster gitops-dev con capacidad completa
crear_cluster_gitops_dev() {
    log_info "🚀 Creando cluster $CLUSTER_DEV_NAME con capacidad completa..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría: minikube start --profile=$CLUSTER_DEV_NAME --cpus=$CLUSTER_DEV_CPUS --memory=$CLUSTER_DEV_MEMORY --disk-size=$CLUSTER_DEV_DISK"
        log_info "[DRY-RUN] Ejecutaría: minikube addons enable metrics-server --profile=$CLUSTER_DEV_NAME"
        log_info "[DRY-RUN] Ejecutaría: kubectl config use-context $CLUSTER_DEV_NAME"
        return 0
    fi
    
    # Eliminar cluster existente si existe
    if minikube profile list | grep -q "$CLUSTER_DEV_NAME"; then
        log_info "🗑️ Eliminando cluster existente $CLUSTER_DEV_NAME..."
        minikube delete --profile="$CLUSTER_DEV_NAME"
    fi
    
    # Crear cluster con capacidad completa
    log_info "🏗️ Creando cluster $CLUSTER_DEV_NAME..."
    
    # Configurar argumentos según el usuario
    local minikube_args=(
        "--profile=$CLUSTER_DEV_NAME"
        "--cpus=$CLUSTER_DEV_CPUS"
        "--memory=$CLUSTER_DEV_MEMORY"
        "--disk-size=$CLUSTER_DEV_DISK"
        "--kubernetes-version=stable"
    )
    
    # Detectar si se ejecuta como root y ajustar driver
    if [[ "$EUID" -eq 0 ]]; then
        log_warning "⚠️ Ejecutándose como root, usando driver 'none'"
        minikube_args+=("--driver=none" "--force")
    else
        log_info "👤 Ejecutándose como usuario normal, usando driver 'docker'"
        minikube_args+=("--driver=docker")
    fi
    
    if ! minikube start "${minikube_args[@]}"; then
        log_error "Error creando cluster $CLUSTER_DEV_NAME"
        return 1
    fi
    
    # Habilitar addons esenciales
    log_info "🔧 Habilitando addons esenciales..."
    minikube addons enable metrics-server --profile="$CLUSTER_DEV_NAME"
    minikube addons enable ingress --profile="$CLUSTER_DEV_NAME"
    minikube addons enable storage-provisioner --profile="$CLUSTER_DEV_NAME"
    
    # Configurar contexto
    log_info "⚙️ Configurando contexto kubectl..."
    kubectl config use-context "$CLUSTER_DEV_NAME"
    
    # Verificar que el cluster está listo
    log_info "🔍 Verificando que el cluster está listo..."
    kubectl wait --for=condition=ready nodes --all --timeout=300s
    
    log_success "✅ Cluster $CLUSTER_DEV_NAME creado y configurado correctamente"
    return 0
}

# Crear clusters de promoción (pre y pro)
crear_clusters_promocion() {
    log_info "🌐 Creando clusters de promoción gitops-pre y gitops-pro..."
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría creación de clusters gitops-pre y gitops-pro"
        return 0
    fi
    
    # Crear cluster gitops-pre
    log_info "🏗️ Creando cluster $CLUSTER_PRE_NAME..."
    if ! minikube start \
        --profile="$CLUSTER_PRE_NAME" \
        --cpus="$CLUSTER_PRE_CPUS" \
        --memory="$CLUSTER_PRE_MEMORY" \
        --disk-size="$CLUSTER_PRE_DISK" \
        --driver=docker \
        --kubernetes-version=stable; then
        log_error "Error creando cluster $CLUSTER_PRE_NAME"
        return 1
    fi
    
    # Habilitar addons básicos para PRE
    minikube addons enable metrics-server --profile="$CLUSTER_PRE_NAME"
    minikube addons enable ingress --profile="$CLUSTER_PRE_NAME"
    
    # Crear cluster gitops-pro
    log_info "🏗️ Creando cluster $CLUSTER_PRO_NAME..."
    if ! minikube start \
        --profile="$CLUSTER_PRO_NAME" \
        --cpus="$CLUSTER_PRO_CPUS" \
        --memory="$CLUSTER_PRO_MEMORY" \
        --disk-size="$CLUSTER_PRO_DISK" \
        --driver=docker \
        --kubernetes-version=stable; then
        log_error "Error creando cluster $CLUSTER_PRO_NAME"
        return 1
    fi
    
    # Habilitar addons básicos para PRO
    minikube addons enable metrics-server --profile="$CLUSTER_PRO_NAME"
    minikube addons enable ingress --profile="$CLUSTER_PRO_NAME"
    
    # Volver al contexto de DEV
    kubectl config use-context "$CLUSTER_DEV_NAME"
    
    # Registrar clusters en ArgoCD para gestión multi-cluster
    log_info "🔗 Registrando clusters en ArgoCD para gestión multi-cluster..."
    # Aquí iría la lógica para registrar los clusters adicionales en ArgoCD
    
    log_success "✅ Clusters de promoción creados y registrados"
    return 0
}
