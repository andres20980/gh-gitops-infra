#!/bin/bash

# ============================================================================
# ACTUALIZADOR DE HELM CHARTS - Mantener versiones actualizadas
# ============================================================================
# Actualiza automáticamente las versiones de helm charts en las aplicaciones
# ArgoCD basándose en los repositorios oficiales
# ============================================================================

set -euo pipefail

# Cargar módulo base
HELM_UPDATER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./base.sh
source "$HELM_UPDATER_SCRIPT_DIR/base.sh"

# ============================================================================
# CONFIGURACIÓN DE HELM REPOSITORIES
# ============================================================================

readonly HELM_REPOS=(
    "prometheus-community|https://prometheus-community.github.io/helm-charts"
    "grafana|https://grafana.github.io/helm-charts"
    "ingress-nginx|https://kubernetes.github.io/ingress-nginx"
    "cert-manager|https://charts.jetstack.io"
    "external-secrets|https://charts.external-secrets.io"
    "argo|https://argoproj.github.io/argo-helm"
    "gitea-charts|https://dl.gitea.io/charts"
    "minio|https://charts.min.io"
    "jaegertracing|https://jaegertracing.github.io/helm-charts"
)

readonly CHART_MAPPINGS=(
    "prometheus-stack|prometheus-community|kube-prometheus-stack"
    "grafana|grafana|grafana"
    "ingress-nginx|ingress-nginx|ingress-nginx"
    "cert-manager|cert-manager|cert-manager"
    "external-secrets|external-secrets|external-secrets"
    "argo-events|argo|argo-events"
    "argo-rollouts|argo|argo-rollouts"
    "argo-workflows|argo|argo-workflows"
    "gitea|gitea-charts|gitea"
    "minio|minio|minio"
    "jaeger|jaegertracing|jaeger"
    "loki|grafana|loki"
)

# ============================================================================
# FUNCIONES DE HELM
# ============================================================================

setup_helm_repos() {
    log_section "📦 Configurando repositorios de Helm"
    
    # Actualizar lista de repos
    helm repo update >/dev/null 2>&1 || true
    
    # Agregar repositorios necesarios
    for repo_entry in "${HELM_REPOS[@]}"; do
        local repo_name="${repo_entry%%|*}"
        local repo_url="${repo_entry##*|}"
        
        if ! helm repo list | grep -q "^$repo_name"; then
            log_info "➕ Agregando repositorio: $repo_name"
            helm repo add "$repo_name" "$repo_url" >/dev/null 2>&1
        else
            log_debug "✅ Repositorio ya existe: $repo_name"
        fi
    done
    
    # Actualizar todos los repositorios
    log_info "🔄 Actualizando repositorios..."
    helm repo update >/dev/null 2>&1
    
    log_success "✅ Repositorios de Helm configurados"
}

get_latest_chart_version() {
    local repo_name="$1"
    local chart_name="$2"
    
    # Obtener la última versión del chart
    local latest_version
    latest_version=$(helm search repo "$repo_name/$chart_name" --versions | grep -v "DEPRECATED" | head -2 | tail -1 | awk '{print $2}')
    
    if [[ -n "$latest_version" && "$latest_version" != "CHART VERSION" ]]; then
        echo "$latest_version"
    else
        log_error "❌ No se pudo obtener la versión de $repo_name/$chart_name"
        return 1
    fi
}

update_argocd_application() {
    local app_file="$1"
    local new_version="$2"
    local app_name
    app_name=$(basename "$app_file" .yaml)
    
    log_info "🔧 Actualizando $app_name a versión $new_version"
    
    # Usar yq para actualizar la versión si existe
    if command -v yq >/dev/null 2>&1; then
        yq eval ".spec.source.targetRevision = \"$new_version\"" -i "$app_file"
        log_success "✅ $app_name actualizado a $new_version"
    else
        # Fallback con sed si yq no está disponible
        sed -i "s/targetRevision: .*/targetRevision: $new_version/" "$app_file"
        log_success "✅ $app_name actualizado a $new_version (usando sed)"
    fi
}

# ============================================================================
# FUNCIONES PRINCIPALES
# ============================================================================

check_and_update_charts() {
    local herramientas_dir="${1:-$(pwd)/herramientas-gitops}"
    
    if [[ ! -d "$herramientas_dir" ]]; then
        log_error "❌ Directorio de herramientas no encontrado: $herramientas_dir"
        return 1
    fi
    
    log_section "🔍 Verificando versiones de charts"
    
    setup_helm_repos
    
    # Procesar cada mapping de chart
    for mapping in "${CHART_MAPPINGS[@]}"; do
        local app_name="${mapping%%|*}"
        local temp="${mapping#*|}"
        local repo_name="${temp%%|*}"
        local chart_name="${temp##*|}"
        
        local app_file="$herramientas_dir/$app_name.yaml"
        
        if [[ ! -f "$app_file" ]]; then
            log_warning "⚠️ Archivo no encontrado: $app_file"
            continue
        fi
        
        log_info "🔍 Verificando $app_name ($repo_name/$chart_name)..."
        
        # Obtener versión actual del archivo
        local current_version
        if command -v yq >/dev/null 2>&1; then
            current_version=$(yq eval '.spec.source.targetRevision' "$app_file")
        else
            current_version=$(grep "targetRevision:" "$app_file" | awk '{print $2}' | head -1)
        fi
        
        # Obtener última versión disponible
        local latest_version
        if latest_version=$(get_latest_chart_version "$repo_name" "$chart_name"); then
            log_info "📊 $app_name: $current_version → $latest_version"
            
            if [[ "$current_version" != "$latest_version" ]]; then
                if [[ "${UPDATE_CHARTS:-false}" == "true" ]]; then
                    update_argocd_application "$app_file" "$latest_version"
                else
                    log_info "💡 Usa UPDATE_CHARTS=true para actualizar automáticamente"
                fi
            else
                log_success "✅ $app_name ya está actualizado"
            fi
        else
            log_warning "⚠️ No se pudo verificar la versión de $app_name"
        fi
    done
}

show_all_versions() {
    log_section "📋 Versiones disponibles de charts"
    
    setup_helm_repos
    
    for mapping in "${CHART_MAPPINGS[@]}"; do
        local app_name="${mapping%%|*}"
        local temp="${mapping#*|}"
        local repo_name="${temp%%|*}"
        local chart_name="${temp##*|}"
        
        echo "=== $app_name ($repo_name/$chart_name) ==="
        helm search repo "$repo_name/$chart_name" --versions | head -6
        echo
    done
}

# ============================================================================
# VALIDACIÓN DE CONFIGURACIONES
# ============================================================================

validate_chart_configurations() {
    local herramientas_dir="${1:-$(pwd)/herramientas-gitops}"
    
    log_section "🔍 Validando configuraciones de charts"
    
    for mapping in "${CHART_MAPPINGS[@]}"; do
        local app_name="${mapping%%|*}"
        local app_file="$herramientas_dir/$app_name.yaml"
        
        if [[ ! -f "$app_file" ]]; then
            log_warning "⚠️ Archivo no encontrado: $app_file"
            continue
        fi
        
        log_info "🔍 Validando $app_name..."
        
        # Verificar estructura básica
        if ! grep -q "apiVersion: argoproj.io/v1alpha1" "$app_file"; then
            log_error "❌ $app_name: Falta apiVersion de ArgoCD"
            continue
        fi
        
        if ! grep -q "kind: Application" "$app_file"; then
            log_error "❌ $app_name: Falta kind Application"
            continue
        fi
        
        if ! grep -q "repoURL:" "$app_file"; then
            log_error "❌ $app_name: Falta repoURL"
            continue
        fi
        
        if ! grep -q "targetRevision:" "$app_file"; then
            log_error "❌ $app_name: Falta targetRevision"
            continue
        fi
        
        log_success "✅ $app_name estructura válida"
    done
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-check}"
    local herramientas_dir="${2:-}"
    
    # Detectar directorio de herramientas automáticamente
    if [[ -z "$herramientas_dir" ]]; then
        if [[ -d "$(pwd)/herramientas-gitops" ]]; then
            herramientas_dir="$(pwd)/herramientas-gitops"
        elif [[ -d "$(dirname "$0")/../../herramientas-gitops" ]]; then
            herramientas_dir="$(cd "$(dirname "$0")/../../herramientas-gitops" && pwd)"
        else
            log_error "❌ No se pudo encontrar el directorio herramientas-gitops"
            return 1
        fi
    fi
    
    case "$action" in
        "check")
            check_and_update_charts "$herramientas_dir"
            ;;
        "update")
            UPDATE_CHARTS=true check_and_update_charts "$herramientas_dir"
            ;;
        "versions")
            show_all_versions
            ;;
        "validate")
            validate_chart_configurations "$herramientas_dir"
            ;;
        *)
            log_error "❌ Acción no válida: $action"
            log_info "Uso: $0 [check|update|versions|validate] [directorio]"
            return 1
            ;;
    esac
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
