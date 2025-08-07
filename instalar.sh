#!/bin/bash

# ============================================================================
# INSTALADOR PRINCIPAL MODULAR - GitOps en Español Infrastructure (Versión 3.0.0)
# ============================================================================
# Instalador principal optimizado y modular para infraestructura GitOps
# Orquestador inteligente con arquitectura por fases autocontenidas
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar PROJECT_ROOT automáticamente
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

# Cargar autocontención
if [[ -f "$PROJECT_ROOT/scripts/comun/autocontener.sh" ]]; then
    # shellcheck source=scripts/comun/autocontener.sh
    source "$PROJECT_ROOT/scripts/comun/autocontener.sh"
else
    echo "❌ Error: No se pudo cargar el módulo de autocontención" >&2
    echo "   Asegúrate de que la estructura del proyecto sea correcta" >&2
    exit 1
fi

# ============================================================================
# FUNCIONES ESPECÍFICAS DEL INSTALADOR
# ============================================================================

# Cargar todos los módulos de fases
cargar_modulos_fases() {
    log_info "📂 Cargando módulos por fases..."
    
    for fase in "${FASES_DISPONIBLES[@]}"; do
        local fase_path="$FASES_DIR/$fase"
        
        if [[ -f "$fase_path" ]]; then
            # shellcheck source=/dev/null
            source "$fase_path"
            log_debug "✅ Módulo cargado: $fase"
        else
            log_error "❌ Módulo de fase no encontrado: $fase_path"
            return 1
        fi
    done
    
    log_success "✅ Todos los módulos de fases cargados correctamente"
}
export TIMEOUT_DELETE="${TIMEOUT_DELETE:-120}"

# ============================================================================
# CARGA DE MÓDULOS POR FASES
# ============================================================================

# Lista de fases en orden de ejecución
readonly FASES=(
    "fase-01-permisos.sh"
    "fase-02-dependencias.sh"
    "fase-03-clusters.sh"
    "fase-04-argocd.sh"
    "fase-05-herramientas.sh"
    "fase-06-aplicaciones.sh"
    "fase-07-finalizacion.sh"
)

# Cargar todos los módulos de fases
cargar_modulos_fases() {
    log_info "📂 Cargando módulos por fases..."
    
    for fase in "${FASES[@]}"; do
        local fase_path="$FASES_DIR/$fase"
        
        if [[ -f "$fase_path" ]]; then
            # shellcheck source=/dev/null
            source "$fase_path"
            log_debug "✅ Módulo cargado: $fase"
        else
            log_error "❌ Módulo de fase no encontrado: $fase_path"
            return 1
        fi
    done
    
    log_success "✅ Todos los módulos de fases cargados correctamente"
}

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

# Verificar si está en modo dry-run
es_dry_run() {
    [[ "$DRY_RUN" == "true" ]]
}

# Configurar modo de instalación
configurar_modo_instalacion() {
    # PROCESO DESATENDIDO ÚNICO - no hay modos
    export INSTALLATION_MODE="gitops-absoluto"
    export PROCESO_DESATENDIDO="true"
    
    log_info "🚀 Configurado para PROCESO DESATENDIDO - Entorno GitOps Absoluto"
    log_info "📋 Fases: Permisos → Deps → Clusters → ArgoCD → Tools → Apps → Finalización"
}

# Configurar modo de fase individual
configurar_modo_fase_individual() {
    local fase="$1"
    export INSTALLATION_MODE="fase-individual"
    export FASE_OBJETIVO="$fase"
    export PROCESO_DESATENDIDO="false"
    
    local fase_nombre
    case "$fase" in
        "01") fase_nombre="Gestión de Permisos" ;;
        "02") fase_nombre="Dependencias del Sistema" ;;
        "03") fase_nombre="Docker y Clusters" ;;
        "04") fase_nombre="Instalación ArgoCD" ;;
        "05") fase_nombre="Herramientas GitOps" ;;
        "06") fase_nombre="Aplicaciones Custom" ;;
        "07") fase_nombre="Finalización y Accesos" ;;
        *) fase_nombre="Desconocida" ;;
    esac
    
    log_info "🎯 Configurado para FASE INDIVIDUAL: $fase - $fase_nombre"
}

# Configurar modo de rango de fases
configurar_modo_rango_fases() {
    local rango="$1"
    export INSTALLATION_MODE="rango-fases"
    export RANGO_FASES="$rango"
    export PROCESO_DESATENDIDO="false"
    
    local inicio="${rango%-*}"
    local fin="${rango#*-}"
    
    log_info "🔄 Configurado para RANGO DE FASES: $inicio hasta $fin"
    log_info "📋 Se ejecutarán las fases: $inicio, $((inicio+1)), ..., $fin"
}

# Configurar logging avanzado
configurar_logging_instalador() {
    local nivel="${LOG_LEVEL:-INFO}"
    local archivo="${LOG_FILE:-${PROJECT_ROOT}/logs/instalador-$(date +%Y%m%d-%H%M%S).log}"
    
    # Crear directorio de logs si no existe
    mkdir -p "${PROJECT_ROOT}/logs"
    
    # Configurar variables de entorno para logging
    export LOG_LEVEL="$nivel"
    export LOG_FILE="$archivo"
    
    # Configurar debug si está habilitado
    if [[ "$DEBUG" == "true" ]]; then
        set -x
        export LOG_LEVEL="DEBUG"
    fi
    
    # Configurar verbose
    if [[ "$VERBOSE" == "true" ]]; then
        export LOG_LEVEL="DEBUG"
        export SHOW_TIMESTAMP="true"
    fi
}

# ============================================================================
# FUNCIONES DE AYUDA Y BANNER
# ============================================================================

# Mostrar ayuda completa
mostrar_ayuda() {
    cat << 'EOF'
GitOps en Español Infrastructure - Instalador Principal Modular v3.0.0

SINTAXIS:
  ./instalar.sh [FASE] [OPCIONES]

🚀 PROCESO AUTOMÁTICO COMPLETO:
  ./instalar.sh                    # Entorno GitOps absoluto desde Ubuntu WSL limpio

🎯 EJECUCIÓN POR FASES INDIVIDUALES:
  ./instalar.sh fase-01            # Solo gestión inteligente de permisos
  ./instalar.sh fase-02            # Solo verificar/actualizar dependencias
  ./instalar.sh fase-03            # Solo configurar Docker + clusters
  ./instalar.sh fase-04            # Solo instalar ArgoCD
  ./instalar.sh fase-05            # Solo desplegar herramientas GitOps
  ./instalar.sh fase-06            # Solo desplegar aplicaciones custom
  ./instalar.sh fase-07            # Solo finalización + accesos
  
🔄 RANGOS DE FASES:
  ./instalar.sh fase-01-03         # Ejecutar desde fase 1 hasta 3
  ./instalar.sh fase-04-07         # Ejecutar desde fase 4 hasta 7

FASES DEL PROCESO DESATENDIDO:
  1. Gestión inteligente de permisos (auto-escalation/de-escalation)
  2. Verificar/actualizar dependencias del sistema (últimas versiones)
  3. Configurar Docker + cluster gitops-dev (capacidad completa)
  4. Instalar ArgoCD (última versión, controlará todos los clusters)
  5. Actualizar helm-charts y desplegar herramientas GitOps
  6. Desplegar aplicaciones custom con integración completa
  7. Crear clusters gitops-pre y gitops-pro + mostrar accesos

RESULTADO: Entorno GitOps absoluto con 3 clusters completamente funcional

OPCIONES DE DEBUG/TESTING:
  --dry-run               Mostrar qué se haría sin ejecutar comandos
  --verbose               Salida detallada y debug  
  --debug                 Modo debug completo (muy detallado)
  --skip-deps             Saltar verificación de dependencias (solo testing)
  --solo-dev              Solo crear cluster gitops-dev (testing)

CONFIGURACIÓN AVANZADA:
  --timeout SEGUNDOS      Timeout para operaciones (por defecto: 600)
  --log-level NIVEL       Nivel de log: ERROR, WARNING, INFO, DEBUG, TRACE
  --log-file ARCHIVO      Archivo de log personalizado

ARQUITECTURA MODULAR:
  scripts/fases/fase-01-permisos.sh      - Gestión inteligente de permisos
  scripts/fases/fase-02-dependencias.sh  - Dependencias del sistema
  scripts/fases/fase-03-clusters.sh      - Docker y clusters Kubernetes
  scripts/fases/fase-04-argocd.sh        - Instalación de ArgoCD
  scripts/fases/fase-05-herramientas.sh  - Herramientas GitOps
  scripts/fases/fase-06-aplicaciones.sh  - Aplicaciones custom
  scripts/fases/fase-07-finalizacion.sh  - Información final y accesos

EJEMPLOS DE USO:
  ./instalar.sh                                # Proceso completo desatendido
  ./instalar.sh --dry-run                      # Ver todo el proceso sin ejecutar
  ./instalar.sh fase-03 --verbose              # Solo crear clusters con detalle
  ./instalar.sh fase-01-04 --debug            # Fases 1-4 con debug completo
  ./instalar.sh fase-05 --log-file custom.log # Solo herramientas con log custom

INFORMACIÓN:
  Repositorio: https://github.com/andres20980/gh-gitops-infra
  Documentación: README.md
  Versión: 3.0.0 (Arquitectura Modular)
EOF
}

# Mostrar banner inicial mejorado
mostrar_banner_inicial() {
    clear
    log_section "🚀 GitOps en Español - Instalador Modular v${GITOPS_VERSION}"
    
    # Información adicional del sistema
    log_info "Sistema: $(uname -s) $(uname -m)"
    log_info "Usuario: $(whoami)"
    if es_wsl; then
        log_info "Entorno: WSL detectado"
    fi
    echo
}

# ============================================================================
# PROCESAMIENTO DE ARGUMENTOS AVANZADO
# ============================================================================

# Procesar argumentos de línea de comandos
procesar_argumentos() {
    # Variables para control de fases
    local fase_especifica=""
    local rango_fases=""
    
    # Si no hay argumentos, usar proceso desatendido
    if [[ $# -eq 0 ]]; then
        configurar_modo_instalacion
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            # Fases individuales
            fase-01|fase-1|f01|f1|permisos)
                fase_especifica="01"
                shift
                ;;
            fase-02|fase-2|f02|f2|dependencias)
                fase_especifica="02"
                shift
                ;;
            fase-03|fase-3|f03|f3|clusters)
                fase_especifica="03"
                shift
                ;;
            fase-04|fase-4|f04|f4|argocd)
                fase_especifica="04"
                shift
                ;;
            fase-05|fase-5|f05|f5|herramientas)
                fase_especifica="05"
                shift
                ;;
            fase-06|fase-6|f06|f6|aplicaciones)
                fase_especifica="06"
                shift
                ;;
            fase-07|fase-7|f07|f7|finalizacion)
                fase_especifica="07"
                shift
                ;;
            
            # Rangos de fases
            fase-01-03|fase-1-3|f01-03|f1-3)
                rango_fases="01-03"
                shift
                ;;
            fase-01-04|fase-1-4|f01-04|f1-4)
                rango_fases="01-04"
                shift
                ;;
            fase-04-07|fase-4-7|f04-07|f4-7)
                rango_fases="04-07"
                shift
                ;;
            fase-05-07|fase-5-7|f05-07|f5-7)
                rango_fases="05-07"
                shift
                ;;
            
            # Opciones de debug/testing
            --dry-run)
                DRY_RUN="true"
                export DRY_RUN
                shift
                ;;
            --verbose)
                VERBOSE="true"
                export VERBOSE
                shift
                ;;
            --debug)
                DEBUG="true"
                VERBOSE="true"
                export DEBUG VERBOSE
                shift
                ;;
            --skip-deps)
                SKIP_DEPS="true"
                export SKIP_DEPS
                shift
                ;;
            --solo-dev)
                SOLO_DEV="true"
                export SOLO_DEV
                shift
                ;;
            
            # Configuración
            --timeout)
                TIMEOUT_INSTALL="$2"
                export TIMEOUT_INSTALL
                shift 2
                ;;
            --log-level)
                LOG_LEVEL="$2"
                export LOG_LEVEL
                shift 2
                ;;
            --log-file)
                LOG_FILE="$2"
                export LOG_FILE
                shift 2
                ;;
            
            # Ayuda
            --ayuda|--help|-h)
                mostrar_ayuda
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME v$GITOPS_VERSION"
                exit 0
                ;;
            
            # Opciones desconocidas
            *)
                log_error "Opción desconocida: $1"
                log_info "Usa --ayuda para ver las opciones disponibles"
                exit 1
                ;;
        esac
    done
    
    # Configurar modo de instalación según parámetros
    if [[ -n "$fase_especifica" ]]; then
        configurar_modo_fase_individual "$fase_especifica"
    elif [[ -n "$rango_fases" ]]; then
        configurar_modo_rango_fases "$rango_fases"
    else
        configurar_modo_instalacion
    fi
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

# Función principal optimizada
main() {
    # Procesar argumentos primero (para configurar logging)
    procesar_argumentos "$@"
    
    # Configurar logging con parámetros procesados
    configurar_logging_instalador
    
    # Cargar módulos de fases
    if ! cargar_modulos_fases; then
        log_error "Error cargando módulos de fases"
        exit 1
    fi
    
    # Mostrar banner inicial
    mostrar_banner_inicial
    
    # Ejecutar según el modo configurado
    case "$INSTALLATION_MODE" in
        "fase-individual")
            ejecutar_fase_individual "$FASE_OBJETIVO"
            ;;
        "rango-fases")
            ejecutar_rango_fases "$RANGO_FASES"
            ;;
        "gitops-absoluto"|*)
            ejecutar_proceso_completo
            ;;
    esac
    
    return 0
}

# Ejecutar una fase individual
ejecutar_fase_individual() {
    local fase="$1"
    
    log_section "🎯 EJECUCIÓN FASE INDIVIDUAL: $fase"
    log_info "Modo: Fase Individual"
    log_info "Dry-run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "Log file: $LOG_FILE"
    fi
    echo
    
    # Validar dependencias de fase
    if ! validar_dependencia_fase "$fase"; then
        return 1
    fi
    
    # Mostrar información de la fase
    mostrar_info_fase "$fase"
    echo
    
    case "$fase" in
        "01")
            iniciar_fase "01" "🔐 FASE 1: Gestión Inteligente de Permisos" "1-2min"
            gestionar_permisos_inteligente "dependencias"
            marcar_fase_completada "01"
            finalizar_fase "Permisos configurados correctamente"
            ;;
        "02")
            iniciar_fase "02" "📦 FASE 2: Verificar/Actualizar Dependencias del Sistema" "2-3min"
            if [[ "$SKIP_DEPS" == "false" ]]; then
                ejecutar_instalacion_dependencias
            else
                verificar_dependencias_criticas
            fi
            marcar_fase_completada "02"
            finalizar_fase "Dependencias procesadas"
            ;;
        "03")
            iniciar_fase "03" "🐳 FASE 3: Configurar Docker y Crear Cluster gitops-dev" "3-5min"
            configurar_docker_automatico
            crear_cluster_gitops_dev
            marcar_fase_completada "03"
            finalizar_fase "Cluster $CLUSTER_DEV_NAME creado"
            ;;
        "04")
            iniciar_fase "04" "🔄 FASE 4: Instalar ArgoCD" "1-2min"
            fase_04_argocd
            marcar_fase_completada "04"
            finalizar_fase "ArgoCD instalado y configurado"
            ;;
        "05")
            iniciar_fase "05" "📊 FASE 5: Desplegar Herramientas GitOps" "5-7min"
            fase_05_herramientas
            marcar_fase_completada "05"
            finalizar_fase "Herramientas GitOps desplegadas"
            ;;
        "06")
            iniciar_fase "06" "🚀 FASE 6: Desplegar Aplicaciones Custom" "3-4min"
            desplegar_aplicaciones_custom
            marcar_fase_completada "06"
            finalizar_fase "Aplicaciones custom desplegadas"
            ;;
        "07")
            iniciar_fase "07" "🌐 FASE 7: Finalización y Accesos" "2-3min"
            crear_clusters_promocion
            mostrar_resumen_final
            marcar_fase_completada "07"
            finalizar_fase "Proceso finalizado"
            ;;
        *)
            log_error "❌ Fase no reconocida: $fase"
            return 1
            ;;
    esac
}

# Ejecutar un rango de fases
ejecutar_rango_fases() {
    local rango="$1"
    local inicio="${rango%-*}"
    local fin="${rango#*-}"
    
    log_section "🔄 EJECUCIÓN RANGO DE FASES: $inicio-$fin"
    log_info "Modo: Rango de Fases"
    log_info "Dry-run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "Log file: $LOG_FILE"
    fi
    echo
    
    # Validar rango
    if [[ $inicio -lt 1 || $inicio -gt 7 || $fin -lt 1 || $fin -gt 7 || $inicio -gt $fin ]]; then
        log_error "❌ Rango de fases inválido: $inicio-$fin"
        return 1
    fi
    
    # Ejecutar fases en secuencia
    for ((fase_num=inicio; fase_num<=fin; fase_num++)); do
        local fase_str=$(printf "%02d" $fase_num)
        ejecutar_fase_individual "$fase_str"
        
        if [[ $? -ne 0 ]]; then
            log_error "❌ Error en fase $fase_str, deteniendo ejecución"
            return 1
        fi
    done
    
    log_success "🎉 Rango de fases $inicio-$fin completado exitosamente"
}

# Mostrar resumen de accesos a herramientas GitOps
mostrar_resumen_accesos_herramientas() {
    log_section "🌐 RESUMEN DE ACCESOS A HERRAMIENTAS GITOPS"
    
    echo "🎛️ TODAS LAS HERRAMIENTAS GITOPS ESTÁN LISTAS Y ACCESIBLES:"
    echo "================================================================================"
    echo
    echo "🔧 INFRAESTRUCTURA BÁSICA:"
    echo "  • ArgoCD (GitOps Controller)    : http://localhost:8080"
    echo "    📝 Usuario: admin | Password: Ver en instalación ArgoCD"
    echo "  • Cert-Manager (TLS Automático) : Sin UI (funciona automáticamente)"
    echo "  • Ingress-NGINX (Load Balancer) : Sin UI específica"
    echo
    echo "📊 OBSERVABILIDAD Y MONITOREO:"
    echo "  • Grafana (Dashboards)          : http://localhost:8081"
    echo "    📝 Usuario: admin | Password: prom-operator"
    echo "  • Prometheus (Métricas)         : http://localhost:8082"
    echo "  • AlertManager (Alertas)        : http://localhost:8083"
    echo "  • Jaeger (Distributed Tracing)  : http://localhost:8084"
    echo "  • Loki (Log Aggregation)        : http://localhost:8086"
    echo
    echo "🚀 HERRAMIENTAS GITOPS AVANZADAS:"
    echo "  • Argo Workflows (CI/CD)        : http://localhost:8089"
    echo "  • Argo Events (Event-driven)    : http://localhost:8090"
    echo "  • Argo Rollouts (Deploy Avanz.) : http://localhost:8091"
    echo "  • Kargo (Environment Promotion) : http://localhost:8085"
    echo
    echo "📦 ALMACENAMIENTO Y DESARROLLO:"
    echo "  • MinIO (S3 Compatible Storage) : http://localhost:8087"
    echo "    📝 Usuario: minioadmin | Password: minioadmin"
    echo "  • Gitea (Git Server Local)      : http://localhost:8088"
    echo "    📝 Usuario: gitea | Password: gitea"
    echo
    echo "================================================================================"
    echo "💡 COMANDOS ÚTILES:"
    echo "  • Ver estado accesos : ./scripts/accesos-herramientas.sh status"
    echo "  • Iniciar accesos    : ./scripts/accesos-herramientas.sh start"
    echo "  • Parar accesos      : ./scripts/accesos-herramientas.sh stop"
    echo "  • Listar herramientas: ./scripts/accesos-herramientas.sh list"
    echo "================================================================================"
    echo
    
    if [[ "$PROCESO_DESATENDIDO" != "true" ]]; then
        log_info "⏸️ PAUSA ANTES DE CONTINUAR CON APLICACIONES"
        log_info "Puedes revisar las herramientas antes de desplegar aplicaciones."
        log_info "Presiona ENTER para continuar con la Fase 6 o Ctrl+C para pausar."
        read -r
    else
        log_info "⏭️ Continuando automáticamente con la Fase 6 en 10 segundos..."
        log_info "💡 Puedes acceder a las herramientas en cualquier momento usando los enlaces de arriba"
        sleep 10
    fi
}

# Ejecutar proceso completo (modo original)
ejecutar_proceso_completo() {
    log_section "⚙️ Configuración del Proceso GitOps Absoluto Modular"
    log_info "Versión: $GITOPS_VERSION (Arquitectura Modular)"
    log_info "Modo: PROCESO DESATENDIDO (Entorno GitOps Absoluto)"
    log_info "Clusters a crear:"
    log_info "  • $CLUSTER_DEV_NAME: ${CLUSTER_DEV_CPUS} CPUs, ${CLUSTER_DEV_MEMORY}MB RAM, ${CLUSTER_DEV_DISK} disk"
    if [[ "$SOLO_DEV" != "true" ]]; then
        log_info "  • $CLUSTER_PRE_NAME: ${CLUSTER_PRE_CPUS} CPUs, ${CLUSTER_PRE_MEMORY}MB RAM, ${CLUSTER_PRE_DISK} disk"
        log_info "  • $CLUSTER_PRO_NAME: ${CLUSTER_PRO_CPUS} CPUs, ${CLUSTER_PRO_MEMORY}MB RAM, ${CLUSTER_PRO_DISK} disk"
    fi
    log_info "Proveedor: $CLUSTER_PROVIDER"
    log_info "Proceso desatendido: $PROCESO_DESATENDIDO"
    log_info "Skip dependencias: $SKIP_DEPS"
    log_info "Solo DEV: $SOLO_DEV"
    log_info "Dry-run: $DRY_RUN"
    log_info "Verbose: $VERBOSE"
    log_info "Debug: $DEBUG"
    if [[ -n "${LOG_FILE:-}" ]]; then
        log_info "Log file: $LOG_FILE"
    fi
    echo
    
    # ========================================================================
    # FASE 1: GESTIÓN INTELIGENTE DE PERMISOS
    # ========================================================================
    log_section "🔐 FASE 1: Gestión Inteligente de Permisos"
    if [[ "$SKIP_DEPS" == "false" ]]; then
        gestionar_permisos_inteligente "dependencias"
    else
        gestionar_permisos_inteligente "clusters"
    fi
    log_success "✅ FASE 1 completada: Permisos configurados correctamente"
    
    # ========================================================================
    # FASE 2: VERIFICAR/ACTUALIZAR DEPENDENCIAS DEL SISTEMA
    # ========================================================================
    if [[ "$SKIP_DEPS" == "false" ]]; then
        log_section "📦 FASE 2: Verificar/Actualizar Dependencias del Sistema"
        if ! ejecutar_instalacion_dependencias; then
            log_error "Error en la verificación/actualización de dependencias"
            exit 1
        fi
        log_success "✅ FASE 2 completada: Dependencias actualizadas"
        
        # Si estamos como root después de instalar dependencias, cambiar a usuario normal para clusters
        if [[ "$EUID" -eq 0 ]]; then
            gestionar_permisos_inteligente "clusters"
        fi
    else
        log_section "📦 FASE 2: Verificar Dependencias Críticas (--skip-deps)"
        if ! verificar_dependencias_criticas; then
            log_error "Faltan dependencias críticas"
            exit 1
        fi
        log_success "✅ FASE 2 completada: Dependencias verificadas"
    fi
    
    # ========================================================================
    # FASE 3: CONFIGURAR DOCKER Y CREAR CLUSTER GITOPS-DEV
    # ========================================================================
    log_section "🐳 FASE 3: Configurar Docker y Crear Cluster gitops-dev"
    
    # Configurar Docker automáticamente
    if ! configurar_docker_automatico; then
        log_error "Docker no está disponible y es requerido para $CLUSTER_PROVIDER"
        exit 1
    fi
    
    # Crear cluster gitops-dev con capacidad completa
    if ! crear_cluster_gitops_dev; then
        log_error "Error creando cluster $CLUSTER_DEV_NAME"
        exit 1
    fi
    log_success "✅ FASE 3 completada: Cluster $CLUSTER_DEV_NAME creado y configurado"
    
    # Si solo queremos DEV, parar aquí
    if [[ "$SOLO_DEV" == "true" ]]; then
        log_success "🎯 Proceso completado: Solo cluster DEV creado (--solo-dev)"
        mostrar_accesos_sistema
        return 0
    fi
    
    # ========================================================================
    # FASE 4: INSTALAR ARGOCD (ÚLTIMA VERSIÓN)
    # ========================================================================
    iniciar_fase "04" "🔄 FASE 4: Instalar ArgoCD (Controlará todos los clusters)" "1-2min"
    if ! fase_04_argocd; then
        log_error "Error en Fase 4: ArgoCD"
        exit 1
    fi
    finalizar_fase "ArgoCD instalado y configurado"
    
    # ========================================================================
    # FASE 5: OPTIMIZAR Y DESPLEGAR HERRAMIENTAS GITOPS
    # ========================================================================
    iniciar_fase "05" "📊 FASE 5: Optimizar Configuraciones y Desplegar Herramientas GitOps" "5-7min"
    if ! instalar_herramientas_gitops; then
        log_error "Error desplegando herramientas GitOps"
        exit 1
    fi
    finalizar_fase "Herramientas optimizadas y desplegadas"
    
    # ========================================================================
    # PAUSA INFORMATIVA: ACCESOS A HERRAMIENTAS GITOPS
    # ========================================================================
    if [[ "$SKIP_INTERACTIVE" != "true" ]]; then
        mostrar_resumen_accesos_herramientas
    fi
    
    # ========================================================================
    # FASE 6: DESPLEGAR APLICACIONES CUSTOM
    # ========================================================================
    iniciar_fase "06" "🚀 FASE 6: Desplegar Aplicaciones Custom" "3-4min"
    if ! desplegar_aplicaciones_custom; then
        log_error "Error desplegando aplicaciones custom"
        exit 1
    fi
    finalizar_fase "Aplicaciones custom desplegadas"
    
    # ========================================================================
    # FASE 7: CREAR CLUSTERS DE PROMOCIÓN Y MOSTRAR INFORMACIÓN FINAL
    # ========================================================================
    log_section "🌐 FASE 7: Crear Clusters de Promoción y Finalización"
    if ! crear_clusters_promocion; then
        log_error "Error creando clusters de promoción"
        exit 1
    fi
    
    # Mostrar información final
    mostrar_resumen_final
    log_success "✅ FASE 7 completada: Clusters de promoción creados"
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Ejecutar función principal con manejo de errores
if ! main "$@"; then
    log_error "Instalación falló"
    exit 1
fi
