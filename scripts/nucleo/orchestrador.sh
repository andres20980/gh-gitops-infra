#!/bin/bash

# ============================================================================
# SCRIPT CORE - ORCHESTRADOR PRINCIPAL
# ============================================================================
# Orchestrador inteligente para instalación completa de infraestructura GitOps
# Coordina todos los módulos y maneja flujos de instalación
# ============================================================================

# Cargar librerías base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_LIB_DIR="$(dirname "$SCRIPT_DIR")/bibliotecas"

# shellcheck source=../bibliotecas/base.sh
source "$ORCHESTRATOR_LIB_DIR/base.sh"
# shellcheck source=../bibliotecas/logging.sh
source "$ORCHESTRATOR_LIB_DIR/logging.sh"
# shellcheck source=../bibliotecas/validacion.sh
source "$ORCHESTRATOR_LIB_DIR/validacion.sh"
# shellcheck source=../bibliotecas/versiones.sh
source "$ORCHESTRATOR_LIB_DIR/versiones.sh"

# ============================================================================
# CONFIGURACIÓN DEL ORCHESTRADOR
# ============================================================================

readonly ORCHESTRATOR_VERSION="1.0.0"
readonly ORCHESTRATOR_NAME="GitOps Core Orchestrator"

# Fases de instalación
readonly PHASE_VALIDATION="validation"
readonly PHASE_DEPENDENCIES="dependencies"
readonly PHASE_CLUSTER="cluster"
readonly PHASE_GITOPS="gitops"
readonly PHASE_COMPONENTS="components"
readonly PHASE_ADDITIONAL_CLUSTERS="additional-clusters"
readonly PHASE_VERIFICATION="verification"

# Estados de instalación
readonly STATE_PENDING="pending"
readonly STATE_RUNNING="running"
readonly STATE_SUCCESS="success"
readonly STATE_ERROR="error"
readonly STATE_SKIPPED="skipped"

# ============================================================================
# VARIABLES GLOBALES DEL ORCHESTRADOR
# ============================================================================

# Control de flujo
declare -g CURRENT_PHASE=""
declare -g INSTALLATION_MODE="normal"
declare -g SKIP_VALIDATION=false
declare -g FORCE_REINSTALL=false
declare -g DRY_RUN_MODE=false

# Estado de fases
declare -A PHASE_STATUS=(
    [$PHASE_VALIDATION]="$STATE_PENDING"
    [$PHASE_DEPENDENCIES]="$STATE_PENDING"
    [$PHASE_CLUSTER]="$STATE_PENDING"
    [$PHASE_GITOPS]="$STATE_PENDING"
    [$PHASE_COMPONENTS]="$STATE_PENDING"
    [$PHASE_ADDITIONAL_CLUSTERS]="$STATE_PENDING"
    [$PHASE_VERIFICATION]="$STATE_PENDING"
)

# Tiempos de ejecución
declare -A PHASE_START_TIME=()
declare -A PHASE_END_TIME=()

# ============================================================================
# FUNCIONES DE ESTADO Y SEGUIMIENTO
# ============================================================================

# Actualizar estado de fase
update_phase_status() {
    local phase="$1"
    local status="$2"
    
    PHASE_STATUS[$phase]="$status"
    
    case "$status" in
        "$STATE_RUNNING")
            PHASE_START_TIME[$phase]=$(date +%s)
            log_progress "Iniciando fase: $phase"
            ;;
        "$STATE_SUCCESS")
            if [[ -n "${PHASE_START_TIME[$phase]:-}" ]]; then
                PHASE_END_TIME[$phase]=$(date +%s)
                local duration=$((${PHASE_END_TIME[$phase]} - ${PHASE_START_TIME[$phase]}))
                log_success "Fase completada: $phase (${duration}s)"
            else
                log_success "Fase completada: $phase"
            fi
            ;;
        "$STATE_ERROR")
            if [[ -n "${PHASE_START_TIME[$phase]:-}" ]]; then
                PHASE_END_TIME[$phase]=$(date +%s)
            fi
            log_error "Fase falló: $phase"
            ;;
        "$STATE_SKIPPED")
            log_info "Fase omitida: $phase"
            ;;
    esac
}

# Mostrar resumen de estado
show_status_summary() {
    log_section "📊 Resumen de Estado de Instalación"
    
    for phase in "$PHASE_VALIDATION" "$PHASE_DEPENDENCIES" "$PHASE_CLUSTER" "$PHASE_GITOPS" "$PHASE_COMPONENTS" "$PHASE_VERIFICATION"; do
        local status="${PHASE_STATUS[$phase]}"
        local start_time="${PHASE_START_TIME[$phase]:-}"
        local end_time="${PHASE_END_TIME[$phase]:-}"
        local duration=""
        
        if [[ -n "$start_time" && -n "$end_time" ]]; then
            duration=" (${duration}s)"
        fi
        
        case "$status" in
            "$STATE_SUCCESS")
                log_check "$(printf '%-15s' "$phase"):$duration" "success"
                ;;
            "$STATE_ERROR")
                log_check "$(printf '%-15s' "$phase"):$duration" "error"
                ;;
            "$STATE_RUNNING")
                log_check "$(printf '%-15s' "$phase"): en progreso..." "pending"
                ;;
            "$STATE_SKIPPED")
                log_check "$(printf '%-15s' "$phase"): omitida" "warning"
                ;;
            *)
                log_check "$(printf '%-15s' "$phase"): pendiente" "pending"
                ;;
        esac
    done
}

# ============================================================================
# FUNCIONES DE CARGA DE MÓDULOS
# ============================================================================

# Cargar instalador
load_installer() {
    local installer="$1"
    local installer_path="${SCRIPT_DIR}/../instaladores/${installer}.sh"
    
    if [[ ! -f "$installer_path" ]]; then
        log_error "Instalador no encontrado: $installer_path"
        return 1
    fi
    
    log_debug "Cargando instalador: $installer"
    # shellcheck source=/dev/null
    source "$installer_path"
}

# Cargar módulo GitOps
load_gitops_module() {
    local module="$1"
    local module_path="${SCRIPT_DIR}/../modulos/${module}.sh"
    
    if [[ ! -f "$module_path" ]]; then
        log_error "Módulo GitOps no encontrado: $module_path"
        return 1
    fi
    
    log_debug "Cargando módulo GitOps: $module"
    # shellcheck source=/dev/null
    source "$module_path"
}

# ============================================================================
# FASES DE INSTALACIÓN
# ============================================================================

# Fase 1: Validación de prerequisitos
phase_validation() {
    local phase="$PHASE_VALIDATION"
    
    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        update_phase_status "$phase" "$STATE_SKIPPED"
        return 0
    fi
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "🔍 Fase 1: Validación de Prerequisitos"
    
    # Validar sistema operativo y dependencias básicas
    if ! validar_prerequisitos_sistema; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    # En modo desde-cero, no validar herramientas que se van a instalar
    if [[ "$INSTALLATION_MODE" != "desde-cero" ]]; then
        if ! validar_entorno_gitops; then
            log_warning "Entorno GitOps incompleto - se procederá a instalación"
        fi
    fi
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# Fase 2: Instalación de dependencias
phase_dependencies() {
    local phase="$PHASE_DEPENDENCIES"
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "📦 Fase 2: Instalación de Dependencias"
    
    # Cargar instalador de dependencias
    if ! load_installer "dependencias"; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    # Ejecutar instalación de dependencias
    if ! instalar_dependencias_completas; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# Fase 3: Configuración del cluster
phase_cluster() {
    local phase="$PHASE_CLUSTER"
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "🎯 Fase 3: Configuración del Cluster Principal (gitops-dev)"
    
    # Cargar módulo de cluster
    if ! load_gitops_module "cluster"; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    # Crear cluster principal gitops-dev con recursos completos
    log_info "Creando cluster principal gitops-dev..."
    CLUSTER_NAME="gitops-dev"
    
    # Configurar cluster según el modo
    case "$CLUSTER_PROVIDER" in
        "minikube")
            if ! configurar_cluster_minikube; then
                update_phase_status "$phase" "$STATE_ERROR"
                return 1
            fi
            ;;
        "kind")
            if ! configurar_cluster_kind; then
                update_phase_status "$phase" "$STATE_ERROR"
                return 1
            fi
            ;;
        "existente")
            if ! validar_cluster_existente; then
                update_phase_status "$phase" "$STATE_ERROR"
                return 1
            fi
            ;;
        *)
            log_error "Proveedor de cluster no soportado: $CLUSTER_PROVIDER"
            update_phase_status "$phase" "$STATE_ERROR"
            return 1
            ;;
    esac
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# Fase 4: Instalación de GitOps Core
phase_gitops() {
    local phase="$PHASE_GITOPS"
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "🚀 Fase 4: Instalación de GitOps Core"
    
    # AUTOMATIZACIÓN: Actualizar helm charts con últimas versiones
    log_subsection "🔄 Actualizando Helm Charts a últimas versiones"
    if ! load_gitops_module "actualizador-charts"; then
        log_warn "Módulo actualizador de charts no disponible, continuando..."
    else
        if ! actualizar_helm_charts_automaticamente; then
            log_warn "No se pudieron actualizar todos los charts, continuando con versiones actuales..."
        else
            log_success "✅ Helm Charts actualizados a últimas versiones"
        fi
    fi
    
    # Instalar ArgoCD
    log_subsection "Instalando ArgoCD"
    if ! load_gitops_module "argocd"; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    if ! instalar_argocd; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    # Instalar Kargo si está habilitado
    if [[ "${INSTALL_KARGO:-true}" == "true" ]]; then
        log_subsection "Instalando Kargo"
        if ! load_gitops_module "kargo"; then
            update_phase_status "$phase" "$STATE_ERROR"
            return 1
        fi
        
        if ! instalar_kargo; then
            update_phase_status "$phase" "$STATE_ERROR"
            return 1
        fi
    fi
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# Fase 5: Instalación de componentes GitOps vía ArgoCD
phase_components() {
    local phase="$PHASE_COMPONENTS"
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "🧩 Fase 5: Despliegue de Herramientas GitOps vía ArgoCD"
    
    # Desplegar todas las aplicaciones ArgoCD de herramientas-gitops/
    log_info "Desplegando aplicaciones ArgoCD desde herramientas-gitops/..."
    
    if ! kubectl apply -f "$PROJECT_ROOT/herramientas-gitops/" >/dev/null 2>&1; then
        log_error "Error desplegando aplicaciones ArgoCD"
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    log_success "Aplicaciones ArgoCD desplegadas"
    
    # Esperar a que todas las aplicaciones estén synced y healthy
    log_info "Esperando a que todas las aplicaciones estén synced y healthy..."
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local total_apps
        local synced_apps
        local healthy_apps
        
        total_apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        synced_apps=$(kubectl get applications -n argocd -o json 2>/dev/null | jq -r '.items[] | select(.status.sync.status == "Synced") | .metadata.name' | wc -l || echo "0")
        healthy_apps=$(kubectl get applications -n argocd -o json 2>/dev/null | jq -r '.items[] | select(.status.health.status == "Healthy") | .metadata.name' | wc -l || echo "0")
        
        log_info "Estado: $synced_apps/$total_apps synced, $healthy_apps/$total_apps healthy"
        
        if [[ $synced_apps -eq $total_apps ]] && [[ $healthy_apps -eq $total_apps ]] && [[ $total_apps -gt 0 ]]; then
            log_success "✅ Todas las aplicaciones están synced y healthy"
            break
        fi
        
        ((attempt++))
        sleep 30
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        log_warning "⚠️ Timeout esperando a que todas las aplicaciones estén ready"
        log_info "Continuando con clusters adicionales..."
    fi
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# Fase 6: Creación de clusters adicionales para promociones
phase_additional_clusters() {
    local phase="$PHASE_ADDITIONAL_CLUSTERS"
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "🔄 Fase 6: Clusters Adicionales para Promociones"
    
    # Cargar módulo de cluster
    if ! load_gitops_module "cluster"; then
        update_phase_status "$phase" "$STATE_ERROR"
        return 1
    fi
    
    # Crear cluster gitops-pre (mínimo)
    log_info "Creando cluster gitops-pre (entorno de preproducción)..."
    if ! crear_cluster_minimo "gitops-pre"; then
        log_warning "Error creando cluster gitops-pre, continuando..."
    else
        log_success "✅ Cluster gitops-pre creado"
    fi
    
    # Crear cluster gitops-pro (mínimo)
    log_info "Creando cluster gitops-pro (entorno de producción)..."
    if ! crear_cluster_minimo "gitops-pro"; then
        log_warning "Error creando cluster gitops-pro, continuando..."
    else
        log_success "✅ Cluster gitops-pro creado"
    fi
    
    # Configurar contextos para Kargo
    log_info "Configurando contextos para promociones Kargo..."
    if ! configurar_contextos_kargo; then
        log_warning "Error configurando contextos Kargo"
    else
        log_success "✅ Contextos Kargo configurados"
    fi
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# Fase 7: Verificación final
phase_verification() {
    local phase="$PHASE_VERIFICATION"
    
    update_phase_status "$phase" "$STATE_RUNNING"
    CURRENT_PHASE="$phase"
    
    log_section "✅ Fase 7: Verificación Final"
    
    # Cargar utilidad de verificación
    if ! cargar_core "verificacion"; then
        log_warning "Módulo de verificación no disponible"
    else
        verificar_instalacion_completa
    fi
    
    # Mostrar información de acceso
    mostrar_informacion_acceso
    
    update_phase_status "$phase" "$STATE_SUCCESS"
    return 0
}

# ============================================================================
# ORCHESTRADOR PRINCIPAL
# ============================================================================

# Función principal de orchestración
run_orchestrator() {
    local modo="${1:-normal}"
    local fases_a_ejecutar=()
    
    # Configurar modo de instalación
    INSTALLATION_MODE="$modo"
    
    # Definir fases según el modo
    case "$modo" in
        "dependencies"|"desde-cero")
            fases_a_ejecutar=(
                "$PHASE_VALIDATION"
                "$PHASE_DEPENDENCIES"
                "$PHASE_CLUSTER"
                "$PHASE_GITOPS"
                "$PHASE_COMPONENTS"
                "$PHASE_ADDITIONAL_CLUSTERS"
                "$PHASE_VERIFICATION"
            )
            ;;
        "solo-cluster")
            fases_a_ejecutar=(
                "$PHASE_VALIDATION"
                "$PHASE_CLUSTER"
                "$PHASE_VERIFICATION"
            )
            ;;
        "solo-gitops")
            fases_a_ejecutar=(
                "$PHASE_VALIDATION"
                "$PHASE_GITOPS"
                "$PHASE_VERIFICATION"
            )
            ;;
        "solo-componentes")
            fases_a_ejecutar=(
                "$PHASE_VALIDATION"
                "$PHASE_COMPONENTS"
                "$PHASE_VERIFICATION"
            )
            ;;
        "normal"|*)
            fases_a_ejecutar=(
                "$PHASE_VALIDATION"
                "$PHASE_CLUSTER"
                "$PHASE_GITOPS"
                "$PHASE_COMPONENTS"
                "$PHASE_ADDITIONAL_CLUSTERS"
                "$PHASE_VERIFICATION"
            )
            ;;
    esac
    
    # Mostrar banner inicial
    mostrar_banner
    log_info "Modo de instalación: $modo"
    log_info "Fases a ejecutar: ${fases_a_ejecutar[*]}"
    echo
    
    # Confirmar si no es dry-run
    if ! es_dry_run && [[ "${INTERACTIVE:-true}" == "true" ]]; then
        if ! confirmar "¿Continuar con la instalación?"; then
            log_info "Instalación cancelada por el usuario"
            return 0
        fi
    fi
    
    # Ejecutar fases
    local start_time
    start_time=$(date +%s)
    
    for fase in "${fases_a_ejecutar[@]}"; do
        if es_dry_run; then
            log_info "[DRY-RUN] Simularía ejecución de fase: $fase"
            update_phase_status "$fase" "$STATE_SUCCESS"
            continue
        fi
        
        case "$fase" in
            "$PHASE_VALIDATION")
                if ! phase_validation; then
                    log_error "Falló la validación de prerequisitos"
                    show_status_summary
                    return 1
                fi
                ;;
            "$PHASE_DEPENDENCIES")
                if ! phase_dependencies; then
                    log_error "Falló la instalación de dependencias"
                    show_status_summary
                    return 1
                fi
                ;;
            "$PHASE_CLUSTER")
                if ! phase_cluster; then
                    log_error "Falló la configuración del cluster"
                    show_status_summary
                    return 1
                fi
                ;;
            "$PHASE_GITOPS")
                if ! phase_gitops; then
                    log_error "Falló la instalación de GitOps"
                    show_status_summary
                    return 1
                fi
                ;;
            "$PHASE_COMPONENTS")
                if ! phase_components; then
                    log_error "Falló la instalación de componentes"
                    show_status_summary
                    return 1
                fi
                ;;
            "$PHASE_ADDITIONAL_CLUSTERS")
                if ! phase_additional_clusters; then
                    log_error "Falló la creación de clusters adicionales"
                    show_status_summary
                    return 1
                fi
                ;;
            "$PHASE_VERIFICATION")
                if ! phase_verification; then
                    log_warning "Verificación completada con advertencias"
                fi
                ;;
        esac
    done
    
    # Calcular tiempo total
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Mostrar resumen final
    show_status_summary
    
    # Banner de finalización
    mostrar_banner_finalizacion
    log_success "Instalación completada exitosamente en ${total_duration}s"
    
    return 0
}

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

# Mostrar información de acceso
mostrar_informacion_acceso() {
    log_section "🌐 Información de Acceso"
    
    # ArgoCD
    local argocd_url="https://localhost:8080"
    local argocd_pass
    argocd_pass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
    
    log_info "ArgoCD UI: $argocd_url"
    log_info "ArgoCD Usuario: admin"
    log_info "ArgoCD Contraseña: $argocd_pass"
    echo
    
    # Grafana
    if kubectl get namespace grafana >/dev/null 2>&1; then
        log_info "Grafana UI: http://localhost:3000"
        log_info "Grafana Usuario: admin"
        log_info "Grafana Contraseña: admin"
        echo
    fi
    
    # Comandos útiles
    log_subsection "Comandos Útiles"
    log_list \
        "kubectl get applications -A" \
        "kubectl port-forward -n argocd svc/argocd-server 8080:443" \
        "kubectl port-forward -n grafana svc/grafana 3000:80" \
        "minikube dashboard"
}

# Mostrar ayuda del orchestrador
show_orchestrator_help() {
    cat << 'EOF'
Uso: orchestrador.sh [MODO] [OPCIONES]

MODOS:
  dependencies   Instalación completa desde cero (incluye dependencias Ubuntu)
  desde-cero     Instalación completa desde cero (incluye dependencias)
  normal         Instalación estándar (sin dependencias del sistema)
  solo-cluster   Solo configurar cluster Kubernetes
  solo-gitops    Solo instalar ArgoCD y Kargo
  solo-componentes Solo instalar componentes adicionales

OPCIONES:
  --skip-validation    Omitir validación de prerequisitos
  --force             Forzar reinstalación de componentes existentes
  --dry-run           Mostrar qué se haría sin ejecutar
  --help              Mostrar esta ayuda

EJEMPLOS:
  ./orchestrador.sh desde-cero
  ./orchestrador.sh normal --skip-validation
  ./orchestrador.sh solo-gitops --dry-run
EOF
}

# ============================================================================
# EXPORTS
# ============================================================================

export -f run_orchestrator
export -f show_orchestrator_help
export -f mostrar_informacion_acceso
