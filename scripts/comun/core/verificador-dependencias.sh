#!/bin/bash

# ============================================================================
# DEPENDENCY CHECKER DRY - Verificador Universal de Dependencias
# ============================================================================
# Responsabilidad: Verificación genérica y reutilizable de dependencias
# Principios: Single Responsibility, DRY, Configurable, Testeable
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN DRY
# ============================================================================

# Mapa de extractores de versión (DRY)
declare -A VERSION_EXTRACTORS=(
    ["docker"]='docker --version | grep -oP "(?<=version )\d+\.\d+" || echo "0.0"'
    ["minikube"]='minikube version | grep -oP "(?<=version: v)\d+\.\d+" || echo "0.0"'
    ["kubectl"]='kubectl version --client | grep -oP "(?<=GitVersion:\"v)\d+\.\d+" || echo "0.0"'
    ["helm"]='helm version | grep -oP "(?<=Version:\"v)\d+\.\d+" || echo "0.0"'
    ["git"]='git --version | grep -oP "(?<=version )\d+\.\d+" || echo "0.0"'
)

# ============================================================================
# FUNCIONES ATÓMICAS DRY
# ============================================================================

# Verificar si comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Obtener versión de herramienta (DRY)
get_tool_version() {
    local tool="$1"
    
    if [[ -z "${VERSION_EXTRACTORS[$tool]:-}" ]]; then
        log_error "Herramienta no soportada: $tool"
        return 1
    fi
    
    eval "${VERSION_EXTRACTORS[$tool]}" 2>/dev/null || echo "0.0"
}

# Comparar versiones (formato major.minor)
version_compare() {
    local version1="$1"
    local version2="$2"
    
    local v1_major v1_minor v2_major v2_minor
    v1_major=$(echo "$version1" | cut -d'.' -f1)
    v1_minor=$(echo "$version1" | cut -d'.' -f2 2>/dev/null || echo "0")
    v2_major=$(echo "$version2" | cut -d'.' -f1)
    v2_minor=$(echo "$version2" | cut -d'.' -f2 2>/dev/null || echo "0")
    
    local v1_int=$((v1_major * 100 + v1_minor))
    local v2_int=$((v2_major * 100 + v2_minor))
    
    if [[ $v1_int -gt $v2_int ]]; then
        echo "1"  # version1 > version2
    elif [[ $v1_int -lt $v2_int ]]; then
        echo "-1" # version1 < version2
    else
        echo "0"  # version1 == version2
    fi
}

# ============================================================================
# API PÚBLICA DRY
# ============================================================================

# Verificar herramienta con versión mínima
check_tool_version() {
    local tool="$1"
    local min_version="$2"
    local description="${3:-$tool}"
    
    # Verificar existencia
    if ! command_exists "$tool"; then
        log_debug "❌ $description no está instalado"
        return 1
    fi
    
    # Obtener versión actual
    local current_version
    current_version=$(get_tool_version "$tool")
    
    # Comparar versiones
    local comparison
    comparison=$(version_compare "$current_version" "$min_version")
    
    if [[ "$comparison" -ge 0 ]]; then
        log_success "✅ $description v$current_version (>= v$min_version)"
        return 0
    else
        log_warning "⚠️ $description v$current_version < v$min_version requerida"
        return 1
    fi
}

# Verificar múltiples herramientas (formato: "tool:version:description")
check_multiple_tools() {
    local tools_spec=("$@")
    local all_ok=true
    
    for spec in "${tools_spec[@]}"; do
        IFS=':' read -r tool min_version description <<< "$spec"
        
        if ! check_tool_version "$tool" "$min_version" "$description"; then
            all_ok=false
        fi
    done
    
    $all_ok
}

# Verificar herramientas críticas del sistema
check_system_dependencies() {
    local critical_tools=(
        "docker:20.10:Docker Engine"
        "kubectl:1.25:Cliente Kubernetes"
        "helm:3.8:Gestor de paquetes K8s"
        "git:2.30:Control de versiones"
    )
    
    log_info "🔍 Verificando dependencias críticas del sistema..."
    
    if check_multiple_tools "${critical_tools[@]}"; then
        log_success "✅ Todas las dependencias críticas están disponibles"
        return 0
    else
        log_error "❌ Faltan dependencias críticas"
        return 1
    fi
}

# Verificar herramientas opcionales
check_optional_dependencies() {
    local optional_tools=(
        "minikube:1.30:Kubernetes local"
    )
    
    log_info "🔍 Verificando herramientas opcionales..."
    check_multiple_tools "${optional_tools[@]}"
}

# ============================================================================
# UTILIDADES DE DIAGNÓSTICO
# ============================================================================

# Mostrar resumen de herramientas instaladas
show_tools_summary() {
    log_section "📋 Resumen de Herramientas del Sistema"
    
    local tools=("docker" "kubectl" "minikube" "helm" "git")
    
    for tool in "${tools[@]}"; do
        if command_exists "$tool"; then
            local version
            version=$(get_tool_version "$tool")
            log_info "  ✅ $tool v$version"
        else
            log_info "  ❌ $tool (no instalado)"
        fi
    done
}

# ============================================================================
# TESTING FRAMEWORK
# ============================================================================

# Test unitario para verificación de versiones
test_version_comparison() {
    local test_cases=(
        "2.1:2.0:1"    # 2.1 > 2.0
        "1.5:1.5:0"    # 1.5 == 1.5
        "1.2:1.5:-1"   # 1.2 < 1.5
        "10.0:2.0:1"   # 10.0 > 2.0
    )
    
    for case in "${test_cases[@]}"; do
        IFS=':' read -r v1 v2 expected <<< "$case"
        local result
        result=$(version_compare "$v1" "$v2")
        
        if [[ "$result" == "$expected" ]]; then
            echo "✅ Test: $v1 vs $v2 = $result (esperado: $expected)"
        else
            echo "❌ Test: $v1 vs $v2 = $result (esperado: $expected)"
            return 1
        fi
    done
    
    echo "✅ Todos los tests de comparación de versiones pasaron"
}

# ============================================================================
# EJECUCIÓN DIRECTA (Testing)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🧪 Ejecutando tests del dependency checker..."
    test_version_comparison
    echo "🧪 Tests completados"
fi
