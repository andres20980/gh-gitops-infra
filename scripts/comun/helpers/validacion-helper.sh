#!/bin/bash

# ============================================================================
# HELPER: VALIDACIÓN DE SISTEMA
# ============================================================================
# Funciones especializadas para verificación de dependencias del sistema
# Principios: Verificación rápida, Instalación inteligente, Compatibilidad
# ============================================================================

set -euo pipefail

# ============================================================================
# DETECCIÓN DE SISTEMA
# ============================================================================

# Detecta la distribución de Linux
detectar_distribucion() {
    [[ -f /etc/os-release ]] && source /etc/os-release && echo "${ID:-linux}" || echo "unknown"
}

# Detecta si estamos en WSL
detectar_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -q "microsoft" /proc/version 2>/dev/null
}

# Detecta arquitectura del sistema
detectar_arquitectura() {
    uname -m
}

# ============================================================================
# VERIFICACIÓN DE HERRAMIENTAS
# ============================================================================

# Verifica si una herramienta está instalada
verificar_herramienta() {
    local herramienta="$1"
    command -v "$herramienta" >/dev/null 2>&1
}

# Obtiene versión de una herramienta
obtener_version() {
    local herramienta="$1"
    case "$herramienta" in
        "docker") docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' ;;
        "minikube") minikube version --short 2>/dev/null | awk '{print $3}' ;;
        "kubectl") kubectl version --client --short 2>/dev/null | awk '{print $3}' ;;
        "helm") helm version --short 2>/dev/null | awk '{print $1}' | sed 's/v//' ;;
        *) echo "unknown" ;;
    esac
}

# Compara versiones (retorna 0 si v1 >= v2)
comparar_versiones() {
    local v1="$1" v2="$2"
    printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -n1 | grep -q "^$v2$"
}

# ============================================================================
# VERIFICACIÓN DE DOCKER
# ============================================================================

# Verifica si Docker está ejecutándose
verificar_docker_ejecutandose() {
    docker info >/dev/null 2>&1
}

# Verifica permisos de Docker para usuario actual
verificar_permisos_docker() {
    docker ps >/dev/null 2>&1
}

# ============================================================================
# VERIFICACIÓN DE KUBERNETES
# ============================================================================

# Obtiene versión compatible de Kubernetes para minikube
obtener_version_k8s_compatible() {
    local version_minikube="$(obtener_version minikube 2>/dev/null || echo "1.36.0")"
    
    # Mapeo de versiones minikube -> kubernetes
    case "$version_minikube" in
        1.36.*) echo "v1.31.0" ;;
        1.35.*) echo "v1.30.0" ;;
        1.34.*) echo "v1.29.0" ;;
        *) echo "v1.31.0" ;;  # default
    esac
}

# Verifica si kubectl es compatible con minikube
verificar_kubectl_compatible() {
    local version_kubectl="$(obtener_version kubectl 2>/dev/null || echo "1.0.0")"
    local version_k8s_target="$(obtener_version_k8s_compatible)"
    
    # Extraer número mayor de versión
    local major_kubectl="$(echo "$version_kubectl" | sed 's/v//' | awk -F. '{print $1"."$2}')"
    local major_k8s="$(echo "$version_k8s_target" | sed 's/v//' | awk -F. '{print $1"."$2}')"
    
    comparar_versiones "$major_kubectl" "$major_k8s"
}

# ============================================================================
# VERIFICACIÓN DE CONECTIVIDAD
# ============================================================================

# Verifica conectividad a internet
verificar_conectividad() {
    local urls=("google.com" "github.com" "docker.io")
    
    for url in "${urls[@]}"; do
        if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            return 0
        fi
    done
    
    return 1
}

# ============================================================================
# VERIFICACIÓN DE RECURSOS
# ============================================================================

# Verifica memoria disponible (en GB)
verificar_memoria() {
    local minimo="${1:-2}"  # GB mínimos
    local disponible=$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
    
    (( $(echo "$disponible >= $minimo" | bc -l) ))
}

# Verifica espacio en disco (en GB)
verificar_espacio_disco() {
    local directorio="${1:-.}"
    local minimo="${2:-10}"  # GB mínimos
    local disponible=$(df -BG "$directorio" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    (( disponible >= minimo ))
}

# ============================================================================
# FUNCIONES DE DIAGNÓSTICO
# ============================================================================

# Diagnóstico completo del sistema
diagnosticar_sistema() {
    log_info "🖥️ Sistema: $(detectar_distribucion) $(detectar_arquitectura)"
    log_info "🏗️ Entorno: $(detectar_wsl && echo "WSL detectado" || echo "Nativo")"
    log_info "💾 Memoria: $(awk '/MemAvailable/ {printf "%.1fGB disponible", $2/1024/1024}' /proc/meminfo)"
    log_info "💿 Disco: $(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')GB disponible"
    log_info "🌐 Conectividad: $(verificar_conectividad && echo "✅ OK" || echo "❌ Limitada")"
}

# Diagnóstico de herramientas
diagnosticar_herramientas() {
    local herramientas=("docker" "minikube" "kubectl" "helm")
    
    for herramienta in "${herramientas[@]}"; do
        if verificar_herramienta "$herramienta"; then
            local version="$(obtener_version "$herramienta")"
            log_info "✅ $herramienta: $version"
        else
            log_warning "❌ $herramienta: no instalado"
        fi
    done
}
