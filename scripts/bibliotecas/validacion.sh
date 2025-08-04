#!/bin/bash

# ============================================================================
# LIBRERÍA DE VALIDACIONES - Sistema de verificación completo
# ============================================================================
# Validaciones especializadas para cluster, dependencias y configuración
# Funciones de verificación de estado y prerequisitos
# ============================================================================

# Prevenir múltiples cargas
[[ -n "${_GITOPS_VALIDATION_LOADED:-}" ]] && return 0
readonly _GITOPS_VALIDATION_LOADED=1

# Cargar dependencias
if [[ -z "${_GITOPS_BASE_LOADED:-}" ]]; then
    # shellcheck source=./base.sh
    source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
fi

if [[ -z "${_GITOPS_LOGGING_LOADED:-}" ]]; then
    # shellcheck source=./logging.sh
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# ============================================================================
# VALIDACIONES DE COMANDOS Y HERRAMIENTAS
# ============================================================================

# Validar que un comando esté disponible
validar_comando() {
    local comando="$1"
    command -v "$comando" >/dev/null 2>&1
}

# Validar acceso a cluster Kubernetes
validar_kubernetes() {
    kubectl cluster-info >/dev/null 2>&1
}

# Validar estado de Docker
validar_docker() {
    docker ps >/dev/null 2>&1
}

# ============================================================================
# VALIDACIONES DE SISTEMA OPERATIVO
# ============================================================================

# Validar distribución Ubuntu
validar_ubuntu() {
    if ! es_ubuntu; then
        log_error "Este script requiere Ubuntu o distribución compatible"
        log_info "Distribución detectada: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
        return 1
    fi
    
    log_debug "Distribución Ubuntu verificada"
    return 0
}

# Validar arquitectura del sistema
validar_arquitectura() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "x86_64"|"amd64")
            log_debug "Arquitectura x86_64 verificada"
            return 0
            ;;
        "arm64"|"aarch64")
            log_debug "Arquitectura ARM64 verificada"
            return 0
            ;;
        *)
            log_error "Arquitectura no soportada: $arch"
            log_info "Arquitecturas soportadas: x86_64, amd64, arm64, aarch64"
            return 1
            ;;
    esac
}

# Validar versión mínima de Ubuntu
validar_version_ubuntu() {
    local version_minima="${1:-20.04}"
    local version_actual
    
    if ! es_ubuntu; then
        log_warning "No se puede verificar versión - no es Ubuntu"
        return 0
    fi
    
    version_actual=$(lsb_release -rs 2>/dev/null || echo "desconocida")
    
    if ! dpkg --compare-versions "$version_actual" ge "$version_minima"; then
        log_error "Versión de Ubuntu insuficiente"
        log_info "Versión actual: $version_actual"
        log_info "Versión mínima requerida: $version_minima"
        return 1
    fi
    
    log_debug "Versión de Ubuntu verificada: $version_actual >= $version_minima"
    return 0
}

# ============================================================================
# VALIDACIONES DE DEPENDENCIAS
# ============================================================================

# Lista de dependencias básicas del sistema
readonly DEPENDENCIAS_BASICAS=(
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

# Lista de dependencias de desarrollo
readonly DEPENDENCIAS_DESARROLLO=(
    "build-essential"
    "apt-transport-https"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "software-properties-common"
)

# Validar dependencia individual
validar_dependencia() {
    local dependencia="$1"
    local tipo="${2:-comando}"
    
    case "$tipo" in
        "comando")
            if comando_existe "$dependencia"; then
                log_debug "Dependencia '$dependencia' encontrada"
                return 0
            else
                log_debug "Dependencia '$dependencia' no encontrada"
                return 1
            fi
            ;;
        "paquete")
            if dpkg -l | grep -q "^ii.*$dependencia"; then
                log_debug "Paquete '$dependencia' instalado"
                return 0
            else
                log_debug "Paquete '$dependencia' no instalado"
                return 1
            fi
            ;;
        "archivo")
            if [[ -f "$dependencia" ]]; then
                log_debug "Archivo '$dependencia' encontrado"
                return 0
            else
                log_debug "Archivo '$dependencia' no encontrado"
                return 1
            fi
            ;;
        *)
            log_error "Tipo de validación desconocido: $tipo"
            return 1
            ;;
    esac
}

# Validar lista de dependencias
validar_dependencias() {
    local dependencias=("$@")
    local faltantes=()
    local estado=0
    
    log_debug "Validando ${#dependencias[@]} dependencias..."
    
    for dep in "${dependencias[@]}"; do
        if ! validar_dependencia "$dep" "comando"; then
            faltantes+=("$dep")
            estado=1
        fi
    done
    
    if [[ ${#faltantes[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes:"
        for dep in "${faltantes[@]}"; do
            log_check "$dep" "error"
        done
        return 1
    fi
    
    log_success "Todas las dependencias están disponibles"
    return 0
}

# Validar dependencias básicas
validar_dependencias_basicas() {
    log_debug "Validando dependencias básicas del sistema..."
    validar_dependencias "${DEPENDENCIAS_BASICAS[@]}"
}

# ============================================================================
# VALIDACIONES DE DOCKER
# ============================================================================

# Validar instalación de Docker
validar_docker() {
    if ! comando_existe "docker"; then
        log_error "Docker no está instalado"
        return 1
    fi
    
    # Verificar que el servicio esté activo
    if ! systemctl is-active --quiet docker 2>/dev/null; then
        log_error "El servicio Docker no está activo"
        log_info "Intenta: sudo systemctl start docker"
        return 1
    fi
    
    # Verificar permisos de usuario
    if ! docker info >/dev/null 2>&1; then
        log_error "Usuario no tiene permisos para usar Docker"
        log_info "Intenta: sudo usermod -aG docker \$USER && newgrp docker"
        return 1
    fi
    
    log_debug "Docker validado correctamente"
    return 0
}

# Validar versión de Docker
validar_version_docker() {
    local version_minima="${1:-20.10.0}"
    local version_actual
    
    if ! validar_docker; then
        return 1
    fi
    
    version_actual=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    
    if [[ -z "$version_actual" ]]; then
        log_error "No se pudo obtener la versión de Docker"
        return 1
    fi
    
    if ! dpkg --compare-versions "$version_actual" ge "$version_minima"; then
        log_error "Versión de Docker insuficiente"
        log_info "Versión actual: $version_actual"
        log_info "Versión mínima requerida: $version_minima"
        return 1
    fi
    
    log_debug "Versión de Docker verificada: $version_actual >= $version_minima"
    return 0
}

# ============================================================================
# VALIDACIONES DE KUBERNETES
# ============================================================================

# Validar kubectl
validar_kubectl() {
    if ! comando_existe "kubectl"; then
        log_error "kubectl no está instalado"
        return 1
    fi
    
    log_debug "kubectl encontrado"
    return 0
}

# Validar acceso al cluster
validar_acceso_cluster() {
    if ! validar_kubectl; then
        return 1
    fi
    
    # Verificar conectividad al cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "No se puede conectar al cluster de Kubernetes"
        log_info "Verifica que el cluster esté activo y kubectl configurado"
        return 1
    fi
    
    log_debug "Acceso al cluster verificado"
    return 0
}

# Validar contexto de kubectl
validar_contexto_kubectl() {
    local contexto_esperado="${1:-}"
    local contexto_actual
    
    if ! validar_kubectl; then
        return 1
    fi
    
    contexto_actual=$(kubectl config current-context 2>/dev/null)
    
    if [[ -z "$contexto_actual" ]]; then
        log_error "No hay contexto activo en kubectl"
        return 1
    fi
    
    if [[ -n "$contexto_esperado" && "$contexto_actual" != "$contexto_esperado" ]]; then
        log_error "Contexto incorrecto de kubectl"
        log_info "Contexto actual: $contexto_actual"
        log_info "Contexto esperado: $contexto_esperado"
        return 1
    fi
    
    log_debug "Contexto de kubectl verificado: $contexto_actual"
    return 0
}

# Validar versión de kubectl
validar_version_kubectl() {
    local version_minima="${1:-1.24.0}"
    local version_actual
    
    if ! validar_kubectl; then
        return 1
    fi
    
    version_actual=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/v//')
    
    if [[ -z "$version_actual" ]]; then
        log_error "No se pudo obtener la versión de kubectl"
        return 1
    fi
    
    if ! dpkg --compare-versions "$version_actual" ge "$version_minima"; then
        log_error "Versión de kubectl insuficiente"
        log_info "Versión actual: $version_actual"
        log_info "Versión mínima requerida: $version_minima"
        return 1
    fi
    
    log_debug "Versión de kubectl verificada: $version_actual >= $version_minima"
    return 0
}

# ============================================================================
# VALIDACIONES DE HELM
# ============================================================================

# Validar Helm
validar_helm() {
    if ! comando_existe "helm"; then
        log_error "Helm no está instalado"
        return 1
    fi
    
    log_debug "Helm encontrado"
    return 0
}

# Validar versión de Helm
validar_version_helm() {
    local version_minima="${1:-3.10.0}"
    local version_actual
    
    if ! validar_helm; then
        return 1
    fi
    
    version_actual=$(helm version --template='{{.Version}}' 2>/dev/null | sed 's/v//')
    
    if [[ -z "$version_actual" ]]; then
        log_error "No se pudo obtener la versión de Helm"
        return 1
    fi
    
    if ! dpkg --compare-versions "$version_actual" ge "$version_minima"; then
        log_error "Versión de Helm insuficiente"
        log_info "Versión actual: $version_actual"
        log_info "Versión mínima requerida: $version_minima"
        return 1
    fi
    
    log_debug "Versión de Helm verificada: $version_actual >= $version_minima"
    return 0
}

# ============================================================================
# VALIDACIONES DE MINIKUBE
# ============================================================================

# Validar Minikube
validar_minikube() {
    if ! comando_existe "minikube"; then
        log_error "Minikube no está instalado"
        return 1
    fi
    
    log_debug "Minikube encontrado"
    return 0
}

# Validar estado de Minikube
validar_estado_minikube() {
    if ! validar_minikube; then
        return 1
    fi
    
    local estado
    estado=$(minikube status --format='{{.Host}}' 2>/dev/null)
    
    if [[ "$estado" != "Running" ]]; then
        log_error "Minikube no está ejecutándose"
        log_info "Estado actual: ${estado:-'Desconocido'}"
        log_info "Intenta: minikube start"
        return 1
    fi
    
    log_debug "Estado de Minikube verificado: Running"
    return 0
}

# ============================================================================
# VALIDACIONES DE RECURSOS
# ============================================================================

# Validar memoria disponible
validar_memoria() {
    local memoria_minima_gb="${1:-4}"
    local memoria_disponible_kb
    local memoria_disponible_gb
    
    memoria_disponible_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    memoria_disponible_gb=$((memoria_disponible_kb / 1024 / 1024))
    
    if [[ $memoria_disponible_gb -lt $memoria_minima_gb ]]; then
        log_error "Memoria insuficiente"
        log_info "Memoria disponible: ${memoria_disponible_gb}GB"
        log_info "Memoria mínima requerida: ${memoria_minima_gb}GB"
        return 1
    fi
    
    log_debug "Memoria verificada: ${memoria_disponible_gb}GB >= ${memoria_minima_gb}GB"
    return 0
}

# Validar espacio en disco
validar_espacio_disco() {
    local espacio_minimo_gb="${1:-10}"
    local directorio="${2:-/}"
    local espacio_disponible_gb
    
    espacio_disponible_gb=$(df "$directorio" | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [[ $espacio_disponible_gb -lt $espacio_minimo_gb ]]; then
        log_error "Espacio en disco insuficiente"
        log_info "Espacio disponible en $directorio: ${espacio_disponible_gb}GB"
        log_info "Espacio mínimo requerido: ${espacio_minimo_gb}GB"
        return 1
    fi
    
    log_debug "Espacio en disco verificado: ${espacio_disponible_gb}GB >= ${espacio_minimo_gb}GB"
    return 0
}

# ============================================================================
# VALIDACIONES DE RED
# ============================================================================

# Validar conectividad a internet
validar_conectividad() {
    local host="${1:-8.8.8.8}"
    local timeout="${2:-5}"
    
    if ! timeout "$timeout" ping -c 1 "$host" >/dev/null 2>&1; then
        log_error "No hay conectividad a internet"
        log_info "No se pudo alcanzar: $host"
        return 1
    fi
    
    log_debug "Conectividad a internet verificada"
    return 0
}

# Validar acceso a registros de contenedores
validar_registros_contenedores() {
    local registros=(
        "docker.io"
        "quay.io"
        "gcr.io"
        "registry.k8s.io"
    )
    
    for registro in "${registros[@]}"; do
        if ! timeout 10 curl -s --head "https://$registro" >/dev/null 2>&1; then
            log_warning "No se pudo verificar acceso a registro: $registro"
        else
            log_debug "Acceso a registro verificado: $registro"
        fi
    done
    
    return 0
}

# ============================================================================
# VALIDACIONES COMPLEJAS
# ============================================================================

# Validar prerequisitos completos del sistema
validar_prerequisitos_sistema() {
    local errores=0
    
    log_section "🔍 Validando Prerequisitos del Sistema"
    
    # Sistema operativo
    log_subsection "Sistema Operativo"
    if ! validar_ubuntu; then ((errores++)); fi
    if ! validar_arquitectura; then ((errores++)); fi
    if ! validar_version_ubuntu "20.04"; then ((errores++)); fi
    
    # Dependencias básicas
    log_subsection "Dependencias Básicas"
    if ! validar_dependencias_basicas; then ((errores++)); fi
    
    # Recursos del sistema
    log_subsection "Recursos del Sistema"
    if ! validar_memoria 4; then ((errores++)); fi
    if ! validar_espacio_disco 10; then ((errores++)); fi
    
    # Conectividad
    log_subsection "Conectividad"
    if ! validar_conectividad; then ((errores++)); fi
    validar_registros_contenedores
    
    if [[ $errores -gt 0 ]]; then
        log_error "Se encontraron $errores problemas en los prerequisitos"
        return 1
    fi
    
    log_success "Todos los prerequisitos del sistema están OK"
    return 0
}

# Validar entorno GitOps completo
validar_entorno_gitops() {
    local errores=0
    
    log_section "🔍 Validando Entorno GitOps"
    
    # Docker
    log_subsection "Docker"
    if ! validar_docker; then ((errores++)); fi
    if ! validar_version_docker "20.10.0"; then ((errores++)); fi
    
    # Kubernetes
    log_subsection "Kubernetes"
    if ! validar_kubectl; then ((errores++)); fi
    if ! validar_version_kubectl "1.24.0"; then ((errores++)); fi
    
    # Helm
    log_subsection "Helm"
    if ! validar_helm; then ((errores++)); fi
    if ! validar_version_helm "3.10.0"; then ((errores++)); fi
    
    # Minikube
    log_subsection "Minikube"
    if ! validar_minikube; then ((errores++)); fi
    
    if [[ $errores -gt 0 ]]; then
        log_error "Se encontraron $errores problemas en el entorno GitOps"
        return 1
    fi
    
    log_success "Entorno GitOps validado correctamente"
    return 0
}

# ============================================================================
# EXPORTS PARA COMPATIBILIDAD
# ============================================================================

export -f validar_ubuntu
export -f validar_arquitectura
export -f validar_version_ubuntu
export -f validar_dependencia
export -f validar_dependencias
export -f validar_dependencias_basicas
export -f validar_docker
export -f validar_version_docker
export -f validar_kubectl
export -f validar_acceso_cluster
export -f validar_contexto_kubectl
export -f validar_version_kubectl
export -f validar_helm
export -f validar_version_helm
export -f validar_minikube
export -f validar_estado_minikube
export -f validar_memoria
export -f validar_espacio_disco
export -f validar_conectividad
export -f validar_registros_contenedores
export -f validar_prerequisitos_sistema
export -f validar_entorno_gitops
