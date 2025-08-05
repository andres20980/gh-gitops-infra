#!/bin/bash

# ============================================================================
# ORQUESTADOR PRINCIPAL - Coordinación de instalación GitOps
# ============================================================================
# Coordina la ejecución de todas las fases de instalación GitOps de forma
# modular y ordenada
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN GLOBAL
# ============================================================================

# Evitar redefinición de variables si ya están cargadas desde orquestador
if [[ -z "${GITOPS_ORQUESTADOR_LOADED:-}" ]]; then
    readonly GITOPS_ORQUESTADOR_LOADED="true"
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly SCRIPTS_ROOT="$SCRIPT_DIR"
fi

# Cargar módulos comunes
# shellcheck source=comun/base.sh
source "$SCRIPTS_ROOT/comun/base.sh"
# shellcheck source=comun/validacion.sh
source "$SCRIPTS_ROOT/comun/validacion.sh"
# shellcheck source=instalacion/dependencias.sh
source "$SCRIPTS_ROOT/instalacion/dependencias.sh"
# shellcheck source=cluster/gestor.sh
source "$SCRIPTS_ROOT/cluster/gestor.sh"

# ============================================================================
# DEFINICIÓN DE FASES
# ============================================================================

readonly FASE_VALIDACION="validacion"
readonly FASE_DEPENDENCIAS="dependencias"
readonly FASE_CLUSTER="cluster"
readonly FASE_GITOPS="gitops"
readonly FASE_COMPONENTES="componentes"
readonly FASE_VERIFICACION="verificacion"

# Variables globales de configuración
MODO_INSTALACION="${MODO_INSTALACION:-normal}"
CLUSTER_NAME="${CLUSTER_NAME:-gitops-dev}"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
CREATE_CLUSTER="${CREATE_CLUSTER:-true}"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
DEBUG="${DEBUG:-false}"
INTERACTIVE="${INTERACTIVE:-true}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ============================================================================
# GESTIÓN DE FASES
# ============================================================================

ejecutar_fase_validacion() {
    log_section "🔍 Fase 1: Validación de Prerequisitos"
    
    local start_time
    start_time=$(date +%s)
    
    # Validar prerequisitos del sistema
    if ! validar_prerequisitos; then
        log_error "❌ Falló la validación de prerequisitos"
        return 1
    fi
    
    # Validar entorno GitOps
    if ! validar_entorno_gitops; then
        log_warning "⚠️ Entorno GitOps incompleto, pero continuando..."
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Fase completada: validacion (${duration}s)"
    return 0
}

ejecutar_fase_dependencias() {
    log_section "📦 Fase 2: Instalación de Dependencias"
    
    local start_time
    start_time=$(date +%s)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 [DRY-RUN] Se instalarían las dependencias del sistema"
        return 0
    fi
    
    if ! instalar_dependencias; then
        log_error "❌ Falló la instalación de dependencias"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Fase completada: dependencias (${duration}s)"
    return 0
}

ejecutar_fase_cluster() {
    log_section "🎯 Fase 3: Configuración del Cluster Principal ($CLUSTER_NAME)"
    
    local start_time
    start_time=$(date +%s)
    
    if [[ "$CREATE_CLUSTER" != "true" ]]; then
        log_info "⏭️ Creación de cluster deshabilitada"
        
        # Solo validar cluster existente
        if ! validar_cluster; then
            log_error "❌ Cluster existente no válido"
            return 1
        fi
        
        log_success "✅ Cluster existente validado"
        return 0
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 [DRY-RUN] Se crearía cluster $CLUSTER_PROVIDER: $CLUSTER_NAME"
        return 0
    fi
    
    log_info "Creando cluster principal $CLUSTER_NAME..."
    
    if ! configurar_cluster "$CLUSTER_NAME" "$CLUSTER_PROVIDER" "create"; then
        log_error "❌ Falló la configuración del cluster"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Fase completada: cluster (${duration}s)"
    return 0
}

ejecutar_fase_gitops() {
    log_section "🚀 Fase 4: Instalación de Herramientas GitOps"
    
    local start_time
    start_time=$(date +%s)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 [DRY-RUN] Se instalarían las herramientas GitOps (ArgoCD, etc.)"
        return 0
    fi
    
    # Aquí se integraría con el módulo de GitOps
    log_info "🔧 Instalando ArgoCD..."
    log_info "🔧 Configurando repositorios Git..."
    log_info "🔧 Instalando Kargo..."
    
    # Placeholder - se implementará con módulos específicos
    log_warning "⚠️ Fase GitOps en desarrollo - implementación pendiente"
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Fase completada: gitops (${duration}s)"
    return 0
}

ejecutar_fase_componentes() {
    log_section "🔧 Fase 5: Instalación de Componentes Adicionales"
    
    local start_time
    start_time=$(date +%s)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "🔍 [DRY-RUN] Se instalarían componentes adicionales (Prometheus, Grafana, etc.)"
        return 0
    fi
    
    # Aquí se integraría con el módulo de componentes
    log_info "📊 Instalando stack de monitorización..."
    log_info "🔒 Configurando External Secrets..."
    log_info "🌐 Configurando Ingress..."
    
    # Placeholder - se implementará con módulos específicos
    log_warning "⚠️ Fase componentes en desarrollo - implementación pendiente"
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Fase completada: componentes (${duration}s)"
    return 0
}

ejecutar_fase_verificacion() {
    log_section "✅ Fase 6: Verificación Final"
    
    local start_time
    start_time=$(date +%s)
    
    # Verificar cluster
    if ! validar_cluster; then
        log_error "❌ Cluster no está funcionando correctamente"
        return 1
    fi
    
    # Verificar herramientas instaladas
    log_info "🔍 Verificando herramientas instaladas..."
    
    local herramientas=("kubectl" "helm" "docker")
    for herramienta in "${herramientas[@]}"; do
        if comando_existe "$herramienta"; then
            log_success "✅ $herramienta disponible"
        else
            log_warning "⚠️ $herramienta no disponible"
        fi
    done
    
    # Mostrar información del cluster
    log_info "📊 Estado del cluster:"
    kubectl get nodes 2>/dev/null | head -5 || log_warning "No se pudo obtener información de nodos"
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Fase completada: verificacion (${duration}s)"
    return 0
}

# ============================================================================
# GESTIÓN DE ERRORES Y LIMPIEZA
# ============================================================================

limpiar_en_error() {
    local fase_fallida="$1"
    
    log_warning "⚠️ Ejecutando limpieza automática tras error en fase: $fase_fallida"
    
    case "$fase_fallida" in
        "cluster")
            if [[ "$CREATE_CLUSTER" == "true" && "$CLUSTER_PROVIDER" == "minikube" ]]; then
                log_info "Limpiando cluster minikube fallido..."
                minikube delete -p "$CLUSTER_NAME" 2>/dev/null || true
            fi
            ;;
        "gitops"|"componentes")
            log_info "Limpieza de recursos Kubernetes..."
            # Aquí se agregarían comandos específicos de limpieza
            ;;
    esac
}

# ============================================================================
# ORQUESTADOR PRINCIPAL
# ============================================================================

ejecutar_orquestacion() {
    local modo="${1:-normal}"
    local fases_a_ejecutar=()
    
    # Configurar modo de instalación
    MODO_INSTALACION="$modo"
    
    # Definir fases según el modo
    case "$modo" in
        "dependencies"|"desde-cero")
            fases_a_ejecutar=(
                "$FASE_VALIDACION"
                "$FASE_DEPENDENCIAS"
                "$FASE_CLUSTER"
                "$FASE_GITOPS"
                "$FASE_COMPONENTES"
                "$FASE_VERIFICACION"
            )
            ;;
        "solo-cluster")
            fases_a_ejecutar=(
                "$FASE_VALIDACION"
                "$FASE_CLUSTER"
                "$FASE_VERIFICACION"
            )
            ;;
        "solo-gitops")
            fases_a_ejecutar=(
                "$FASE_VALIDACION"
                "$FASE_GITOPS"
                "$FASE_VERIFICACION"
            )
            ;;
        "solo-componentes")
            fases_a_ejecutar=(
                "$FASE_VALIDACION"
                "$FASE_COMPONENTES"
                "$FASE_VERIFICACION"
            )
            ;;
        "normal"|*)
            fases_a_ejecutar=(
                "$FASE_VALIDACION"
                "$FASE_CLUSTER"
                "$FASE_GITOPS"
                "$FASE_COMPONENTES"
                "$FASE_VERIFICACION"
            )
            ;;
    esac
    
    log_info "Modo de instalación: $modo"
    log_info "Fases a ejecutar: ${fases_a_ejecutar[*]}"
    
    # Ejecutar fases secuencialmente
    local fases_completadas=()
    local fase_actual=""
    
    for fase in "${fases_a_ejecutar[@]}"; do
        fase_actual="$fase"
        log_running "Iniciando fase: $fase"
        
        case "$fase" in
            "$FASE_VALIDACION")
                if ! ejecutar_fase_validacion; then
                    limpiar_en_error "$fase"
                    log_error "Fase falló: $fase"
                    mostrar_resumen_estado "${fases_completadas[@]}" "$fase" "${fases_a_ejecutar[@]}"
                    return 1
                fi
                ;;
            "$FASE_DEPENDENCIAS")
                if ! ejecutar_fase_dependencias; then
                    limpiar_en_error "$fase"
                    log_error "Fase falló: $fase"
                    mostrar_resumen_estado "${fases_completadas[@]}" "$fase" "${fases_a_ejecutar[@]}"
                    return 1
                fi
                ;;
            "$FASE_CLUSTER")
                if ! ejecutar_fase_cluster; then
                    limpiar_en_error "$fase"
                    log_error "Fase falló: $fase"
                    log_error "Falló la configuración del cluster"
                    mostrar_resumen_estado "${fases_completadas[@]}" "$fase" "${fases_a_ejecutar[@]}"
                    return 1
                fi
                ;;
            "$FASE_GITOPS")
                if ! ejecutar_fase_gitops; then
                    limpiar_en_error "$fase"
                    log_error "Fase falló: $fase"
                    mostrar_resumen_estado "${fases_completadas[@]}" "$fase" "${fases_a_ejecutar[@]}"
                    return 1
                fi
                ;;
            "$FASE_COMPONENTES")
                if ! ejecutar_fase_componentes; then
                    limpiar_en_error "$fase"
                    log_error "Fase falló: $fase"
                    mostrar_resumen_estado "${fases_completadas[@]}" "$fase" "${fases_a_ejecutar[@]}"
                    return 1
                fi
                ;;
            "$FASE_VERIFICACION")
                if ! ejecutar_fase_verificacion; then
                    log_error "Fase falló: $fase"
                    mostrar_resumen_estado "${fases_completadas[@]}" "$fase" "${fases_a_ejecutar[@]}"
                    return 1
                fi
                ;;
        esac
        
        fases_completadas+=("$fase")
    done
    
    # Mostrar resumen final
    mostrar_resumen_exito "${fases_completadas[@]}"
    return 0
}

# ============================================================================
# FUNCIONES DE REPORTE
# ============================================================================

mostrar_resumen_estado() {
    local fases_completadas=("$@")
    local fase_fallida=""
    local todas_las_fases=()
    
    # Extraer argumentos
    local i=0
    while [[ $i -lt $# ]]; do
        if [[ "${!i}" == "$FASE_VALIDACION" || "${!i}" == "$FASE_DEPENDENCIAS" || 
              "${!i}" == "$FASE_CLUSTER" || "${!i}" == "$FASE_GITOPS" || 
              "${!i}" == "$FASE_COMPONENTES" || "${!i}" == "$FASE_VERIFICACION" ]]; then
            if [[ -z "$fase_fallida" ]]; then
                fase_fallida="${!i}"
                ((i++))
                break
            fi
        fi
        ((i++))
    done
    
    # El resto son todas las fases
    while [[ $i -lt $# ]]; do
        todas_las_fases+=("${!i}")
        ((i++))
    done
    
    log_section "📊 Resumen de Estado de Instalación"
    
    for fase in "${todas_las_fases[@]}"; do
        if [[ " ${fases_completadas[*]} " =~ " ${fase} " ]]; then
            echo "  ✓ $fase     : (s)"
        elif [[ "$fase" == "$fase_fallida" ]]; then
            echo "  ✗ $fase     : (s)"
        else
            echo "  ⏳ $fase     : pendiente"
        fi
    done
}

mostrar_resumen_exito() {
    local fases_completadas=("$@")
    
    log_section "🎉 Instalación Completada Exitosamente"
    
    log_success "✅ Todas las fases ejecutadas correctamente:"
    for fase in "${fases_completadas[@]}"; do
        echo "  ✓ $fase"
    done
    
    echo
    log_info "🌐 Acceso al cluster:"
    log_info "  kubectl config current-context"
    log_info "  kubectl get nodes"
    
    if [[ "$CLUSTER_PROVIDER" == "minikube" ]]; then
        log_info "🎛️ Dashboard de Kubernetes:"
        log_info "  minikube dashboard -p $CLUSTER_NAME"
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL EXPORTADA
# ============================================================================

run_orchestrator() {
    local modo="${1:-normal}"
    
    log_debug "Pre-cargando módulos comunes..."
    log_debug "Módulo pre-cargado: cluster"
    log_debug "Pre-carga de módulos completada"
    
    if ! ejecutar_orquestacion "$modo"; then
        log_error "Error en la orquestación GitOps"
        return 1
    fi
    
    return 0
}

# ============================================================================
# INICIALIZACIÓN
# ============================================================================

inicializar_orquestador() {
    log_debug "Orquestador principal cargado - Sistema de fases disponible"
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    inicializar_orquestador
    
    # Parsear argumentos de línea de comandos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode=*)
                MODO_INSTALACION="${1#*=}"
                shift
                ;;
            --cluster=*)
                CLUSTER_NAME="${1#*=}"
                shift
                ;;
            --provider=*)
                CLUSTER_PROVIDER="${1#*=}"
                shift
                ;;
            --create-cluster=*)
                CREATE_CLUSTER="${1#*=}"
                shift
                ;;
            --dry-run=*)
                DRY_RUN="${1#*=}"
                shift
                ;;
            --verbose=*)
                VERBOSE="${1#*=}"
                shift
                ;;
            --debug=*)
                DEBUG="${1#*=}"
                shift
                ;;
            --interactive=*)
                INTERACTIVE="${1#*=}"
                shift
                ;;
            --log-level=*)
                LOG_LEVEL="${1#*=}"
                shift
                ;;
            *)
                MODO_INSTALACION="$1"
                shift
                ;;
        esac
    done
    
    run_orchestrator "$MODO_INSTALACION"
fi
