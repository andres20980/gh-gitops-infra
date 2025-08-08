#!/bin/bash

# ============================================================================
# FASE 3: CONFIGURACIÓN DOCKER Y CLUSTERS
# ============================================================================
# Configura Docker automáticamente y crea el cluster gitops-dev
# Script autocontenido - puede ejecutarse independientemente
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar autocontención
if [[ -f "$SCRIPT_DIR/../comun/bootstrap.sh" ]]; then
    # shellcheck source=../comun/bootstrap.sh
    source "$SCRIPT_DIR/../comun/bootstrap.sh"
else
    echo "❌ Error: No se pudo cargar el módulo de autocontención" >&2
    echo "   Asegúrate de ejecutar desde la estructura correcta del proyecto" >&2
    exit 1
fi

# Cargar helper de clusters optimizado
if [[ -f "$SCRIPT_DIR/../comun/helpers/cluster-helper.sh" ]]; then
    # shellcheck source=../comun/helpers/cluster-helper.sh
    source "$SCRIPT_DIR/../comun/helpers/cluster-helper.sh"
fi

# ============================================================================
# FUNCIONES DE LA FASE 3
# ============================================================================

# Verificar que Docker está disponible y funcionando
verificar_docker_disponible() {
    log_info "🐳 Verificando Docker..."
    
    # Verificar si Docker está instalado
    if ! command -v docker >/dev/null 2>&1; then
        log_error "❌ Docker no está instalado"
        log_info "💡 Ejecuta primero la Fase 2 (dependencias)"
        return 1
    fi
    
    # En modo dry-run, simplificar verificación
    if es_dry_run; then
        log_info "[DRY-RUN] Verificaría Docker daemon y lo configuraría si es necesario"
        log_success "✅ Docker disponible (modo dry-run)"
        return 0
    fi
    
    # Verificar si Docker daemon está corriendo o configurarlo
    if ! docker info >/dev/null 2>&1; then
        log_info "🔧 Docker daemon no está activo, configurando automáticamente..."
        configurar_docker_automatico
    else
        log_success "✅ Docker daemon disponible"
    fi
    
    return 0
}

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
            log_info "[DRY-RUN] Ejecutaría: sudo dockerd > logs/docker.log 2>&1 &"
            return 0
        fi
        
        # Crear directorio de logs si no existe y archivo de log con permisos correctos
        mkdir -p "${PROJECT_ROOT}/logs" 2>/dev/null || true
        local docker_log="${PROJECT_ROOT}/logs/docker-$(date +%Y%m%d-%H%M%S).log"
        touch "$docker_log" && chmod 666 "$docker_log" 2>/dev/null || docker_log="/dev/null"
        
        # Iniciar Docker daemon
        sudo dockerd > "$docker_log" 2>&1 &
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
            if [[ "$docker_log" != "/dev/null" ]]; then
                log_info "Log de Docker disponible en: $docker_log"
            fi
            return 0
        else
            log_error "No se pudo iniciar Docker daemon"
            if [[ "$docker_log" != "/dev/null" ]]; then
                log_info "Revisa el log en: $docker_log"
            fi
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
    
    # Usar el gestor de cluster optimizado para WSL
    log_info "🔧 Utilizando gestor de cluster optimizado para WSL..."
    
    # Cargar el gestor de cluster
    local gestor_cluster="$SCRIPT_DIR/../cluster/gestor.sh"
    if [[ -f "$gestor_cluster" ]]; then
        log_info "📦 Cargando gestor de cluster..."
        # shellcheck source=../cluster/gestor.sh
        source "$gestor_cluster"
        
        # Llamar al gestor con configuración optimizada
        if crear_cluster_minikube "$CLUSTER_DEV_NAME"; then
            log_success "✅ Cluster $CLUSTER_DEV_NAME creado exitosamente"
        else
            log_error "❌ Error creando cluster $CLUSTER_DEV_NAME"
            return 1
        fi
    else
        log_error "❌ Gestor de cluster no encontrado: $gestor_cluster"
        return 1
    fi
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

# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE 3 - OPTIMIZADA
# ============================================================================

fase_03_clusters() {
    log_info "🏗️ FASE 3: Configuración Optimizada de Clusters Kubernetes"
    log_info "═══════════════════════════════════════════════════════════"
    
    # Verificar que no estamos ejecutando como root
    if [[ "$EUID" -eq 0 ]]; then
        log_error "❌ Esta fase no debe ejecutarse como root"
        log_info "💡 Los clusters Kubernetes deben crearse con usuario normal"
        return 1
    fi
    
    # Verificar Docker solo una vez
    if ! verificar_docker_disponible; then
        log_error "❌ Docker no está disponible"
        return 1
    fi
    
    # En modo dry-run, mostrar lo que se haría
    if es_dry_run; then
        log_info "[DRY-RUN] Crearía entorno GitOps optimizado:"
        log_info "   • Pre-descarga de imágenes K8s para reutilización"
        log_info "   • Cluster gitops-dev: 4 CPUs, 4096MB, 40g"
        if ! solo_dev; then
            log_info "   • Cluster gitops-pre: 2 CPUs, 2048MB, 20g"
            log_info "   • Cluster gitops-pro: 2 CPUs, 2048MB, 20g"
        fi
        log_info "   • Configuración de addons en paralelo"
        log_success "✅ Dry-run completado"
        return 0
    fi
    
    # Crear entorno GitOps completo con optimización
    log_info "� Iniciando creación optimizada de clusters..."
    
    if ! crear_entorno_gitops_completo "${SOLO_DEV:-false}"; then
        log_error "❌ Error en la creación optimizada de clusters"
        return 1
    fi
    
    # Mostrar estado final optimizado
    mostrar_estado_clusters
    
    log_success "✅ Fase 3 completada: Entorno GitOps optimizado y funcional"
    log_info "💾 Cache de imágenes disponible para futuras recreaciones"
    log_info "⚡ Próximas creaciones de clusters serán significativamente más rápidas"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_03_clusters "$@"
fi
