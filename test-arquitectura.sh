#!/bin/bash

# ============================================================================
# SCRIPT DE TESTING - Verificación de arquitectura modular
# ============================================================================
# Verifica que todos los módulos se cargan correctamente y no hay duplicación
# ============================================================================

set -euo pipefail

# Cargar autocontención
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/scripts/comun/autocontener.sh" ]]; then
    # shellcheck source=scripts/comun/autocontener.sh
    source "$SCRIPT_DIR/scripts/comun/autocontener.sh"
else
    echo "❌ Error: No se pudo cargar autocontención" >&2
    exit 1
fi

# ============================================================================
# TESTS DE ARQUITECTURA MODULAR
# ============================================================================

test_configuracion_centralizada() {
    log_section "🧪 Testing Configuración Centralizada"
    
    # Verificar que las variables están definidas desde config.sh
    local tests_passed=0
    local tests_total=8
    
    [[ -n "${GITOPS_VERSION:-}" ]] && ((tests_passed++)) || log_error "GITOPS_VERSION no definida"
    [[ -n "${PROJECT_ROOT:-}" ]] && ((tests_passed++)) || log_error "PROJECT_ROOT no definida"
    [[ -n "${SCRIPTS_DIR:-}" ]] && ((tests_passed++)) || log_error "SCRIPTS_DIR no definida"
    [[ -n "${CLUSTER_DEV_NAME:-}" ]] && ((tests_passed++)) || log_error "CLUSTER_DEV_NAME no definida"
    [[ -n "${ARGOCD_NAMESPACE:-}" ]] && ((tests_passed++)) || log_error "ARGOCD_NAMESPACE no definida"
    [[ -n "${DEFAULT_LOG_LEVEL:-}" ]] && ((tests_passed++)) || log_error "DEFAULT_LOG_LEVEL no definida"
    [[ "${#FASES_DISPONIBLES[@]}" -eq 7 ]] && ((tests_passed++)) || log_error "FASES_DISPONIBLES incorrecta"
    [[ "${#FASE_NOMBRES[@]}" -eq 7 ]] && ((tests_passed++)) || log_error "FASE_NOMBRES incorrecta"
    
    log_info "Tests de configuración: $tests_passed/$tests_total"
    return $((tests_total - tests_passed))
}

test_funciones_base() {
    log_section "🧪 Testing Funciones Base"
    
    local tests_passed=0
    local tests_total=6
    
    command -v log_info >/dev/null 2>&1 && ((tests_passed++)) || log_error "log_info no disponible"
    command -v log_error >/dev/null 2>&1 && ((tests_passed++)) || log_error "log_error no disponible"
    command -v log_success >/dev/null 2>&1 && ((tests_passed++)) || log_error "log_success no disponible"
    command -v es_dry_run >/dev/null 2>&1 && ((tests_passed++)) || log_error "es_dry_run no disponible"
    command -v es_verbose >/dev/null 2>&1 && ((tests_passed++)) || log_error "es_verbose no disponible"
    command -v inicializar_configuracion >/dev/null 2>&1 && ((tests_passed++)) || log_error "inicializar_configuracion no disponible"
    
    log_info "Tests de funciones base: $tests_passed/$tests_total"
    return $((tests_total - tests_passed))
}

test_autocontención() {
    log_section "🧪 Testing Autocontención"
    
    local tests_passed=0
    local tests_total=4
    
    [[ -n "${GITOPS_CONFIG_LOADED:-}" ]] && ((tests_passed++)) || log_error "Configuración no cargada"
    [[ -n "${GITOPS_BASE_LOADED:-}" ]] && ((tests_passed++)) || log_error "Base no cargada"
    command -v auto_cargar_dependencias >/dev/null 2>&1 && ((tests_passed++)) || log_error "auto_cargar_dependencias no disponible"
    command -v verificar_dependencias_cargadas >/dev/null 2>&1 && ((tests_passed++)) || log_error "verificar_dependencias_cargadas no disponible"
    
    log_info "Tests de autocontención: $tests_passed/$tests_total"
    return $((tests_total - tests_passed))
}

test_estructura_modular() {
    log_section "🧪 Testing Estructura Modular"
    
    local tests_passed=0
    local tests_total=0
    
    log_info "Verificando fases disponibles..."
    for fase in "${FASES_DISPONIBLES[@]}"; do
        ((tests_total++))
        if [[ -f "$FASES_DIR/$fase" ]]; then
            ((tests_passed++))
            log_debug "✅ $fase disponible"
        else
            log_error "❌ $fase no encontrada"
        fi
    done
    
    log_info "Tests de estructura: $tests_passed/$tests_total"
    return $((tests_total - tests_passed))
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    log_section "🚀 Testing Arquitectura Modular v3.0.0"
    
    local tests_failed=0
    
    # Ejecutar tests
    test_configuracion_centralizada || ((tests_failed++))
    test_funciones_base || ((tests_failed++))
    test_autocontención || ((tests_failed++))
    test_estructura_modular || ((tests_failed++))
    
    # Mostrar información de configuración
    log_section "📋 Información del Sistema"
    obtener_info_configuracion
    
    # Resultado final
    if [[ $tests_failed -eq 0 ]]; then
        log_success "🎉 Todos los tests pasaron - Arquitectura modular perfecta"
        return 0
    else
        log_error "💥 $tests_failed test(s) fallaron - Arquitectura necesita correcciones"
        return 1
    fi
}

# Ejecutar solo si se invoca directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
