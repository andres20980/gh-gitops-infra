#!/bin/bash

# ============================================================================
# MÓDULO KARGO - Instalación y configuración de Kargo en castellano
# ============================================================================

# Importar librerías
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/comun.sh"
source "${SCRIPT_DIR}/../lib/registro.sh"

# Configuración específica de Kargo
KARGO_VERSION="${VERSIONES_COMPONENTES[kargo]}"
KARGO_NAMESPACE="kargo-system"
KARGO_REPO_URL="${REPOSITORIOS_HELM[akuity]}"
KARGO_CHART_NAME="kargo"

# Función principal para instalar Kargo
instalar_kargo() {
    log_seccion "INSTALACIÓN DE KARGO (SUPER IMPORTANTE)"
    log_inicio_operacion "Instalación de Kargo v${KARGO_VERSION}"
    
    # Verificar si ya está instalado
    if componente_instalado "kargo" "$KARGO_NAMESPACE"; then
        log_exito "Kargo ya está instalado"
        return 0
    fi
    
    # Verificar que ArgoCD esté instalado (prerequisito)
    if ! componente_instalado "argocd" "argocd"; then
        log_error "ArgoCD debe estar instalado antes que Kargo"
        log_info "Ejecuta primero: scripts/modulos/argocd.sh instalar"
        return 1
    fi
    
    # Agregar repositorio Helm
    agregar_repo_helm_si_no_existe "akuity" "$KARGO_REPO_URL"
    
    # Actualizar repositorios
    ejecutar_comando "helm repo update" "Actualizando repositorios Helm"
    
    # Crear namespace
    crear_namespace_si_no_existe "$KARGO_NAMESPACE"
    
    # Obtener configuración optimizada para recursos
    local recursos_optimizados=$(obtener_recursos_optimizados "kargo")
    
    # Configuración base de Kargo
    local valores_helm=""
    valores_helm="$valores_helm --set api.service.type=ClusterIP"
    valores_helm="$valores_helm --set api.ingress.enabled=false"
    valores_helm="$valores_helm --set controller.enabled=true"
    valores_helm="$valores_helm --set webhooks.enabled=true"
    valores_helm="$valores_helm --set garbage-collector.enabled=true"
    
    # Configuración de integración con ArgoCD
    valores_helm="$valores_helm --set api.argocd.namespace=argocd"
    valores_helm="$valores_helm --set api.argocd.urls[0]=http://argocd-server.argocd.svc.cluster.local"
    
    # Aplicar optimizaciones si hay recursos limitados
    if [[ -n "$recursos_optimizados" ]]; then
        valores_helm="$valores_helm $recursos_optimizados"
        log_info "Aplicando configuración optimizada para recursos limitados"
    fi
    
    # Instalar Kargo
    local comando_instalacion="helm install kargo akuity/${KARGO_CHART_NAME} \
        --namespace ${KARGO_NAMESPACE} \
        --version ${KARGO_VERSION} \
        ${valores_helm} \
        --wait \
        --timeout=600s"
    
    if ejecutar_comando "$comando_instalacion" "Instalando Kargo"; then
        log_exito "Kargo instalado correctamente"
    else
        log_error "Error instalando Kargo"
        limpiar_en_error "kargo"
        return 1
    fi
    
    # Esperar a que Kargo esté listo
    esperar_deployment_listo "$KARGO_NAMESPACE" "kargo-api" 300
    esperar_deployment_listo "$KARGO_NAMESPACE" "kargo-controller" 300
    
    # Configurar RBAC para integración con ArgoCD
    configurar_rbac_kargo
    
    log_fin_operacion "Instalación de Kargo" "éxito"
    return 0
}

# Función para configurar RBAC de Kargo
configurar_rbac_kargo() {
    log_inicio_operacion "Configuración RBAC para Kargo"
    
    if es_dry_run; then
        log_info "[DRY-RUN] Configurando RBAC para integración Kargo-ArgoCD"
        return 0
    fi
    
    # Crear ClusterRole para Kargo
    cat <<EOF | kubectl apply -f - || log_warning "Error aplicando ClusterRole de Kargo"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kargo-argocd-integration
rules:
- apiGroups: ["argoproj.io"]
  resources: ["applications", "appprojects"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
EOF

    # Crear ClusterRoleBinding
    cat <<EOF | kubectl apply -f - || log_warning "Error aplicando ClusterRoleBinding de Kargo"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kargo-argocd-integration
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kargo-argocd-integration
subjects:
- kind: ServiceAccount
  name: kargo-api
  namespace: ${KARGO_NAMESPACE}
EOF

    log_exito "RBAC configurado para integración Kargo-ArgoCD"
}

# Función para validar instalación de Kargo
validar_kargo() {
    log_inicio_operacion "Validación de Kargo"
    
    # Verificar que el namespace existe
    if ! kubectl get namespace "$KARGO_NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace $KARGO_NAMESPACE no existe"
        return 1
    fi
    
    # Verificar deployments
    local deployments=("kargo-api" "kargo-controller" "kargo-webhooks-server")
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$KARGO_NAMESPACE" >/dev/null 2>&1; then
            local replicas_disponibles=$(kubectl get deployment "$deployment" -n "$KARGO_NAMESPACE" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
            local replicas_deseadas=$(kubectl get deployment "$deployment" -n "$KARGO_NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [[ "$replicas_disponibles" == "$replicas_deseadas" && "$replicas_disponibles" != "0" ]]; then
                log_exito "Deployment $deployment está funcionando correctamente ($replicas_disponibles/$replicas_deseadas replicas)"
            else
                log_error "Deployment $deployment no está listo ($replicas_disponibles/$replicas_deseadas replicas)"
                return 1
            fi
        else
            log_warning "Deployment $deployment no encontrado (puede no estar habilitado)"
        fi
    done
    
    # Verificar servicios
    local servicios=("kargo-api" "kargo-webhooks-server")
    for servicio in "${servicios[@]}"; do
        if kubectl get service "$servicio" -n "$KARGO_NAMESPACE" >/dev/null 2>&1; then
            log_exito "Servicio $servicio existe"
        else
            log_warning "Servicio $servicio no encontrado"
        fi
    done
    
    # Verificar CRDs de Kargo
    local crds=("projects.kargo.akuity.io" "stages.kargo.akuity.io" "promotions.kargo.akuity.io" "freights.kargo.akuity.io")
    for crd in "${crds[@]}"; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            log_exito "CRD $crd instalado"
        else
            log_error "CRD $crd no encontrado"
            return 1
        fi
    done
    
    # Verificar conectividad de la API
    if ! es_dry_run; then
        local puerto_forward_pid=""
        
        # Crear port-forward temporal para test
        kubectl port-forward svc/kargo-api -n "$KARGO_NAMESPACE" 8081:80 >/dev/null 2>&1 &
        puerto_forward_pid=$!
        
        sleep 5
        
        # Test de conectividad
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081/healthz" | grep -q "200"; then
            log_exito "API de Kargo responde correctamente"
        else
            log_warning "API de Kargo no responde o no está lista"
        fi
        
        # Limpiar port-forward
        if [[ -n "$puerto_forward_pid" ]]; then
            kill "$puerto_forward_pid" 2>/dev/null || true
        fi
    fi
    
    log_fin_operacion "Validación de Kargo" "éxito"
    return 0
}

# Función para desinstalar Kargo
desinstalar_kargo() {
    log_inicio_operacion "Desinstalación de Kargo"
    
    if ! componente_instalado "kargo" "$KARGO_NAMESPACE"; then
        log_info "Kargo no está instalado"
        return 0
    fi
    
    # Advertencia especial para Kargo
    echo -e "${ROJO}⚠️  ADVERTENCIA: Kargo es SUPER IMPORTANTE para el proyecto${SIN_COLOR}"
    echo -e "${ROJO}⚠️  Su desinstalación puede afectar la gestión de promociones${SIN_COLOR}"
    read -p "¿Estás seguro de que quieres desinstalar Kargo? (escribe 'SI' para confirmar): " confirmacion
    
    if [[ "$confirmacion" != "SI" ]]; then
        log_info "Desinstalación cancelada"
        return 0
    fi
    
    # Limpiar recursos de Kargo primero
    limpiar_recursos_kargo
    
    # Desinstalar Helm release
    ejecutar_comando "helm uninstall kargo -n ${KARGO_NAMESPACE}" "Desinstalando Kargo"
    
    # Eliminar RBAC
    kubectl delete clusterrolebinding kargo-argocd-integration 2>/dev/null || true
    kubectl delete clusterrole kargo-argocd-integration 2>/dev/null || true
    
    # Eliminar namespace (opcional)
    read -p "¿Eliminar namespace $KARGO_NAMESPACE? (s/N): " respuesta
    if [[ "$respuesta" =~ ^[sS]$ ]]; then
        ejecutar_comando "kubectl delete namespace ${KARGO_NAMESPACE}" "Eliminando namespace $KARGO_NAMESPACE"
    fi
    
    log_fin_operacion "Desinstalación de Kargo" "éxito"
}

# Función para limpiar recursos de Kargo
limpiar_recursos_kargo() {
    log_info "Limpiando recursos de Kargo..."
    
    # Eliminar proyectos de Kargo
    kubectl delete projects --all -A 2>/dev/null || true
    
    # Eliminar stages
    kubectl delete stages --all -A 2>/dev/null || true
    
    # Eliminar promotions
    kubectl delete promotions --all -A 2>/dev/null || true
    
    # Eliminar freights
    kubectl delete freights --all -A 2>/dev/null || true
    
    log_info "Recursos de Kargo limpiados"
}

# Función para obtener información de Kargo
info_kargo() {
    log_seccion "INFORMACIÓN DE KARGO (SUPER IMPORTANTE)"
    
    if ! componente_instalado "kargo" "$KARGO_NAMESPACE"; then
        log_info "Kargo no está instalado"
        return 1
    fi
    
    # Información general
    local version_instalada=$(helm list -n "$KARGO_NAMESPACE" -o json | jq -r '.[] | select(.name=="kargo") | .chart' 2>/dev/null | cut -d'-' -f2- || echo "desconocida")
    log_info "Versión instalada: $version_instalada"
    log_info "Namespace: $KARGO_NAMESPACE"
    
    # Estado de pods
    echo ""
    log_info "Estado de pods:"
    kubectl get pods -n "$KARGO_NAMESPACE" -o wide 2>/dev/null || log_error "No se pudo obtener información de pods"
    
    # Estado de servicios
    echo ""
    log_info "Estado de servicios:"
    kubectl get services -n "$KARGO_NAMESPACE" 2>/dev/null || log_error "No se pudo obtener información de servicios"
    
    # Proyectos de Kargo
    echo ""
    log_info "Proyectos de Kargo:"
    kubectl get projects --all-namespaces 2>/dev/null || log_info "No hay proyectos configurados"
    
    # Stages de Kargo
    echo ""
    log_info "Stages de Kargo:"
    kubectl get stages --all-namespaces 2>/dev/null || log_info "No hay stages configurados"
    
    # Información de acceso
    echo ""
    log_info "Para acceder a Kargo UI:"
    log_info "1. Ejecutar port-forward: kubectl port-forward svc/kargo-api -n kargo-system 8081:80"
    log_info "2. Abrir navegador en: http://localhost:8081"
}

# Función para crear proyecto de ejemplo
crear_proyecto_ejemplo() {
    log_inicio_operacion "Creación de proyecto ejemplo de Kargo"
    
    if ! componente_instalado "kargo" "$KARGO_NAMESPACE"; then
        log_error "Kargo no está instalado"
        return 1
    fi
    
    # Crear namespace para el proyecto ejemplo
    crear_namespace_si_no_existe "kargo-demo"
    
    # Crear proyecto de Kargo
    cat <<EOF | kubectl apply -f - || {
        log_error "Error creando proyecto ejemplo"
        return 1
    }
apiVersion: kargo.akuity.io/v1alpha1
kind: Project
metadata:
  name: demo-project
  namespace: kargo-demo
spec:
  description: "Proyecto de demostración para Kargo"
  promotionPolicies:
  - stage: dev
    autoPromotionEnabled: true
  - stage: staging
    autoPromotionEnabled: false
  - stage: prod
    autoPromotionEnabled: false
EOF

    log_exito "Proyecto ejemplo de Kargo creado"
    log_info "Puedes ver el proyecto con: kubectl get projects -n kargo-demo"
}

# Función principal del módulo
main() {
    local accion="${1:-instalar}"
    
    case "$accion" in
        "instalar"|"install")
            instalar_kargo
            ;;
        "validar"|"validate")
            validar_kargo
            ;;
        "desinstalar"|"uninstall")
            desinstalar_kargo
            ;;
        "info"|"información")
            info_kargo
            ;;
        "ejemplo"|"demo")
            crear_proyecto_ejemplo
            ;;
        *)
            echo "Uso: $0 {instalar|validar|desinstalar|info|ejemplo}"
            echo "  instalar     - Instala Kargo"
            echo "  validar      - Valida la instalación"
            echo "  desinstalar  - Desinstala Kargo"
            echo "  info         - Muestra información del componente"
            echo "  ejemplo      - Crea un proyecto ejemplo"
            exit 1
            ;;
    esac
}

# Ejecutar función principal si el script es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
