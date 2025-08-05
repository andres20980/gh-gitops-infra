#!/bin/bash

# ============================================================================
# MÓDULO DE VALIDACIÓN - Verificación de prerequisitos del sistema
# ============================================================================
# Valida todas las dependencias, recursos y configuraciones necesarias
# para la instalación GitOps
# ============================================================================

set -euo pipefail

# Cargar módulo base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./base.sh
source "$SCRIPT_DIR/base.sh"

# ============================================================================
# VALIDACIÓN DE SISTEMA OPERATIVO
# ============================================================================

validar_sistema_operativo() {
    log_info "→ Sistema Operativo"
    echo "----------------------------------------"
    
    # Verificar que sea Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "Sistema operativo no compatible. Se requiere Linux"
        return 1
    fi
    
    # Verificar distribución
    local distro
    distro=$(obtener_distribucion)
    
    case "$distro" in
        ubuntu|debian)
            log_debug "Distribución $distro verificada"
            ;;
        *)
            log_warning "Distribución $distro no probada oficialmente"
            ;;
    esac
    
    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_error "Arquitectura $arch no soportada. Se requiere x86_64"
        return 1
    fi
    log_debug "Arquitectura $arch verificada"
    
    # Verificar versión de Ubuntu si aplica
    if [[ "$distro" == "ubuntu" ]]; then
        local version
        version=$(obtener_version_sistema)
        local version_number
        version_number=$(echo "$version" | cut -d'.' -f1,2)
        
        if (( $(echo "$version_number >= 20.04" | bc -l) )); then
            log_debug "Versión de Ubuntu verificada: $version >= 20.04"
        else
            log_error "Versión de Ubuntu no soportada: $version (mínimo 20.04)"
            return 1
        fi
    fi
    
    return 0
}

# ============================================================================
# VALIDACIÓN DE DEPENDENCIAS
# ============================================================================

validar_dependencias_basicas() {
    log_info "→ Dependencias Básicas"
    echo "----------------------------------------"
    
    local dependencias=(
        "curl"
        "wget" 
        "jq"
        "git"
        "unzip"
        "tar"
        "gzip"
        "awk"
        "sed"
        "grep"
    )
    
    log_debug "Validando dependencias básicas del sistema..."
    log_debug "Validando ${#dependencias[@]} dependencias..."
    
    local faltantes=()
    
    for dep in "${dependencias[@]}"; do
        if comando_existe "$dep"; then
            log_debug "Dependencia '$dep' encontrada"
        else
            log_error "Dependencia '$dep' no encontrada"
            faltantes+=("$dep")
        fi
    done
    
    if [[ ${#faltantes[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${faltantes[*]}"
        log_info "Instalar con: sudo apt update && sudo apt install -y ${faltantes[*]}"
        return 1
    fi
    
    log_success "Todas las dependencias están disponibles"
    return 0
}

# ============================================================================
# VALIDACIÓN DE RECURSOS
# ============================================================================

validar_recursos_sistema() {
    log_info "→ Recursos del Sistema"
    echo "----------------------------------------"
    
    # Verificar memoria RAM (mínimo 4GB)
    local ram_total_gb
    ram_total_gb=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/Gi\?//')
    if (( $(echo "$ram_total_gb >= 4" | bc -l) )); then
        log_debug "Memoria verificada: ${ram_total_gb}GB >= 4GB"
    else
        log_error "Memoria insuficiente: ${ram_total_gb}GB (mínimo 4GB)"
        return 1
    fi
    
    # Verificar espacio en disco (mínimo 10GB)
    local disk_available_gb
    disk_available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $disk_available_gb -ge 10 ]]; then
        log_debug "Espacio en disco verificado: ${disk_available_gb}GB >= 10GB"
    else
        log_error "Espacio en disco insuficiente: ${disk_available_gb}GB (mínimo 10GB)"
        return 1
    fi
    
    return 0
}

# ============================================================================
# VALIDACIÓN DE CONECTIVIDAD
# ============================================================================

validar_conectividad() {
    log_info "→ Conectividad"
    echo "----------------------------------------"
    
    # Verificar conectividad a internet
    if verificar_internet; then
        log_debug "Conectividad a internet verificada"
    else
        log_error "Sin conectividad a internet"
        return 1
    fi
    
    # Verificar acceso a registros de contenedores
    local registros=(
        "docker.io"
        "quay.io" 
        "gcr.io"
        "registry.k8s.io"
    )
    
    for registro in "${registros[@]}"; do
        if curl -s --connect-timeout 10 "https://$registro" >/dev/null 2>&1; then
            log_debug "Acceso a registro verificado: $registro"
        else
            log_warning "No se pudo verificar acceso a registro: $registro"
        fi
    done
    
    return 0
}

# ============================================================================
# VALIDACIÓN DE HERRAMIENTAS GITOPS
# ============================================================================

validar_herramientas_gitops() {
    log_info "→ Docker"
    echo "----------------------------------------"
    
    # Verificar Docker
    if comando_existe docker; then
        log_debug "Docker encontrado"
        
        # Verificar si Docker daemon está funcionando
        if docker info >/dev/null 2>&1; then
            log_debug "Docker daemon está funcionando"
        else
            log_warning "Docker daemon no está funcionando"
            if tiene_systemd; then
                log_warning "El servicio Docker no está activo. Intentando iniciarlo..."
                if sudo systemctl enable docker >/dev/null 2>&1; then
                    log_debug "Servicio Docker habilitado para arranque automático"
                fi
                
                if sudo systemctl start docker >/dev/null 2>&1; then
                    log_success "Servicio Docker iniciado correctamente"
                else
                    log_error "No se pudo iniciar el servicio Docker"
                    log_info "Intenta manualmente: sudo systemctl start docker"
                    return 1
                fi
            else
                log_warning "Sistema sin systemd detectado (WSL/contenedor)"
                log_info "Docker se configurará automáticamente durante la instalación"
            fi
        fi
    else
        log_warning "Docker no encontrado - se instalará automáticamente"
    fi
    
    log_info "→ Kubernetes"
    echo "----------------------------------------"
    
    # Verificar kubectl
    if comando_existe kubectl; then
        log_debug "kubectl encontrado"
        local kubectl_version
        kubectl_version=$(kubectl version --client --short 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 | sed 's/v//')
        log_debug "kubectl encontrado"
        
        # Verificar versión mínima (1.24.0)
        if [[ -n "$kubectl_version" ]]; then
            local min_version="1.24.0"
            if printf '%s\n%s\n' "$min_version" "$kubectl_version" | sort -V | head -1 | grep -q "^$min_version"; then
                log_debug "Versión de kubectl verificada: $kubectl_version >= $min_version"
            else
                log_warning "Versión de kubectl antigua: $kubectl_version (mínimo $min_version)"
            fi
        fi
    else
        log_warning "kubectl no encontrado - se instalará automáticamente"
    fi
    
    log_info "→ Helm"
    echo "----------------------------------------"
    
    # Verificar Helm
    if comando_existe helm; then
        log_debug "Helm encontrado"
        local helm_version
        helm_version=$(helm version --short 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 | sed 's/v//')
        log_debug "Helm encontrado"
        
        # Verificar versión mínima (3.10.0)
        if [[ -n "$helm_version" ]]; then
            local min_version="3.10.0"
            if printf '%s\n%s\n' "$min_version" "$helm_version" | sort -V | head -1 | grep -q "^$min_version"; then
                log_debug "Versión de Helm verificada: $helm_version >= $min_version"
            else
                log_warning "Versión de Helm antigua: $helm_version (mínimo $min_version)"
            fi
        fi
    else
        log_warning "Helm no encontrado - se instalará automáticamente"
    fi
    
    log_info "→ Minikube"
    echo "----------------------------------------"
    
    # Verificar Minikube
    if comando_existe minikube; then
        log_debug "Minikube encontrado"
    else
        log_warning "Minikube no encontrado - se instalará automáticamente"
    fi
    
    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE VALIDACIÓN
# ============================================================================

validar_prerequisitos() {
    log_section "🔍 Validando Prerequisitos del Sistema"
    
    local errores=0
    
    # Validar sistema operativo
    if ! validar_sistema_operativo; then
        ((errores++))
    fi
    
    # Validar dependencias básicas
    if ! validar_dependencias_basicas; then
        ((errores++))
    fi
    
    # Validar recursos del sistema
    if ! validar_recursos_sistema; then
        ((errores++))
    fi
    
    # Validar conectividad
    if ! validar_conectividad; then
        ((errores++))
    fi
    
    if [[ $errores -eq 0 ]]; then
        log_success "Todos los prerequisitos del sistema están OK"
    else
        log_error "Se encontraron $errores problemas en los prerequisitos"
        return 1
    fi
    
    # Validar recursos del sistema con información detallada
    log_debug "Validando recursos del sistema..."
    local ram_total_gb
    ram_total_gb=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/Gi\?//')
    log_debug "Memoria RAM suficiente: ${ram_total_gb}GB"
    
    local cpu_cores
    cpu_cores=$(nproc)
    log_debug "CPUs suficientes: $cpu_cores cores"
    
    local disk_available_gb
    disk_available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_debug "Espacio en disco suficiente: ${disk_available_gb}GB"
    
    return 0
}

validar_entorno_gitops() {
    log_section "🔍 Validando Entorno GitOps"
    
    local errores=0
    
    # Validar herramientas GitOps
    if ! validar_herramientas_gitops; then
        ((errores++))
    fi
    
    if [[ $errores -eq 0 ]]; then
        log_success "Entorno GitOps validado correctamente"
        return 0
    else
        log_error "Se encontraron $errores problemas en el entorno GitOps"
        log_warning "Entorno GitOps incompleto - se procederá a instalación"
        return 0  # No fallar, solo advertir
    fi
}

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

inicializar_modulo_validacion() {
    log_debug "Módulo de validación cargado - Funciones de prerequisitos disponibles"
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inicializar_modulo_validacion
    validar_prerequisitos
    validar_entorno_gitops
fi
