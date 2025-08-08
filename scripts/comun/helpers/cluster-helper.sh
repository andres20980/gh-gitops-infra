#!/bin/bash

# ============================================================================
# CLUSTER HELPER - Gestión optimizada de clusters GitOps
# ============================================================================
# Funciones especializadas para creación eficiente de clusters
# Principios: DRY, cache inteligente, verificación previa, reutilización
# ============================================================================

set -euo pipefail

# ============================================================================
# VARIABLES DE OPTIMIZACIÓN
# ============================================================================

# Cache de imágenes y configuraciones
readonly CLUSTER_CACHE_DIR="/tmp/gitops-cluster-cache"
readonly K8S_VERSION="${K8S_VERSION:-v1.31.0}"
readonly DOCKER_DRIVER="docker"

# Estados de clusters
declare -A CLUSTER_STATUS=()

# ============================================================================
# VERIFICACIÓN Y ANÁLISIS INTELIGENTE
# ============================================================================

# Verifica si un cluster ya existe y está funcional
verificar_cluster_existente() {
    local cluster_name="$1"
    
    # Verificar si el perfil existe
    if ! minikube profile list -o json 2>/dev/null | jq -r '.[].Name' | grep -q "^${cluster_name}$"; then
        CLUSTER_STATUS["$cluster_name"]="no_existe"
        return 1
    fi
    
    # Verificar estado del cluster
    local status
    status=$(minikube status --profile="$cluster_name" --format='{{.Host}}' 2>/dev/null || echo "")
    
    case "$status" in
        "Running")
            # Verificar conectividad kubectl
            if kubectl --context="$cluster_name" get nodes >/dev/null 2>&1; then
                CLUSTER_STATUS["$cluster_name"]="funcional"
                echo "funcional"
                return 0
            else
                CLUSTER_STATUS["$cluster_name"]="corrupto"
                echo "corrupto"
                return 1
            fi
            ;;
        "Stopped")
            CLUSTER_STATUS["$cluster_name"]="detenido"
            echo "detenido"
            return 1
            ;;
        *)
            CLUSTER_STATUS["$cluster_name"]="desconocido"
            echo "desconocido"
            return 1
            ;;
    esac
}

# Verifica si las imágenes de Kubernetes ya están en cache
verificar_cache_imagenes() {
    # Verificar si Docker tiene las imágenes base
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "registry.k8s.io.*$K8S_VERSION"; then
        echo "cache_disponible"
        return 0
    else
        echo "cache_vacio"
        return 1
    fi
}

# Analiza recursos del sistema antes de crear clusters
analizar_recursos_sistema() {
    local memoria_total
    local cpu_cores
    local disk_space
    
    # Memoria disponible (en MB)
    memoria_total=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    
    # CPU cores
    cpu_cores=$(nproc)
    
    # Espacio en disco (en GB)
    disk_space=$(df / | awk 'NR==2{printf "%.0f", $4/1024/1024}')
    
    echo "memoria:$memoria_total cpu:$cpu_cores disk:$disk_space"
}

# ============================================================================
# OPTIMIZACIÓN DE CREACIÓN
# ============================================================================

# Pre-descarga imágenes de Kubernetes para reutilización
pre_descargar_imagenes_k8s() {
    local version="${1:-$K8S_VERSION}"
    
    echo "🚀 Optimizando: Pre-descarga de imágenes Kubernetes $version"
    
    # Crear directorio de cache
    mkdir -p "$CLUSTER_CACHE_DIR"
    
    # Verificar si ya están descargadas
    if [[ "$(verificar_cache_imagenes)" == "cache_disponible" ]]; then
        echo "   ✅ Imágenes ya disponibles en cache Docker"
        return 0
    fi
    
    # Pre-descargar usando minikube cache
    echo "   📦 Descargando imágenes base (se reutilizarán para todos los clusters)..."
    
    # Usar un cluster temporal para pre-cargar imágenes
    local temp_cluster="gitops-cache-temp"
    
    if minikube start \
        --profile="$temp_cluster" \
        --cpus=1 \
        --memory=1024 \
        --disk-size=10g \
        --driver="$DOCKER_DRIVER" \
        --kubernetes-version="$version" \
        --download-only 2>/dev/null; then
        
        echo "   ✅ Imágenes pre-descargadas exitosamente"
        
        # Eliminar cluster temporal
        minikube delete --profile="$temp_cluster" >/dev/null 2>&1 || true
        
        return 0
    else
        echo "   ⚠️  Pre-descarga falló, continuando con descarga individual"
        return 1
    fi
}

# Crea un cluster optimizado reutilizando cache
crear_cluster_optimizado() {
    local cluster_name="$1"
    local cpus="$2"
    local memory="$3"
    local disk="$4"
    local addons="${5:-metrics-server,ingress}"
    
    echo "🏗️  Creando cluster optimizado: $cluster_name"
    
    # Verificar si ya existe y es funcional
    local estado
    estado=$(verificar_cluster_existente "$cluster_name" 2>/dev/null || echo "no_existe")
    
    case "$estado" in
        "funcional")
            echo "   ✅ Cluster $cluster_name ya existe y es funcional"
            kubectl config use-context "$cluster_name"
            return 0
            ;;
        "detenido")
            echo "   🔄 Cluster $cluster_name existe pero está detenido, iniciando..."
            if minikube start --profile="$cluster_name"; then
                echo "   ✅ Cluster $cluster_name reiniciado"
                kubectl config use-context "$cluster_name"
                return 0
            else
                echo "   ⚠️  Error reiniciando, recreando cluster..."
                minikube delete --profile="$cluster_name" >/dev/null 2>&1 || true
            fi
            ;;
        "corrupto")
            echo "   🔧 Cluster $cluster_name corrupto, recreando..."
            minikube delete --profile="$cluster_name" >/dev/null 2>&1 || true
            ;;
    esac
    
    # Crear cluster nuevo con configuración optimizada
    echo "   📦 Creando nuevo cluster (reutilizando imágenes cache)..."
    
    local start_args=(
        "--profile=$cluster_name"
        "--cpus=$cpus"
        "--memory=$memory"
        "--disk-size=$disk"
        "--driver=$DOCKER_DRIVER"
        "--kubernetes-version=$K8S_VERSION"
        "--cache-images=true"  # Reutilizar cache
        "--delete-on-failure"  # Auto-limpieza en caso de error
    )
    
    if minikube start "${start_args[@]}"; then
        echo "   ✅ Cluster $cluster_name creado exitosamente"
        
        # Configurar addons de forma eficiente
        if [[ -n "$addons" ]]; then
            echo "   🔧 Configurando addons: $addons"
            IFS=',' read -ra addon_list <<< "$addons"
            for addon in "${addon_list[@]}"; do
                minikube addons enable "$addon" --profile="$cluster_name" &
            done
            wait  # Esperar que todos los addons se configuren en paralelo
        fi
        
        # Establecer contexto
        kubectl config use-context "$cluster_name"
        
        CLUSTER_STATUS["$cluster_name"]="funcional"
        return 0
    else
        echo "   ❌ Error creando cluster $cluster_name"
        CLUSTER_STATUS["$cluster_name"]="error"
        return 1
    fi
}

# ============================================================================
# GESTIÓN MULTI-CLUSTER OPTIMIZADA
# ============================================================================

# Crea todos los clusters de forma optimizada
crear_entorno_gitops_completo() {
    local solo_dev="${1:-false}"
    
    echo "🌐 Creando entorno GitOps completo con optimización de cache"
    
    # Paso 1: Analizar recursos del sistema
    local recursos
    recursos=$(analizar_recursos_sistema)
    echo "📊 Recursos del sistema: $recursos"
    
    # Paso 2: Pre-optimización de imágenes
    if ! pre_descargar_imagenes_k8s; then
        echo "⚠️  Pre-descarga falló, continuando con método tradicional"
    fi
    
    # Paso 3: Crear cluster principal (DEV) con recursos optimizados
    echo "🎯 Creando cluster principal: gitops-dev"
    if ! crear_cluster_optimizado "gitops-dev" "4" "4096" "40g" "metrics-server,ingress,dashboard"; then
        echo "❌ Error crítico: No se pudo crear cluster principal"
        return 1
    fi
    
    # Paso 4: Verificar que DEV es funcional antes de continuar
    if ! kubectl get nodes >/dev/null 2>&1; then
        echo "❌ Cluster DEV no es funcional"
        return 1
    fi
    
    echo "✅ Cluster gitops-dev funcional y listo"
    
    # Paso 5: Crear clusters adicionales solo si no es solo-dev
    if [[ "$solo_dev" != "true" ]]; then
        echo "🔄 Creando clusters de promoción..."
        
        # Crear PRE y PRO en paralelo (reutilizan las imágenes ya descargadas)
        (
            echo "🏗️  Creando cluster PRE en background..."
            crear_cluster_optimizado "gitops-pre" "2" "2048" "20g" "metrics-server,ingress" && \
            echo "✅ Cluster gitops-pre completado"
        ) &
        
        (
            echo "🏗️  Creando cluster PRO en background..."
            crear_cluster_optimizado "gitops-pro" "2" "2048" "20g" "metrics-server,ingress" && \
            echo "✅ Cluster gitops-pro completado"
        ) &
        
        # Esperar que ambos clusters se completen
        wait
        
        # Volver al contexto de DEV
        kubectl config use-context "gitops-dev"
        
        echo "✅ Entorno multi-cluster creado exitosamente"
    else
        echo "ℹ️  Modo solo-dev: Clusters adicionales omitidos"
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE ESTADO Y REPORTE
# ============================================================================

# Muestra el estado de todos los clusters GitOps
mostrar_estado_clusters() {
    echo "📊 Estado de clusters GitOps:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local clusters=("gitops-dev" "gitops-pre" "gitops-pro")
    
    for cluster in "${clusters[@]}"; do
        local estado
        estado=$(verificar_cluster_existente "$cluster" 2>/dev/null || echo "no_existe")
        
        case "$estado" in
            "funcional")
                echo "   ✅ $cluster: Funcional"
                ;;
            "detenido")
                echo "   ⏸️  $cluster: Detenido"
                ;;
            "corrupto")
                echo "   ⚠️  $cluster: Corrupto"
                ;;
            "no_existe")
                echo "   ❌ $cluster: No existe"
                ;;
            *)
                echo "   ❓ $cluster: Estado desconocido"
                ;;
        esac
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Limpia cache y recursos temporales
limpiar_cache_clusters() {
    echo "🧹 Limpiando cache de clusters..."
    
    # Eliminar directorio de cache
    rm -rf "$CLUSTER_CACHE_DIR" 2>/dev/null || true
    
    # Eliminar clusters temporales
    minikube delete --profile="gitops-cache-temp" >/dev/null 2>&1 || true
    
    echo "✅ Cache limpiado"
}
