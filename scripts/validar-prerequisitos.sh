#!/bin/bash

# ============================================================================
# VALIDADOR DE PREREQUISITOS - Verifica dependencias antes de instalación
# ============================================================================

set -euo pipefail

# Directorio base del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar librerías
source "${SCRIPT_DIR}/lib/comun.sh"
source "${SCRIPT_DIR}/lib/registro.sh"

# Función para validar comando existe y versión mínima
validate_command_version() {
    local command=$1
    local min_version=$2
    local version_flag=${3:---version}
    local version_pattern=${4:-'[0-9]+\.[0-9]+\.[0-9]+'}
    
    if ! command_exists "$command"; then
        log_error "❌ $command no está instalado"
        return 1
    fi
    
    local current_version
    current_version=$($command $version_flag 2>&1 | grep -oE "$version_pattern" | head -1)
    
    if [[ -z "$current_version" ]]; then
        log_warning "⚠️  No se pudo determinar la versión de $command"
        return 0  # Continuar si no podemos determinar la versión
    fi
    
    if printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1 | grep -q "^$min_version$"; then
        log_exito "✅ $command v$current_version (mínimo: v$min_version)"
        return 0
    else
        log_error "❌ $command v$current_version es muy antigua (mínimo: v$min_version)"
        return 1
    fi
}

# Función para validar kubectl y conectividad al cluster
validate_kubernetes() {
    log_seccion "Kubernetes y kubectl"
    
    # Validar kubectl
    if ! validate_command_version "kubectl" "1.24.0"; then
        log_error "kubectl no está disponible o es muy antiguo" \
                               "Se requiere kubectl v1.24.0 o superior" \
                               "Instala kubectl desde: https://kubernetes.io/docs/tasks/tools/"
        return 1
    fi
    
    # Validar conectividad al cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "No hay conectividad al cluster Kubernetes" \
                               "kubectl no puede conectar al cluster" \
                               "Verifica tu configuración de kubeconfig y la conectividad de red"
        return 1
    fi
    
    # Obtener información del cluster
    local context=$(kubectl config current-context)
    local server=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name=="'$(kubectl config view --raw -o json | jq -r '.contexts[] | select(.name=="'$context'") | .context.cluster')'") | .cluster.server')
    
    log_exito "✅ Conectado al cluster: $context"
    log_info "   Server: $server"
    
    # Validar permisos administrativos
    if kubectl auth can-i create namespaces >/dev/null 2>&1; then
        log_exito "✅ Permisos administrativos verificados"
    else
        log_error "❌ Sin permisos administrativos en el cluster"
        return 1
    fi
    
    return 0
}

# Función para validar Helm
validate_helm() {
    log_seccion "Helm Package Manager"
    
    if ! validate_command_version "helm" "3.10.0"; then
        log_error "Helm no está disponible o es muy antiguo" \
                               "Se requiere Helm v3.10.0 o superior" \
                               "Instala Helm desde: https://helm.sh/docs/intro/install/"
        return 1
    fi
    
    # Verificar repositorios Helm críticos
    log_info "Verificando repositorios Helm..."
    
    local repos_needed=("argo" "prometheus-community" "grafana")
    local repos_missing=()
    
    for repo in "${repos_needed[@]}"; do
        if ! helm repo list 2>/dev/null | grep -q "^$repo\s"; then
            repos_missing+=("$repo")
        fi
    done
    
    if [[ ${#repos_missing[@]} -gt 0 ]]; then
        log_warning "⚠️  Algunos repositorios Helm no están configurados: ${repos_missing[*]}"
        log_info "   Se configurarán automáticamente durante la instalación"
    else
        log_exito "✅ Repositorios Helm principales configurados"
    fi
    
    return 0
}

# Función para validar herramientas del sistema
validate_system_tools() {
    log_seccion "Herramientas del Sistema"
    
    local required_tools=("curl" "jq" "git" "openssl")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if command_exists "$tool"; then
            log_exito "✅ $tool disponible"
        else
            missing_tools+=("$tool")
            log_error "❌ $tool no está instalado"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Herramientas del sistema faltantes: ${missing_tools[*]}" \
                               "Estas herramientas son necesarias para la instalación" \
                               "Instálalas usando: sudo apt-get install ${missing_tools[*]} (Ubuntu/Debian)"
        return 1
    fi
    
    return 0
}

# Función para validar recursos del cluster
validate_cluster_resources() {
    log_seccion "Recursos del Cluster"
    
    # Verificar nodos
    local node_count=$(kubectl get nodes --no-headers | wc -l)
    log_info "🔍 Nodos disponibles: $node_count"
    
    if [[ $node_count -eq 0 ]]; then
        log_error "❌ No hay nodos disponibles en el cluster"
        return 1
    fi
    
    # Verificar recursos computacionales
    check_cluster_resources 4 2  # Mínimo 4GB RAM, 2 CPU cores
    
    # Verificar storage classes
    local storage_classes=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
    if [[ $storage_classes -eq 0 ]]; then
        log_warning "⚠️  No hay StorageClasses configuradas"
        log_info "   Algunos componentes pueden requerir almacenamiento persistente"
    else
        log_exito "✅ StorageClasses disponibles: $storage_classes"
    fi
    
    return 0
}

# Función para validar puertos de red
validate_network_ports() {
    log_seccion "Puertos de Red"
    
    local required_ports=(8080 8081 3000 9090 16686)
    local ports_in_use=()
    
    for port in "${required_ports[@]}"; do
        if is_port_in_use "$port"; then
            ports_in_use+=("$port")
            log_warning "⚠️  Puerto $port está en uso"
        else
            log_exito "✅ Puerto $port disponible"
        fi
    done
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log_warning "⚠️  Algunos puertos están en uso: ${ports_in_use[*]}"
        log_info "   Esto puede afectar el acceso a las UIs web"
        log_info "   Usa 'sudo lsof -i :PORT' para identificar procesos"
    fi
    
    return 0
}

# Función para validar configuración específica de GitOps
validate_gitops_config() {
    log_seccion "Configuración GitOps"
    
    # Verificar si ya hay instalaciones previas
    local existing_apps=()
    
    for component in "${CRITICAL_COMPONENTS[@]}"; do
        if is_component_installed "$component"; then
            existing_apps+=("$component")
        fi
    done
    
    if [[ ${#existing_apps[@]} -gt 0 ]]; then
        log_warning "⚠️  Componentes ya instalados detectados: ${existing_apps[*]}"
        log_info "   La instalación intentará actualizar en lugar de instalar desde cero"
    else
        log_exito "✅ No hay instalaciones previas detectadas"
    fi
    
    # Verificar conectividad a repositorios Git
    log_info "🔍 Verificando conectividad a repositorios..."
    
    if curl -s --connect-timeout 5 https://github.com >/dev/null; then
        log_exito "✅ Conectividad a GitHub disponible"
    else
        log_warning "⚠️  Sin conectividad a GitHub"
        log_info "   Puede afectar la descarga de charts y configuraciones"
    fi
    
    return 0
}

# Función principal de validación
main() {
    log_seccion "Validación de Prerequisitos" "v2.1.0"
    
    local validation_failed=false
    
    # Ejecutar todas las validaciones
    validate_system_tools || validation_failed=true
    validate_helm || validation_failed=true
    validate_kubernetes || validation_failed=true
    validate_cluster_resources || validation_failed=true
    validate_network_ports || validation_failed=true
    validate_gitops_config || validation_failed=true
    
    echo ""
    if [[ "$validation_failed" == "true" ]]; then
        log_section "❌ Validación Fallida"
        log_error "Algunos prerequisitos no se cumplen"
        log_info "Revisa los errores anteriores y corrige los problemas antes de continuar"
        log_info "Para más ayuda, consulta: README.md"
        exit 1
    else
        log_section "✅ Validación Exitosa"
        log_exito "Todos los prerequisitos se cumplen"
        log_info "El sistema está listo para la instalación GitOps"
        
        # Mostrar resumen
        echo ""
        log_info "📋 Resumen del entorno:"
        log_info "  • Kubernetes: $(get_kubernetes_version)"
        log_info "  • Helm: $(helm version --short --client)"
        log_info "  • Contexto: $(kubectl config current-context)"
        log_info "  • Nodos: $(kubectl get nodes --no-headers | wc -l)"
        log_info "  • Modo recursos: ${LOW_RESOURCES_MODE:-false}"
    fi
}

# Ejecutar validación si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
