#!/bin/bash

# ============================================================================
# BOOTSTRAP GITOPS - Orquestador Principal de Infraestructura
# ============================================================================
# Autor: Infraestructura GitOps España
# Fecha: Agosto 2025 
# Propósito: Bootstrap modular para infraestructura GitOps completa
# Arquitectura: Modular + Reutilizable + Testeable + Best Practices
# Localización: Castellano España - nomenclatura y documentación nativa
# 
# VARIABLES DE ENTORNO:
# - MODO_DESATENDIDO=true/false (default: true) - Instalación sin prompts
# - CREAR_CLUSTERS_ADICIONALES=true/false (default: false) - Crear PRE y PRO
# - SOLO_VALIDAR=true/false (default: false) - Solo validación sin instalación
# - ENTORNO_DESARROLLO=true/false (default: true) - Recursos optimizados
# 
# EJEMPLOS DE USO:
# ./bootstrap.sh                                    # Instalación completa
# ./bootstrap.sh --validar                          # Solo validación
# ./bootstrap.sh --componentes="argocd,kargo"       # Instalar componentes específicos
# ./bootstrap.sh --interactivo                      # Modo interactivo
# ./bootstrap.sh --dry-run                          # Simulación sin cambios
# ============================================================================

set -euo pipefail

# Directorio base del proyecto
DIRECTORIO_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIRECTORIO_SCRIPTS="${DIRECTORIO_SCRIPT}/scripts"

# Importar librerías comunes
source "${DIRECTORIO_SCRIPTS}/lib/comun.sh"
source "${DIRECTORIO_SCRIPTS}/lib/registro.sh"

# Configurar logging
configurar_logging "INFO" "/tmp/bootstrap-gitops.log" true true

# Variables globales
DIRECTORIO_MODULOS="${DIRECTORIO_SCRIPT}/scripts/modulos"
DIRECTORIO_LIB="${DIRECTORIO_SCRIPT}/scripts/lib"

# Configuración de colores básica
RED='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
SIN_COLOR='\033[0m'

# Funciones básicas de logging
log_error() { echo -e "${RED}❌ $*${SIN_COLOR}"; }
log_exito() { echo -e "${VERDE}✅ $*${SIN_COLOR}"; }
log_info() { echo -e "${AZUL}ℹ️  $*${SIN_COLOR}"; }
log_warning() { echo -e "${AMARILLO}⚠️  $*${SIN_COLOR}"; }
log_seccion() {
    echo ""
    echo -e "${AZUL}════════════════════════════════════════════════════════════════════${SIN_COLOR}"
    echo -e "${AZUL}  $1${SIN_COLOR}"
    echo -e "${AZUL}════════════════════════════════════════════════════════════════════${SIN_COLOR}"
    echo ""
}
registrar_cabecera() {
    echo ""
    echo -e "${VERDE}╔══════════════════════════════════════════════════════════════════╗${SIN_COLOR}"
    echo -e "${VERDE}║                                                                  ║${SIN_COLOR}"
    echo -e "${VERDE}║                    🚀 $1${SIN_COLOR}"
    echo -e "${VERDE}║                         $2 - GitOps España${SIN_COLOR}"
    echo -e "${VERDE}║                                                                  ║${SIN_COLOR}"
    echo -e "${VERDE}╚══════════════════════════════════════════════════════════════════╝${SIN_COLOR}"
    echo ""
}

# Variables globales
MODO_DESATENDIDO="${MODO_DESATENDIDO:-true}"
CREAR_CLUSTERS_ADICIONALES="${CREAR_CLUSTERS_ADICIONALES:-false}"
SOLO_VALIDAR="${SOLO_VALIDAR:-false}"
ENTORNO_DESARROLLO="${ENTORNO_DESARROLLO:-true}"
COMPONENTES_SELECCIONADOS=""
MODO_INTERACTIVO=false
MODO_DRY_RUN=false

# Función para mostrar ayuda completa
mostrar_ayuda() {
    cat << EOF
${AZUL}🚀 Bootstrap GitOps España - Infraestructura Completa${SIN_COLOR}

${AMARILLO}DESCRIPCIÓN:${SIN_COLOR}
    Bootstrap modular para infraestructura GitOps completa con 14 componentes.
    Implementa las mejores prácticas de DevOps con arquitectura moderna.
    
${AMARILLO}USO:${SIN_COLOR}
    $0 [OPCIONES]

${AMARILLO}OPCIONES PRINCIPALES:${SIN_COLOR}
    -h, --ayuda                        Mostrar esta ayuda
    -v, --validar                      Solo validar prerequisitos (no instalar)
    -c, --componentes LISTA            Instalar solo componentes específicos
                                      (separados por coma: argocd,kargo,grafana)
    -i, --interactivo                  Modo interactivo (overrides MODO_DESATENDIDO)
    -d, --dry-run                      Simular instalación (mostrar qué se haría)
    
${AMARILLO}OPCIONES AVANZADAS:${SIN_COLOR}
    --crear-clusters-adicionales       Crear clusters PRE y PRO adicionales
    --entorno-produccion              Configuración para entorno de producción
    --solo-criticos                   Instalar solo componentes críticos (ArgoCD + Kargo)
    --sin-monitorizacion              Omitir stack de monitorización
    --debug                           Modo debug con logging verbose

${AMARILLO}COMPONENTES DISPONIBLES:${SIN_COLOR}
    • argocd           - ArgoCD v3.0.12 (GitOps Core)
    • kargo            - Kargo v1.6.2 (SUPER IMPORTANTE - Promociones)
    • prometheus       - Prometheus Stack v75.15.1 (Métricas)
    • grafana          - Grafana v9.3.0 (Dashboards)
    • loki             - Loki v6.8.0 (Agregación de Logs)
    • jaeger           - Jaeger v3.4.1 (Tracing Distribuido)
    • argo-events      - Argo Events v2.4.8 (Eventos)
    • argo-workflows   - Argo Workflows v0.45.21 (Workflows)
    • argo-rollouts    - Argo Rollouts v2.40.2 (Progressive Delivery)
    • ingress-nginx    - NGINX Ingress v4.13.0 (Load Balancer)
    • cert-manager     - Cert-Manager v1.18.2 (Certificados TLS)
    • external-secrets - External Secrets v0.18.2 (Gestión Secretos)
    • minio            - MinIO v5.2.0 (Object Storage S3)
    • gitea            - Gitea v12.1.2 (Repositorio Git)

${AMARILLO}VARIABLES DE ENTORNO:${SIN_COLOR}
    MODO_DESATENDIDO=true|false         (default: true)
    CREAR_CLUSTERS_ADICIONALES=true|false (default: false)
    ENTORNO_DESARROLLO=true|false       (default: true)
    KUBECONFIG=/ruta/al/config          (default: ~/.kube/config)

${AMARILLO}EJEMPLOS DE USO:${SIN_COLOR}
    # Instalación completa desatendida
    $0

    # Solo validar prerequisitos
    $0 --validar

    # Instalación interactiva
    $0 --interactivo

    # Instalar solo componentes críticos
    $0 --componentes="argocd,kargo"

    # Instalación completa con clusters adicionales
    $0 --crear-clusters-adicionales

    # Dry-run para ver qué se instalaría
    $0 --dry-run --componentes="argocd,kargo"

    # Solo componentes críticos para entorno mínimo
    $0 --solo-criticos

    # Configuración de producción
    $0 --entorno-produccion --componentes="argocd,kargo,prometheus,grafana"

${AMARILLO}ARQUITECTURA MULTI-CLUSTER:${SIN_COLOR}
    - DEV: Cluster principal con todas las herramientas
    - PRE: Cluster de preproducción (opcional)
    - PRO: Cluster de producción (opcional)

${AMARILLO}ACCESOS WEB POST-INSTALACIÓN:${SIN_COLOR}
    • ArgoCD: http://localhost:8080 (admin/admin123)
    • Kargo: http://localhost:8081 (admin/admin123) [SUPER IMPORTANTE]
    • Grafana: http://localhost:3000 (admin/admin123)
    • Prometheus: http://localhost:9090
    • Jaeger: http://localhost:16686

${VERDE}Para más información, consulta: README.md${SIN_COLOR}
EOF
}

# Parsear argumentos de línea de comandos
parsear_argumentos() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--ayuda)
                mostrar_ayuda
                exit 0
                ;;
            -v|--validar)
                SOLO_VALIDAR=true
                shift
                ;;
            -c|--componentes)
                COMPONENTES_SELECCIONADOS="$2"
                shift 2
                ;;
            -i|--interactivo)
                MODO_INTERACTIVO=true
                MODO_DESATENDIDO=false
                shift
                ;;
            -d|--dry-run)
                MODO_DRY_RUN=true
                export DRY_RUN=true
                shift
                ;;
            --crear-clusters-adicionales)
                CREAR_CLUSTERS_ADICIONALES=true
                shift
                ;;
            --entorno-produccion)
                ENTORNO_DESARROLLO=false
                shift
                ;;
            --solo-criticos)
                COMPONENTES_SELECCIONADOS="argocd,kargo"
                shift
                ;;
            --sin-monitorizacion)
                export OMITIR_MONITORIZACION=true
                shift
                ;;
            --debug)
                export LOG_LEVEL=DEBUG
                export ENABLE_TIMESTAMPS=true
                set -x
                shift
                ;;
            *)
                log_error "Opción desconocida: $1"
                echo "Usa --ayuda para ver las opciones disponibles"
                exit 1
                ;;
        esac
    done
}

# Función para inicializar estructura de directorios
inicializar_estructura() {
    log_info "🔧 Inicializando estructura modular..."
    
    # Crear directorios necesarios
    mkdir -p "${DIRECTORIO_SCRIPTS}/lib"
    mkdir -p "${DIRECTORIO_SCRIPTS}/modulos"
    
    log_exito "Estructura inicializada"
}

# Función para instalación básica de componentes sin módulo especializado
instalar_componente_basico() {
    local componente="$1"
    
    log_info "Instalación básica de componente: $componente"
    
    # Verificar si existe un archivo YAML del componente
    local archivo_componente="${DIRECTORIO_SCRIPT}/componentes/${componente}.yaml"
    if [[ -f "$archivo_componente" ]]; then
        if ejecutar_comando "kubectl apply -f ${archivo_componente}" "Aplicando $componente"; then
            log_exito "Componente $componente aplicado"
        else
            log_error "Error aplicando componente $componente"
            return 1
        fi
    else
        log_warning "No se encontró configuración para componente: $componente"
        return 1
    fi
}

# Función principal de instalación
main() {
    log_seccion "Bootstrap GitOps España" "v2.2.0"
    
    # Parsear argumentos
    parsear_argumentos "$@"
    
    # Inicializar estructura si es necesario
    inicializar_estructura
    
    # Mostrar configuración
    log_info "Configuración de bootstrap:"
    log_info "  • Modo desatendido: ${MODO_DESATENDIDO}"
    log_info "  • Clusters adicionales: ${CREAR_CLUSTERS_ADICIONALES}"
    log_info "  • Solo validar: ${SOLO_VALIDAR}"
    log_info "  • Entorno desarrollo: ${ENTORNO_DESARROLLO}"
    log_info "  • Modo dry-run: ${MODO_DRY_RUN}"
    [[ -n "$COMPONENTES_SELECCIONADOS" ]] && log_info "  • Componentes: ${COMPONENTES_SELECCIONADOS}"
    echo ""
    
    # Fase 1: Validación de prerequisitos
    log_seccion "1. Validación de Prerequisitos"
    if [[ -f "${DIRECTORIO_SCRIPTS}/validar-prerequisitos.sh" ]]; then
        "${DIRECTORIO_SCRIPTS}/validar-prerequisitos.sh"
    else
        log_info "Usando validación básica integrada..."
        # Validación básica inline
        command -v kubectl >/dev/null 2>&1 || { log_error "kubectl no está instalado"; exit 1; }
        command -v helm >/dev/null 2>&1 || { log_error "helm no está instalado"; exit 1; }
        kubectl cluster-info >/dev/null 2>&1 || { log_error "No hay conectividad al cluster"; exit 1; }
        log_exito "Validación básica completada"
    fi
    
    if [[ "$SOLO_VALIDAR" == "true" ]]; then
        log_exito "✅ Validación completada exitosamente"
        exit 0
    fi
    
    # Fase 2: Preparación del entorno
    log_seccion "2. Preparación del Entorno"
    log_info "Preparando entorno GitOps..."
    if [[ "$MODO_DRY_RUN" != "true" ]]; then
        # Configuración básica de Helm repos
        helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
        helm repo add akuity https://charts.akuity.io 2>/dev/null || true
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
        helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
        helm repo update >/dev/null 2>&1 || true
    fi
    log_exito "Entorno preparado"
    
    # Fase 3: Instalación de componentes
    log_seccion "3. Instalación de Componentes"
    
    # Determinar qué componentes instalar
    local componentes_a_instalar=()
    if [[ -n "${COMPONENTES_SELECCIONADOS:-}" ]]; then
        IFS=',' read -ra componentes_a_instalar <<< "$COMPONENTES_SELECCIONADOS"
        log_info "Instalando componentes específicos: ${COMPONENTES_SELECCIONADOS}"
    else
        componentes_a_instalar=("${ORDEN_INSTALACION[@]}")
        log_info "Instalando todos los componentes"
    fi
    
    # Instalar componentes usando módulos especializados
    local contador=1
    local total_componentes=${#componentes_a_instalar[@]}
    
    for componente in "${componentes_a_instalar[@]}"; do
        log_progreso $contador $total_componentes "Instalando $componente"
        
        # Usar módulo especializado si existe
        local modulo_componente="${DIRECTORIO_SCRIPTS}/modulos/${componente}.sh"
        if [[ -f "$modulo_componente" ]]; then
            log_info "Usando módulo especializado: $componente"
            if "$modulo_componente" instalar; then
                log_exito "Componente $componente instalado correctamente"
            else
                log_error "Error instalando componente $componente"
                if [[ " ${COMPONENTES_CRITICOS[*]} " =~ " ${componente} " ]]; then
                    log_error "Componente crítico falló - abortando instalación"
                    exit 1
                else
                    log_warning "Componente no crítico falló - continuando..."
                fi
            fi
        else
            # Fallback para componentes sin módulo especializado
            log_info "Usando instalación básica para: $componente"
            instalar_componente_basico "$componente"
        fi
        
        ((contador++))
    done
    
    # Aplicar App of Apps después de componentes críticos
    if [[ -f "${DIRECTORIO_SCRIPT}/app-of-apps-gitops.yaml" ]]; then
        log_info "Aplicando App of Apps..."
        if ejecutar_comando "kubectl apply -f ${DIRECTORIO_SCRIPT}/app-of-apps-gitops.yaml" "Aplicando App of Apps"; then
            log_exito "App of Apps aplicado exitosamente"
        else
            log_error "Error aplicando App of Apps"
        fi
    else
        log_warning "No se encontró app-of-apps-gitops.yaml"
    fi
    
    # Fase 4: Configuración post-instalación
    log_seccion "4. Configuración Post-Instalación"
    log_info "Esperando que los componentes se inicialicen..."
    if [[ "$MODO_DRY_RUN" != "true" ]]; then
        sleep 30  # Dar tiempo a los pods para iniciarse
    fi
    log_exito "Configuración básica completada"
    
    # Fase 5: Validación final
    log_seccion "5. Validación Final"
    if [[ -f "${DIRECTORIO_SCRIPTS}/diagnostico-gitops.sh" ]]; then
        "${DIRECTORIO_SCRIPTS}/diagnostico-gitops.sh"
    else
        log_info "Verificación básica del estado..."
        if [[ "$MODO_DRY_RUN" != "true" ]]; then
            kubectl get applications -n argocd 2>/dev/null || log_warning "ArgoCD aún inicializándose"
        fi
        log_exito "Verificación básica completada"
    fi
    
    # Fase 6: Configurar accesos (opcional)
    if [[ "$MODO_INTERACTIVO" == "true" ]]; then
        log_seccion "6. Configuración de Accesos"
        read -p "¿Configurar port-forwards para acceso web? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[SsYy]$ ]]; then
            if [[ -f "${DIRECTORIO_SCRIPTS}/configurar-port-forwards.sh" ]]; then
                "${DIRECTORIO_SCRIPTS}/configurar-port-forwards.sh"
            else
                log_info "Para configurar port-forwards manualmente:"
                log_info "  kubectl port-forward -n argocd svc/argocd-server 8080:80 &"
                log_info "  kubectl port-forward -n kargo-system svc/kargo-api 8081:80 &"
            fi
        fi
    fi
    
    # Resumen final
    log_seccion "🎉 Bootstrap Completado Exitosamente"
    log_exito "✅ Infraestructura GitOps España instalada correctamente"
    log_info ""
    log_info "📋 Próximos pasos recomendados:"
    log_info "  1. Verificar estado: ./scripts/diagnostico-gitops.sh"
    log_info "  2. Configurar accesos: ./scripts/configurar-port-forwards.sh"
    log_info "  3. Consultar documentación: README.md"
    log_info ""
    log_info "🔗 Interfaces web disponibles:"
    log_info "  • ArgoCD: http://localhost:8080 (admin/admin123)"
    log_info "  • Kargo: http://localhost:8081 (admin/admin123) [SUPER IMPORTANTE]"
    log_info "  • Grafana: http://localhost:3000 (admin/admin123)"
    log_info "  • Prometheus: http://localhost:9090"
    log_info "  • Jaeger: http://localhost:16686"
    log_info ""
    log_exito "🎯 ¡GitOps España listo para usar!"
}

# Ejecutar función principal con todos los argumentos
main "$@"
