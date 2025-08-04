#!/bin/bash

# ============================================================================
# ACTUALIZADOR AUTOMÁTICO DE HELM CHARTS
# ============================================================================
# Actualiza automáticamente las versiones de helm charts en los manifiestos
# de herramientas GitOps con las últimas versiones disponibles
# ============================================================================

# Cargar bibliotecas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIBLIOTECAS_DIR="$(dirname "$SCRIPT_DIR")/bibliotecas"

# shellcheck source=../bibliotecas/base.sh
source "$BIBLIOTECAS_DIR/base.sh"
# shellcheck source=../bibliotecas/logging.sh
source "$BIBLIOTECAS_DIR/logging.sh"
# shellcheck source=../bibliotecas/versiones.sh
source "$BIBLIOTECAS_DIR/versiones.sh"

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly HERRAMIENTAS_GITOPS_DIR="${PROJECT_ROOT}/herramientas-gitops"

# Mapa de herramientas GitOps con sus repositorios Helm
declare -A HELM_REPOSITORIES=(
    ["argo-rollouts"]="https://argoproj.github.io/argo-helm|argo-rollouts"
    ["argo-workflows"]="https://argoproj.github.io/argo-helm|argo-workflows"
    ["argo-events"]="https://argoproj.github.io/argo-helm|argo-events"
    ["prometheus-stack"]="https://prometheus-community.github.io/helm-charts|kube-prometheus-stack"
    ["grafana"]="https://grafana.github.io/helm-charts|grafana"
    ["loki"]="https://grafana.github.io/helm-charts|loki"
    ["jaeger"]="https://jaegertracing.github.io/helm-charts|jaeger"
    ["cert-manager"]="https://charts.jetstack.io|cert-manager"
    ["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx|ingress-nginx"
    ["external-secrets"]="https://charts.external-secrets.io|external-secrets"
    ["minio"]="https://charts.min.io|minio"
    ["gitea"]="https://dl.gitea.io/charts|gitea"
    ["kargo"]="https://charts.akuity.io|kargo"
)

# ============================================================================
# FUNCIONES DE ACTUALIZACIÓN
# ============================================================================

# Obtener última versión de un chart Helm
obtener_ultima_version_helm_chart() {
    local repo_url="$1"
    local chart_name="$2"
    
    log_debug "Obteniendo última versión de $chart_name desde $repo_url"
    
    # Añadir repo temporal si no existe
    local repo_alias="temp-$(echo "$repo_url" | sed 's/[^a-zA-Z0-9]/-/g')"
    
    if ! helm repo add "$repo_alias" "$repo_url" --force-update >/dev/null 2>&1; then
        log_warn "No se pudo añadir repositorio temporal: $repo_url"
        return 1
    fi
    
    # Actualizar repositorio
    if ! helm repo update "$repo_alias" >/dev/null 2>&1; then
        log_warn "No se pudo actualizar repositorio: $repo_alias"
        return 1
    fi
    
    # Obtener última versión
    local version
    version=$(helm search repo "$repo_alias/$chart_name" --output json 2>/dev/null | \
              jq -r '.[0].version // empty' 2>/dev/null)
    
    # Limpiar repo temporal
    helm repo remove "$repo_alias" >/dev/null 2>&1 || true
    
    if [[ -n "$version" && "$version" != "null" ]]; then
        echo "$version"
        return 0
    else
        log_warn "No se pudo obtener versión para $chart_name"
        return 1
    fi
}

# Actualizar versión en archivo YAML
actualizar_version_en_yaml() {
    local archivo="$1"
    local nueva_version="$2"
    local chart_name="$3"
    
    log_debug "Actualizando $archivo con versión $nueva_version para $chart_name"
    
    # Backup del archivo original
    cp "$archivo" "${archivo}.backup-$(date +%Y%m%d-%H%M%S)"
    
    # Actualizar targetRevision
    if grep -q "targetRevision:" "$archivo"; then
        sed -i "s/targetRevision:.*/targetRevision: $nueva_version/" "$archivo"
        log_info "✅ Actualizado $chart_name a versión $nueva_version en $(basename "$archivo")"
        return 0
    else
        log_warn "No se encontró campo targetRevision en $archivo"
        return 1
    fi
}

# Actualizar todas las herramientas GitOps
actualizar_herramientas_gitops() {
    log_section "🔄 Actualizando Versiones de Herramientas GitOps"
    
    if [[ ! -d "$HERRAMIENTAS_GITOPS_DIR" ]]; then
        log_error "Directorio de herramientas GitOps no encontrado: $HERRAMIENTAS_GITOPS_DIR"
        return 1
    fi
    
    # Verificar que Helm esté disponible
    if ! command -v helm >/dev/null 2>&1; then
        log_error "Helm no está instalado o no está en PATH"
        return 1
    fi
    
    # Verificar que jq esté disponible
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq no está instalado, instalando..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update >/dev/null 2>&1
            sudo apt-get install -y jq >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y jq >/dev/null 2>&1
        else
            log_error "No se pudo instalar jq automáticamente"
            return 1
        fi
    fi
    
    local actualizaciones_realizadas=0
    local total_herramientas=${#HELM_REPOSITORIES[@]}
    
    log_info "Procesando $total_herramientas herramientas GitOps..."
    
    for herramienta in "${!HELM_REPOSITORIES[@]}"; do
        local info="${HELM_REPOSITORIES[$herramienta]}"
        local repo_url="${info%|*}"
        local chart_name="${info#*|}"
        local archivo_yaml="$HERRAMIENTAS_GITOPS_DIR/${herramienta}.yaml"
        
        log_info "📦 Procesando $herramienta ($chart_name)..."
        
        # Verificar que el archivo YAML existe
        if [[ ! -f "$archivo_yaml" ]]; then
            log_warn "Archivo no encontrado: $archivo_yaml"
            continue
        fi
        
        # Obtener versión actual
        local version_actual
        version_actual=$(grep "targetRevision:" "$archivo_yaml" | awk '{print $2}' | head -n1)
        
        # Obtener última versión disponible
        local ultima_version
        if ultima_version=$(obtener_ultima_version_helm_chart "$repo_url" "$chart_name"); then
            log_debug "Versión actual: $version_actual | Última versión: $ultima_version"
            
            # Comparar versiones
            if [[ "$version_actual" != "$ultima_version" ]]; then
                log_info "🔄 Actualizando $herramienta: $version_actual → $ultima_version"
                
                if actualizar_version_en_yaml "$archivo_yaml" "$ultima_version" "$herramienta"; then
                    ((actualizaciones_realizadas++))
                else
                    log_warn "Fallo al actualizar $herramienta"
                fi
            else
                log_info "✅ $herramienta ya está en la última versión ($version_actual)"
            fi
        else
            log_warn "No se pudo obtener la última versión para $herramienta"
        fi
    done
    
    # Resumen de actualizaciones
    if [[ $actualizaciones_realizadas -gt 0 ]]; then
        log_success "✅ Se actualizaron $actualizaciones_realizadas herramientas GitOps"
        log_info "💾 Los archivos originales se guardaron como backup"
    else
        log_info "ℹ️ Todas las herramientas ya están en sus últimas versiones"
    fi
    
    return 0
}

# Validar que todas las versiones estén actualizadas
validar_versiones_actualizadas() {
    log_section "🔍 Validando Versiones de Herramientas GitOps"
    
    local versiones_desactualizadas=0
    
    for herramienta in "${!HELM_REPOSITORIES[@]}"; do
        local info="${HELM_REPOSITORIES[$herramienta]}"
        local repo_url="${info%|*}"
        local chart_name="${info#*|}"
        local archivo_yaml="$HERRAMIENTAS_GITOPS_DIR/${herramienta}.yaml"
        
        if [[ -f "$archivo_yaml" ]]; then
            local version_actual
            version_actual=$(grep "targetRevision:" "$archivo_yaml" | awk '{print $2}' | head -n1)
            
            local ultima_version
            if ultima_version=$(obtener_ultima_version_helm_chart "$repo_url" "$chart_name"); then
                if [[ "$version_actual" != "$ultima_version" ]]; then
                    log_warn "⚠️ $herramienta está desactualizado: $version_actual (disponible: $ultima_version)"
                    ((versiones_desactualizadas++))
                else
                    log_debug "✅ $herramienta está actualizado: $version_actual"
                fi
            fi
        fi
    done
    
    if [[ $versiones_desactualizadas -eq 0 ]]; then
        log_success "✅ Todas las herramientas GitOps están actualizadas"
        return 0
    else
        log_warn "⚠️ $versiones_desactualizadas herramientas necesitan actualización"
        return 1
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

actualizar_helm_charts_automaticamente() {
    log_info "🚀 Iniciando actualización automática de Helm Charts"
    
    # Actualizar herramientas GitOps
    if ! actualizar_herramientas_gitops; then
        log_error "Fallo en la actualización de herramientas GitOps"
        return 1
    fi
    
    # Validar que todo esté actualizado
    if validar_versiones_actualizadas; then
        log_success "✅ Actualización automática completada exitosamente"
        return 0
    else
        log_warn "⚠️ Actualización completada con advertencias"
        return 0
    fi
}

# ============================================================================
# EXPORTAR FUNCIONES
# ============================================================================

export -f obtener_ultima_version_helm_chart
export -f actualizar_version_en_yaml
export -f actualizar_herramientas_gitops
export -f validar_versiones_actualizadas
export -f actualizar_helm_charts_automaticamente

# Información del módulo
export CHART_UPDATER_VERSION="1.0.0"
export CHART_UPDATER_DESCRIPTION="Actualizador automático de Helm Charts"

log_debug "Módulo actualizador de Helm Charts cargado (v$CHART_UPDATER_VERSION)"
