#!/bin/bash

# ============================================================================
# FASE 2: DEPENDENCIAS DEL SISTEMA
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

# Verificar que las dependencias críticas están disponibles
verificar_dependencias_criticas() {
    log_info "🔍 Verificando dependencias críticas..."
    
    local dependencias_criticas=(
        "docker"
        "kubectl"
        "minikube"
        "helm"
        "git"
    )
    
    local faltan_dependencias=()
    
    for dep in "${dependencias_criticas[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            faltan_dependencias+=("$dep")
        else
            log_success "✅ $dep disponible"
        fi
    done
    
    if [[ ${#faltan_dependencias[@]} -gt 0 ]]; then
        log_error "❌ Faltan dependencias críticas: ${faltan_dependencias[*]}"
        log_info "💡 Ejecuta sin --skip-deps para instalarlas automáticamente"
        return 1
    fi
    
    log_success "✅ Todas las dependencias críticas están disponibles"
    return 0
}
