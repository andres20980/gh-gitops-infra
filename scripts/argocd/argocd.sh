#!/bin/bash

# ============================================================================
# MÓDULO ARGOCD - Instalación y configuración de ArgoCD en castellano
# ============================================================================

# Importar librerías
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIBLIOTECAS_DIR="$(dirname "$SCRIPT_DIR")/bibliotecas"

# shellcheck source=../bibliotecas/base.sh
source "$BIBLIOTECAS_DIR/base.sh"
# shellcheck source=../bibliotecas/logging.sh
source "$BIBLIOTECAS_DIR/logging.sh"
# shellcheck source=../bibliotecas/comun.sh
source "$BIBLIOTECAS_DIR/comun.sh"
# shellcheck source=../bibliotecas/registro.sh
source "$BIBLIOTECAS_DIR/registro.sh"
# shellcheck source=../bibliotecas/versiones.sh
source "$BIBLIOTECAS_DIR/versiones.sh"

# Configuración específica de ArgoCD
ARGOCD_NAMESPACE="argocd"
ARGOCD_REPO_URL="https://argoproj.github.io/argo-helm"
ARGOCD_CHART_NAME="argo-cd"

# Función principal para instalar ArgoCD
instalar_argocd() {
    log_section "🎯 INSTALACIÓN DE ARGOCD"
    log_info "Instalación de ArgoCD v${ARGOCD_VERSION}"
    
    # Verificar si ya está instalado
    if componente_instalado "argocd" "$ARGOCD_NAMESPACE"; then
        log_exito "ArgoCD ya está instalado"
        return 0
    fi
    
    # Agregar repositorio Helm
    agregar_repo_helm_si_no_existe "argo" "$ARGOCD_REPO_URL"
    
    # Actualizar repositorios
    ejecutar_comando "helm repo update" "Actualizando repositorios Helm"
    
    # Crear namespace
    crear_namespace_si_no_existe "$ARGOCD_NAMESPACE"
    
    # Obtener configuración optimizada para recursos
    local recursos_optimizados=$(obtener_recursos_optimizados "argocd")
    
    # Configuración base de ArgoCD
    local valores_helm=""
    valores_helm="$valores_helm --set global.domain=argocd.local"
    valores_helm="$valores_helm --set server.service.type=ClusterIP"
    valores_helm="$valores_helm --set server.ingress.enabled=false"
    valores_helm="$valores_helm --set configs.params.server\\.insecure=true"
    valores_helm="$valores_helm --set configs.params.server\\.grpc\\.web=true"
    
    # Aplicar optimizaciones si hay recursos limitados
    if [[ -n "$recursos_optimizados" ]]; then
        valores_helm="$valores_helm $recursos_optimizados"
        log_info "Aplicando configuración optimizada para recursos limitados"
    fi
    
    # Instalar ArgoCD
    local comando_instalacion="helm install argocd argo/${ARGOCD_CHART_NAME} \
        --namespace ${ARGOCD_NAMESPACE} \
        --version ${ARGOCD_VERSION} \
        ${valores_helm} \
        --wait \
        --timeout=600s"
    
    if ejecutar_comando "$comando_instalacion" "Instalando ArgoCD"; then
        log_exito "ArgoCD instalado correctamente"
    else
        log_error "Error instalando ArgoCD"
        limpiar_en_error "argocd"
        return 1
    fi
    
    # Esperar a que ArgoCD esté listo
    esperar_deployment_listo "$ARGOCD_NAMESPACE" "argocd-server" 300
    
    # Configurar password inicial
    configurar_password_argocd
    
    log_fin_operacion "Instalación de ArgoCD" "éxito"
    return 0
}

# Función para configurar la contraseña de ArgoCD
configurar_password_argocd() {
    log_inicio_operacion "Configuración de contraseña ArgoCD"
    
    if es_dry_run; then
        log_info "[DRY-RUN] Configurando contraseña de admin para ArgoCD"
        return 0
    fi
    
    # Obtener contraseña inicial
    local password_inicial=""
    local intentos=0
    local max_intentos=10
    
    while [[ $intentos -lt $max_intentos ]]; do
        password_inicial=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        
        if [[ -n "$password_inicial" ]]; then
            break
        fi
        
        log_info "Esperando que se genere la contraseña inicial... (intento $((intentos + 1))/$max_intentos)"
        sleep 10
        ((intentos++))
    done
    
    if [[ -n "$password_inicial" ]]; then
        log_exito "Contraseña inicial de ArgoCD obtenida"
        log_info "Usuario: admin"
        log_info "Contraseña: $password_inicial"
        
        # Guardar credenciales en archivo temporal para scripts posteriores
        echo "ARGOCD_ADMIN_PASSWORD='$password_inicial'" > "/tmp/argocd-credentials.sh"
        chmod 600 "/tmp/argocd-credentials.sh"
        
        log_info "Credenciales guardadas en: /tmp/argocd-credentials.sh"
    else
        log_warning "No se pudo obtener la contraseña inicial automáticamente"
        log_info "Puedes obtenerla manualmente con:"
        log_info "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    fi
}

# Función para validar instalación de ArgoCD
validar_argocd() {
    log_inicio_operacion "Validación de ArgoCD"
    
    # Verificar que el namespace existe
    if ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace $ARGOCD_NAMESPACE no existe"
        return 1
    fi
    
    # Verificar deployments
    local deployments=("argocd-server" "argocd-repo-server" "argocd-application-controller")
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
            local replicas_disponibles=$(kubectl get deployment "$deployment" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
            local replicas_deseadas=$(kubectl get deployment "$deployment" -n "$ARGOCD_NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$replicas_disponibles" == "$replicas_deseadas" && "$replicas_disponibles" != "0" ]]; then
                log_exito "Deployment $deployment está funcionando correctamente ($replicas_disponibles/$replicas_deseadas replicas)"
            else
                log_error "Deployment $deployment no está listo ($replicas_disponibles/$replicas_deseadas replicas)"
                return 1
            fi
        else
            log_error "Deployment $deployment no encontrado"
            return 1
        fi
    done
    
    # Verificar servicios
    local servicios=("argocd-server" "argocd-repo-server")
    for servicio in "${servicios[@]}"; do
        if kubectl get service "$servicio" -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
            log_exito "Servicio $servicio existe"
        else
            log_error "Servicio $servicio no encontrado"
            return 1
        fi
    done
    
    # Verificar conectividad de la API
    if ! es_dry_run; then
        local puerto_forward_pid=""
        
        # Crear port-forward temporal para test
        kubectl port-forward svc/argocd-server -n "$ARGOCD_NAMESPACE" 8080:80 >/dev/null 2>&1 &
        puerto_forward_pid=$!
        
        sleep 5
        
        # Test de conectividad
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/healthz" | grep -q "200"; then
            log_exito "API de ArgoCD responde correctamente"
        else
            log_warning "API de ArgoCD no responde o no está lista (esto es normal en primeras instalaciones)"
        fi
        
        # Limpiar port-forward
        if [[ -n "$puerto_forward_pid" ]]; then
            kill "$puerto_forward_pid" 2>/dev/null || true
        fi
    fi
    
    log_fin_operacion "Validación de ArgoCD" "éxito"
    return 0
}

# Función para desinstalar ArgoCD
desinstalar_argocd() {
    log_inicio_operacion "Desinstalación de ArgoCD"
    
    if ! componente_instalado "argocd" "$ARGOCD_NAMESPACE"; then
        log_info "ArgoCD no está instalado"
        return 0
    fi
    
    # Desinstalar Helm release
    ejecutar_comando "helm uninstall argocd -n ${ARGOCD_NAMESPACE}" "Desinstalando ArgoCD"
    
    # Eliminar namespace (opcional)
    read -p "¿Eliminar namespace $ARGOCD_NAMESPACE? (s/N): " respuesta
    if [[ "$respuesta" =~ ^[sS]$ ]]; then
        ejecutar_comando "kubectl delete namespace ${ARGOCD_NAMESPACE}" "Eliminando namespace $ARGOCD_NAMESPACE"
    fi
    
    # Limpiar archivos temporales
    rm -f "/tmp/argocd-credentials.sh"
    
    log_fin_operacion "Desinstalación de ArgoCD" "éxito"
}

# Función para obtener información de ArgoCD
info_argocd() {
    log_seccion "INFORMACIÓN DE ARGOCD"
    
    if ! componente_instalado "argocd" "$ARGOCD_NAMESPACE"; then
        log_info "ArgoCD no está instalado"
        return 1
    fi
    
    # Información general
    local version_instalada=$(helm list -n "$ARGOCD_NAMESPACE" -o json | jq -r '.[] | select(.name=="argocd") | .chart' 2>/dev/null | cut -d'-' -f2- || echo "desconocida")
    log_info "Versión instalada: $version_instalada"
    log_info "Namespace: $ARGOCD_NAMESPACE"
    
    # Estado de pods
    echo ""
    log_info "Estado de pods:"
    kubectl get pods -n "$ARGOCD_NAMESPACE" -o wide 2>/dev/null || log_error "No se pudo obtener información de pods"
    
    # Estado de servicios
    echo ""
    log_info "Estado de servicios:"
    kubectl get services -n "$ARGOCD_NAMESPACE" 2>/dev/null || log_error "No se pudo obtener información de servicios"
    
    # Aplicaciones gestionadas
    echo ""
    log_info "Aplicaciones gestionadas por ArgoCD:"
    kubectl get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || log_info "No hay aplicaciones configuradas"
    
    # Credenciales si existen
    if [[ -f "/tmp/argocd-credentials.sh" ]]; then
        echo ""
        log_info "Credenciales disponibles en: /tmp/argocd-credentials.sh"
        source "/tmp/argocd-credentials.sh" 2>/dev/null || true
        if [[ -n "${ARGOCD_ADMIN_PASSWORD:-}" ]]; then
            log_info "Usuario: admin"
            log_info "Contraseña: $ARGOCD_ADMIN_PASSWORD"
        fi
    fi
    
    # Información de acceso
    echo ""
    log_info "Para acceder a ArgoCD UI:"
    log_info "1. Ejecutar port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:80"
    log_info "2. Abrir navegador en: http://localhost:8080"
}

# Función para configurar aplicaciones iniciales
configurar_aplicaciones_iniciales() {
    log_inicio_operacion "Configuración de aplicaciones iniciales"
    
    if ! componente_instalado "argocd" "$ARGOCD_NAMESPACE"; then
        log_error "ArgoCD no está instalado"
        return 1
    fi
    
    # Aplicar app-of-apps principal si existe
    local app_of_apps_file="$(dirname "$SCRIPT_DIR")/app-of-apps-gitops.yaml"
    if [[ -f "$app_of_apps_file" ]]; then
        ejecutar_comando "kubectl apply -f ${app_of_apps_file}" "Aplicando app-of-apps principal"
        log_exito "App-of-apps principal configurada"
    else
        log_warning "No se encontró app-of-apps-gitops.yaml"
    fi
    
    # Aplicar ApplicationSet si existe
    local appset_file="$(dirname "$SCRIPT_DIR")/appset-aplicaciones.yaml"
    if [[ -f "$appset_file" ]]; then
        ejecutar_comando "kubectl apply -f ${appset_file}" "Aplicando ApplicationSet"
        log_exito "ApplicationSet configurado"
    else
        log_warning "No se encontró appset-aplicaciones.yaml"
    fi
    
    log_fin_operacion "Configuración de aplicaciones iniciales" "éxito"
}

# Función principal del módulo
main() {
    local accion="${1:-instalar}"
    
    case "$accion" in
        "instalar"|"install")
            instalar_argocd
            ;;
        "validar"|"validate")
            validar_argocd
            ;;
        "desinstalar"|"uninstall")
            desinstalar_argocd
            ;;
        "info"|"información")
            info_argocd
            ;;
        "configurar-apps"|"setup-apps")
            configurar_aplicaciones_iniciales
            ;;
        *)
            echo "Uso: $0 {instalar|validar|desinstalar|info|configurar-apps}"
            echo "  instalar         - Instala ArgoCD"
            echo "  validar          - Valida la instalación"
            echo "  desinstalar      - Desinstala ArgoCD"
            echo "  info             - Muestra información del componente"
            echo "  configurar-apps  - Configura aplicaciones iniciales"
            exit 1
            ;;
    esac
}

# Ejecutar función principal si el script es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
