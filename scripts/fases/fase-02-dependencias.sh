#!/bin/bash

# ============================================================================
# FASE 2: VERIFICACIÓN Y ACTUALIZACIÓN DE DEPENDENCIAS
# ============================================================================
# Verifica e instala todas las dependencias necesarias del sistema
# Script autocontenido - puede ejecutarse independientemente
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar autocontención
if [[ -f "$SCRIPT_DIR/../comun/autocontener.sh" ]]; then
    # shellcheck source=../comun/autocontener.sh
    source "$SCRIPT_DIR/../comun/autocontener.sh"
else
    echo "❌ Error: No se pudo cargar el módulo de autocontención" >&2
    echo "   Asegúrate de ejecutar desde la estructura correcta del proyecto" >&2
    exit 1
fi

# ============================================================================
# FUNCIONES DE LA FASE X
# ============================================================================

# Ejecutar instalación de dependencias del sistema
ejecutar_instalacion_dependencias() {
    local instalador_deps="$SCRIPTS_DIR/instalacion/dependencias.sh"
    
    if [[ ! -f "$instalador_deps" ]]; then
        log_error "Instalador de dependencias no encontrado: $instalador_deps"
        return 1
    fi
    
    log_section "📦 Ejecutando Instalación de Dependencias del Sistema"
    
    if es_dry_run; then
        log_info "[DRY-RUN] Ejecutaría: bash $instalador_deps"
        return 0
    fi
    
    # Ejecutar instalación de dependencias sin parámetros adicionales
    # (el script de dependencias no maneja parámetros de línea de comandos)
    if ! bash "$instalador_deps"; then
        log_error "Error en la instalación de dependencias del sistema"
        return 1
    fi
    
    log_success "Dependencias del sistema instaladas correctamente"
    return 0
}

# Verificar que las dependencias críticas están disponibles con versiones correctas
verificar_dependencias_criticas() {
    log_info "🔍 Verificando dependencias críticas para WSL Ubuntu..."
    
    local errores=0
    
    # Docker: mínimo v20.10
    if ! command -v docker >/dev/null 2>&1; then
        log_error "❌ Docker no está instalado"
        ((errores++))
    else
        local docker_version
        docker_version=$(docker --version 2>/dev/null | grep -oP '(?<=version )\d+\.\d+' || echo "0.0")
        
        # Comparar versiones sin sort -V (más portable)
        local docker_major docker_minor
        docker_major=$(printf '%s\n' "$docker_version" | cut -d'.' -f1)
        docker_minor=$(printf '%s\n' "$docker_version" | cut -d'.' -f2)
        local docker_int=$((docker_major * 100 + docker_minor))
        
        if [[ $docker_int -ge 2010 ]]; then  # 20.10
            log_success "✅ Docker $docker_version (compatible)"
        else
            log_warning "⚠️ Docker $docker_version podría ser muy antiguo (recomendado: 20.10+)"
        fi
    fi
    
    # Minikube: mínimo v1.30
    if ! command -v minikube >/dev/null 2>&1; then
        log_error "❌ Minikube no está instalado"
        ((errores++))
    else
        local minikube_version
        minikube_version=$(minikube version 2>/dev/null | grep -oP '(?<=version: v)\d+\.\d+' || echo "0.0")
        log_success "✅ Minikube v$minikube_version disponible"
    fi
    
    # kubectl: compatible con minikube (no necesariamente la última)
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "❌ kubectl no está instalado"
        ((errores++))
    else
        local kubectl_version
        kubectl_version=$(kubectl version --client 2>/dev/null | grep -oP '(?<=GitVersion:"v)\d+\.\d+' || echo "0.0")
        log_success "✅ kubectl v$kubectl_version (compatible con minikube)"
    fi
    
    # Helm: mínimo v3.8
    if ! command -v helm >/dev/null 2>&1; then
        log_error "❌ Helm no está instalado"
        ((errores++))
    else
        local helm_version
        helm_version=$(helm version 2>/dev/null | grep -oP '(?<=Version:"v)\d+\.\d+' || echo "0.0")
        
        # Comparar versiones de Helm
        local helm_major helm_minor
        helm_major=$(printf '%s\n' "$helm_version" | cut -d'.' -f1)
        helm_minor=$(printf '%s\n' "$helm_version" | cut -d'.' -f2)
        local helm_int=$((helm_major * 100 + helm_minor))
        
        if [[ $helm_int -ge 308 ]]; then  # 3.8
            log_success "✅ Helm v$helm_version (compatible)"
        else
            log_warning "⚠️ Helm v$helm_version podría ser muy antiguo (recomendado: 3.8+)"
        fi
    fi
    
    # Git: cualquier versión reciente
    if ! command -v git >/dev/null 2>&1; then
        log_error "❌ Git no está instalado"
        ((errores++))
    else
        local git_version
        git_version=$(git --version 2>/dev/null | grep -oP '(?<=version )\d+\.\d+' || echo "0.0")
        log_success "✅ Git $git_version disponible"
    fi
    
    if [[ $errores -gt 0 ]]; then
        log_error "❌ Faltan $errores dependencias críticas"
        log_info "💡 Ejecuta sin --skip-deps para instalarlas automáticamente"
        return 1
    fi
    
    log_success "✅ Todas las dependencias críticas están disponibles y son compatibles"
    return 0
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE LA FASE 2
# ============================================================================

fase_02_dependencias() {
    log_info "📦 FASE 2: Verificación y Actualización de Dependencias"
    log_info "═══════════════════════════════════════════════════════"
    
    # Verificar que tenemos privilegios para instalar paquetes
    if [[ "$EUID" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_warning "⚠️ Esta fase requiere privilegios sudo para instalar dependencias"
        log_info "💡 Ejecuta: sudo $0 $*"
        return 1
    fi
    
    if ! skip_deps; then
        log_info "🔄 Instalando dependencias del sistema..."
        ejecutar_instalacion_dependencias
    else
        log_info "⏭️ Saltando instalación de dependencias (--skip-deps)"
    fi
    
    # Verificar dependencias críticas
    verificar_dependencias_criticas
    
    log_info "✅ Fase 2 completada: Dependencias verificadas"
}

# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fase_02_dependencias "$@"
fi
