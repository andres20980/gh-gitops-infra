#!/bin/bash

# ============================================================================
# UTILIDAD DE DIAGNÓSTICOS - Validación y troubleshooting
# ============================================================================
# Consolidación de diagnostico-gitops.sh y validar-prerequisitos.sh
# Uso: ./scripts/utilidades/diagnosticos.sh [prereq|gitops|todo]
# ============================================================================

set -euo pipefail

# Directorio base del proyecto
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly BIBLIOTECAS_DIR="$SCRIPTS_DIR/bibliotecas"

# Cargar bibliotecas esenciales
for lib in "base" "logging" "validacion"; do
    lib_path="$BIBLIOTECAS_DIR/${lib}.sh"
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path"
    else
        echo "Error: Biblioteca $lib no encontrada" >&2
        exit 1
    fi
done

# ============================================================================
# VALIDACIÓN DE PREREQUISITOS
# ============================================================================

validar_prerequisitos() {
    log_section "🔍 Validación de Prerequisitos"
    
    local errores=0
    
    # Validar herramientas básicas
    log_subsection "🛠️ Herramientas Básicas"
    local tools=("docker" "kubectl" "helm" "git" "curl" "jq")
    for tool in "${tools[@]}"; do
        if validar_comando "$tool"; then
            log_check "$tool: ✅ Disponible" "success"
        else
            log_check "$tool: ❌ No encontrado" "error"
            ((errores++))
        fi
    done
    
    # Validar Docker
    log_subsection "🐳 Docker"
    if validar_docker; then
        log_check "Docker: ✅ Funcionando" "success"
    else
        log_check "Docker: ❌ No funciona" "error"
        ((errores++))
    fi
    
    # Validar Kubernetes
    log_subsection "☸️ Kubernetes"
    if validar_kubernetes; then
        log_check "Kubernetes: ✅ Cluster accesible" "success"
        
        # Verificar nodos
        local nodes
        nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        log_check "Nodos: $nodes disponibles" "info"
        
        # Verificar namespaces críticos
        local ns_criticos=("kube-system" "argocd")
        for ns in "${ns_criticos[@]}"; do
            if kubectl get namespace "$ns" >/dev/null 2>&1; then
                log_check "Namespace $ns: ✅ Existe" "success"
            else
                log_check "Namespace $ns: ⚠️ No existe" "warning"
            fi
        done
    else
        log_check "Kubernetes: ❌ No accesible" "error"
        ((errores++))
    fi
    
    # Resumen
    if [[ $errores -eq 0 ]]; then
        log_success "✅ Todos los prerequisitos cumplidos"
        return 0
    else
        log_error "❌ $errores errores encontrados"
        return 1
    fi
}

# ============================================================================
# DIAGNÓSTICO GITOPS
# ============================================================================

diagnostico_gitops() {
    log_section "🚀 Diagnóstico GitOps"
    
    # Verificar ArgoCD
    log_subsection "🔄 ArgoCD"
    if kubectl get namespace argocd >/dev/null 2>&1; then
        log_check "Namespace argocd: ✅ Existe" "success"
        
        # Estado de pods
        local pods_ready
        pods_ready=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep "Running" | wc -l)
        local pods_total
        pods_total=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
        log_check "Pods ArgoCD: $pods_ready/$pods_total ejecutándose" "info"
        
        # Verificar aplicaciones
        if comando_existe argocd; then
            log_info "Verificando aplicaciones ArgoCD..."
            argocd app list --server localhost:8080 --insecure 2>/dev/null | head -10 || true
        fi
    else
        log_check "ArgoCD: ❌ No instalado" "error"
    fi
    
    # Verificar herramientas GitOps
    log_subsection "🛠️ Herramientas GitOps"
    local herramientas=("prometheus-stack" "grafana" "loki" "jaeger")
    for herramienta in "${herramientas[@]}"; do
        if kubectl get applications "$herramienta" -n argocd >/dev/null 2>&1; then
            local status
            status=$(kubectl get applications "$herramienta" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            log_check "$herramienta: $status" "info"
        else
            log_check "$herramienta: ❌ No desplegado" "warning"
        fi
    done
    
    # Verificar Kargo si existe
    if [[ -f "$PROJECT_ROOT/herramientas-gitops/kargo.yaml" ]]; then
        log_subsection "🚛 Kargo"
        if kubectl get namespace kargo-system >/dev/null 2>&1; then
            log_check "Kargo: ✅ Instalado" "success"
        else
            log_check "Kargo: ⚠️ No instalado" "warning"
            log_info "Para instalar: kubectl apply -f herramientas-gitops/kargo.yaml"
        fi
    fi
    
    log_success "✅ Diagnóstico GitOps completado"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local action="${1:-todo}"
    
    case "$action" in
        "prereq"|"prerequisitos")
            validar_prerequisitos
            ;;
        "gitops")
            diagnostico_gitops
            ;;
        "todo")
            validar_prerequisitos
            echo ""
            diagnostico_gitops
            ;;
        *)
            log_error "Uso: $0 [prereq|gitops|todo]"
            exit 1
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
