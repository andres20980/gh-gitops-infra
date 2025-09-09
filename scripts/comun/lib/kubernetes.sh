#!/bin/bash

# ============================================================================
# KUBERNETES LIB - Gestión Universal de Clusters Kubernetes
# ============================================================================
# Responsabilidad: Clusters minikube, validación K8s, contextos
# Principios: Multi-cluster, WSL-optimizado, Production-ready
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Perfiles base; dev será ajustado dinámicamente en tiempo de ejecución
readonly CLUSTER_PROFILES=(
    "gitops-dev:auto:auto:full:Desarrollo completo con todas las herramientas"
    "gitops-pre:2:2048:minimal:Preproducción mínima"
    "gitops-pro:2:2048:minimal:Producción mínima"
)

readonly MINIKUBE_DRIVER="docker"
readonly MINIKUBE_NETWORK="bridge" 
readonly DOCKER_DAEMON_TIMEOUT=60

# Ajustes dinámicos
: "${DYNAMIC_DEV_SIZING:=true}"   # true/false: auto dimensionar dev
: "${CLUSTER_DEV_CPUS:=}"         # override explícito CPUs dev
: "${CLUSTER_DEV_MEMORY:=}"       # override explícito memoria dev (MB)
: "${DYNAMIC_SIZING_HEADROOM:=30}" # % de holgura sobre suma de requests

# Overheads del sistema (aprox para kube-system y addons mínimos)
readonly SYSTEM_OVERHEAD_CPU_M="500"   # 500m
readonly SYSTEM_OVERHEAD_MEM_MI="1024" # 1Gi

# ============================================================================
# FUNCIONES DE DOCKER
# ============================================================================

# Verificar estado del daemon Docker
check_docker_daemon() {
    if docker info >/dev/null 2>&1; then
        log_success "✅ Docker daemon activo"
        return 0
    else
        log_warning "⚠️ Docker daemon no disponible"
        return 1
    fi
}

# Crear cluster kind
create_kind_cluster() {
    local profile="$1"
    local description="$2"

    log_info "Creando cluster kind: $profile ($description)"

    # Verificar si el cluster ya existe
    if kind get clusters | grep -q "^$profile$"; then
        log_success "✅ Cluster kind $profile ya existe"
        return 0
    fi

    # Crear archivo de configuración para kind
    cat <<EOF > "/tmp/kind-config-${profile}.yaml"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${profile}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8081
    protocol: TCP
  - containerPort: 443
    hostPort: 8444
    protocol: TCP
EOF

    log_info "🆕 Creando nuevo cluster kind $profile..."
    if kind create cluster --config "/tmp/kind-config-${profile}.yaml"; then
        log_success "✅ Cluster kind $profile creado correctamente"
        return 0
    else
        log_error "❌ Error creando cluster kind $profile"
        return 1
    fi
}

# Inicializar Docker en WSL
init_docker_wsl() {
    log_info "🐳 Inicializando Docker daemon..."
    
    # WSL2 con Docker Desktop
    if grep -q microsoft /proc/version 2>/dev/null; then
        log_info "🖥️ Entorno WSL detectado"
        
        if command -v docker.exe >/dev/null 2>&1; then
            log_info "🔗 Docker Desktop disponible"
            return 0
        fi
        
        # Dockerd manual en WSL
        if ! pgrep dockerd >/dev/null; then
            log_info "🚀 Iniciando Docker daemon local..."
            sudo dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 &
            
            local counter=0
            while ! docker info >/dev/null 2>&1 && [[ $counter -lt $DOCKER_DAEMON_TIMEOUT ]]; do
                sleep 2
                ((counter += 2))
                log_debug "Esperando daemon... ($counter/$DOCKER_DAEMON_TIMEOUT s)"
            done
            
            if check_docker_daemon; then
                return 0
            else
                log_error "❌ Falló inicio de Docker daemon"
                return 1
            fi
        fi
    fi
    
    # Linux nativo con systemd
    if command -v systemctl >/dev/null 2>&1 && [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
        if ! systemctl is-active --quiet docker 2>/dev/null; then
            log_info "🔄 Iniciando servicio Docker..."
            sudo systemctl start docker || true
            sudo systemctl enable docker || true
        fi
    else
        log_info "🧩 Entorno sin systemd: omitiendo systemctl para Docker"
    fi
    
    check_docker_daemon
}

# Configurar permisos Docker para usuario
setup_docker_user() {
    if ! groups | grep -q docker 2>/dev/null; then
        log_warning "⚠️ Usuario no está en grupo docker"
        return 1
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        log_info "🔧 Aplicando permisos Docker..."
        # Recargar grupos sin logout
        newgrp docker <<EOF
docker ps >/dev/null 2>&1 && echo "Permisos aplicados"
EOF
    fi
    
    log_success "✅ Docker configurado para usuario"
    return 0
}

# ============================================================================
# FUNCIONES DE CLUSTER
# ============================================================================

# Verificar cluster healthy
check_cluster_health() {
    local profile="$1"
    
    log_info "🏥 Verificando salud del cluster $profile..."
    
    # Cambiar contexto
    kubectl config use-context "kind-${profile}" >/dev/null 2>&1
    
    # Verificar conectividad
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ No se puede conectar al cluster $profile"
        return 1
    fi
    
    # Verificar nodos Ready
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    
    if [[ "$ready_nodes" -eq 0 ]]; then
        log_error "❌ Ningún nodo Ready en $profile"
        return 1
    fi
    
    # Verificar pods sistema
    local system_pods
    system_pods=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    
    if [[ "$system_pods" -lt 3 ]]; then
        log_warning "⚠️ Pocos pods sistema running en $profile ($system_pods)"
    fi
    
    log_success "✅ Cluster $profile healthy ($ready_nodes nodos, $system_pods pods sistema)"
    return 0
}

# Crear cluster (ahora usa kind)
create_minikube_cluster() {
    local profile="$1"
    local cpus="$2"
    local memory="$3"
    local preset="$4"
    local description="$5"

    create_kind_cluster "$profile" "$description"
}

# Obtener línea de configuración para un perfil
_get_profile_config_line() {
    local profile="$1"
    local line
    for line in "${CLUSTER_PROFILES[@]}"; do
        if [[ "$line" == "$profile:"* ]]; then
            echo "$line"
            return 0
        fi
    done
    return 1
}

# Sugerir recursos dinámicos para dev basados en la máquina
_suggest_dev_resources() {
    # Salida: echo "<cpus> <memory_mb>"
    local total_cpus total_mem_kb total_mem_mb reserve_mb cpu_target mem_target
    total_cpus=$(nproc 2>/dev/null || echo 4)
    total_mem_kb=$(grep -i '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 8388608)
    total_mem_mb=$(( total_mem_kb / 1024 ))

    # CPUs: 60% de los cores, mínimo 4, máximo 8, dejando al menos 1 libre
    cpu_target=$(( (total_cpus * 60 + 99) / 100 ))
    if (( cpu_target > total_cpus - 1 )); then cpu_target=$(( total_cpus > 1 ? total_cpus - 1 : 1 )); fi
    if (( cpu_target < 4 )); then cpu_target=4; fi
    if (( cpu_target > 8 )); then cpu_target=8; fi

    # Memoria: 50% de la RAM, con reserva 2GB para host; clamp 6144..16384 MB
    reserve_mb=2048
    mem_target=$(( total_mem_mb / 2 ))
    if (( mem_target > total_mem_mb - reserve_mb )); then mem_target=$(( total_mem_mb - reserve_mb )); fi
    if (( mem_target < 6144 )); then mem_target=6144; fi
    if (( mem_target > 16384 )); then mem_target=16384; fi

    echo "$cpu_target $mem_target"
}

# Crear cluster por nombre de perfil usando CLUSTER_PROFILES
create_cluster_by_profile() {
    local profile="$1"
    local line
    line=$(_get_profile_config_line "$profile" || true)
    if [[ -z "$line" ]]; then
        log_error "❌ Configuración no encontrada para perfil: $profile"
        return 1
    fi
    local _profile _cpus _memory _preset _description
    IFS=':' read -r _profile _cpus _memory _preset _description <<< "$line"
    # Ajuste dinámico para pre/pro mínimos estrictos respetando capacidad
    if [[ "$profile" == "gitops-pre" || "$profile" == "gitops-pro" ]]; then
        local min_cpus min_mem
        read -r min_cpus min_mem < <(minimos_pre_pro)
        _cpus="$min_cpus"
        _memory="$min_mem"
    fi
    create_minikube_cluster "$_profile" "$_cpus" "$_memory" "$_preset" "$_description"
}

# ==========================================================================
# ESTIMACIÓN DE RECURSOS A PARTIR DE VALORES HELM (DEV)
# ==========================================================================

# Convertir CPU a millicores (acepta: 200m, 1, 1.5, 2)
_parse_cpu_to_milli() {
    local v="$1"
    v="${v%%#*}"; v="${v%% *}"; v="${v//$'\r'/}" # limpiar comentarios/espacios/CR
    if [[ "$v" =~ ^[0-9]+m$ ]]; then
        echo "${v%m}"
    elif [[ "$v" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        # cores decimales -> millicores
        awk -v x="$v" 'BEGIN { printf("%d", (x*1000)+0.5) }'
    else
        # desconocido -> 0
        echo "0"
    fi
}

# Convertir memoria a Mi (acepta: 128Mi, 1Gi, 512M, 2G, 1024)
_parse_mem_to_mi() {
    local v="$1"
    v="${v%%#*}"; v="${v%% *}"; v="${v//$'\r'/}" # limpiar
    local num unit
    num="${v//[!0-9.]/}"
    unit="${v//[0-9.]/}"
    if [[ -z "$num" ]]; then echo 0; return; fi
    case "$unit" in
        Mi|mi|M|m|"" ) awk -v x="$num" 'BEGIN { printf("%d", x+0) }' ;;
        Gi|gi|G|g)      awk -v x="$num" 'BEGIN { printf("%d", (x*1024)+0.5) }' ;;
        Ki|ki|K|k)      awk -v x="$num" 'BEGIN { printf("%d", (x/1024)+0.5) }' ;;
        *)              awk -v x="$num" 'BEGIN { printf("%d", x+0) }' ;;
    esac
}

# Sumar requests de CPU y memoria desde ficheros values de un directorio
_sum_requests_from_values_dir() {
    local dir="$1"
    local total_cpu_m=0
    local total_mem_mi=0

    if [[ ! -d "$dir" ]]; then
        echo "0 0"
        return 0
    fi

    # Requiere GNU awk; si no está disponible, omitir y devolver 0 0
    if ! awk --version 2>/dev/null | grep -qi "GNU Awk"; then
        echo "0 0"
        return 0
    fi

    local f line kind val
    for f in "$dir"/*.yaml "$dir"/*.yml; do
        [[ -f "$f" ]] || continue
        # Extraer líneas cpu/memory dentro de bloques requests: respetando indentación
        while IFS= read -r line; do
            kind="${line%% *}"; val="${line#* }"
            case "$kind" in
                CPU)
                    total_cpu_m=$(( total_cpu_m + $(_parse_cpu_to_milli "$val") ))
                    ;;
                MEM)
                    total_mem_mi=$(( total_mem_mi + $(_parse_mem_to_mi "$val") ))
                    ;;
            esac
    done < <(awk '
            function lead(s,   r){ match(s, /^[ ]*/); return RLENGTH }
            {
              if ($0 ~ /^[[:space:]]*requests:[[:space:]]*$/) { in=1; base=lead($0); next }
              if (in) {
                cur=lead($0);
                if (cur <= base) { in=0; next }
                if ($0 ~ /cpu:[[:space:]]*/)    { gsub(/.*cpu:[[:space:]]*/, "", $0); printf("CPU %s\n", $0) }
                if ($0 ~ /memory:[[:space:]]*/) { gsub(/.*memory:[[:space:]]*/, "", $0); printf("MEM %s\n", $0) }
              }
            }
        ' "$f")
    done

    echo "$total_cpu_m $total_mem_mi"
}

# Estimar recursos necesarios para dev a partir de stack GitOps (con holgura y overheads)
estimate_dev_resources_from_stack() {
    # Salida: "<cpus> <memory_mb>"
    local lib_dir script_dir repo_root values_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    repo_root="$(cd "$script_dir/../../.." && pwd)"
    values_dir="$repo_root/herramientas-gitops/values-dev"

    local cpu_m mem_mi
    read -r cpu_m mem_mi < <(_sum_requests_from_values_dir "$values_dir")

    # Añadir overheads del sistema
    cpu_m=$(( cpu_m + SYSTEM_OVERHEAD_CPU_M ))
    mem_mi=$(( mem_mi + SYSTEM_OVERHEAD_MEM_MI ))

    # Holgura
    local head="$DYNAMIC_SIZING_HEADROOM"
    if [[ "$head" =~ ^[0-9]+$ ]]; then
        cpu_m=$(( cpu_m + (cpu_m * head + 99) / 100 ))
        mem_mi=$(( mem_mi + (mem_mi * head + 99) / 100 ))
    fi

    # Convertir a unidades del cluster
    local cpus
    cpus=$(( (cpu_m + 999) / 1000 ))
    local mem_mb
    mem_mb=$(( mem_mi )) # Mi -> MB aproximado

    # Mínimos razonables para dev
    if (( cpus < 4 )); then cpus=4; fi
    if (( mem_mb < 6144 )); then mem_mb=6144; fi

    # No exceder capacidad razonable del host (dejar 1 CPU y 2GB libres)
    local total_cpus total_mem_kb total_mem_mb cap_cpu cap_mem
    total_cpus=$(nproc 2>/dev/null || echo 4)
    total_mem_kb=$(grep -i '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 8388608)
    total_mem_mb=$(( total_mem_kb / 1024 ))
    cap_cpu=$(( total_cpus > 1 ? total_cpus - 1 : 1 ))
    cap_mem=$(( total_mem_mb > 2048 ? total_mem_mb - 2048 : total_mem_mb ))
    if (( cpus > cap_cpu )); then cpus=$cap_cpu; fi
    if (( mem_mb > cap_mem )); then mem_mb=$cap_mem; fi

    echo "$cpus $mem_mb"
}

# Configurar addons por cluster
setup_cluster_addons() {
    local profile="$1"
    local preset="$2"
    
    log_info "🔧 Configurando addons para $profile..."
    
    kubectl config use-context "kind-${profile}"

    log_info "🔌 Instalando NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    log_info "📊 Instalando Metrics Server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    log_info "⏳ Esperando que los addons esten listos..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s

    log_success "✅ Addons configurados para $profile"
}

# Asegurar addon metrics-server habilitado (idempotente)
ensure_metrics_server() {
    local profile="$1"
    log_info "Asegurando addons habilitados en $profile..."
    setup_cluster_addons "$profile" ""
}

# Detectar si los nameservers del host son privados (RFC1918), lo que suele romper DNS en Docker/kind
_host_has_private_dns() {
    local ns
    while read -r ns; do
        case "$ns" in
            10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) return 0 ;;
        esac
    done < <(grep -E '^nameserver ' /etc/resolv.conf | awk '{print $2}')
    return 1
}

# Parchear CoreDNS para usar DNS públicos
patch_coredns_upstreams_to_public() {
    local ns1="${1:-1.1.1.1}" ns2="${2:-8.8.8.8}"
    log_info "🧩 Parcheando CoreDNS para usar forwards: $ns1 $ns2"
    if ! kubectl -n kube-system get configmap coredns >/dev/null 2>&1; then
        log_warning "⚠️ ConfigMap coredns no encontrado"
        return 1
    fi
    local tmp=/tmp/coredns.$$; kubectl -n kube-system get configmap coredns -o yaml > "$tmp"
    # Sustituir cualquier línea forward . ... por forward . ns1 ns2
    sed -i -E "s|forward \. .*|forward . ${ns1} ${ns2}|" "$tmp"
    kubectl -n kube-system apply -f "$tmp" >/dev/null
    kubectl -n kube-system rollout restart deployment coredns >/dev/null 2>&1 || true
    log_success "✅ CoreDNS parcheado y reiniciado"
}

# Asegurar DNS del cluster funcional: si el host usa DNS privado, forzar públicos en CoreDNS
ensure_cluster_dns() {
    local profile="$1"
    log_info "🔎 Verificando DNS del cluster $profile..."
    kubectl config use-context "kind-${profile}" >/dev/null 2>&1 || true
    if _host_has_private_dns; then
        log_warning "⚠️ Nameservers privados detectados en el host; actualizando CoreDNS"
        patch_coredns_upstreams_to_public 1.1.1.1 8.8.8.8 || true
        # Esperar CoreDNS listo
        kubectl -n kube-system rollout status deployment coredns --timeout=90s >/dev/null 2>&1 || true
    else
        log_info "✅ Nameservers del host parecen públicos; no se cambia CoreDNS"
    fi
}

# ============================================================================
# FUNCIONES DE CONTEXTO
# ============================================================================

# Verificar disponibilidad de cluster
check_cluster_available() {
    local expected_context="${1:-minikube}"
    
    log_info "🔍 Verificando disponibilidad del cluster..."
    
    # Verificar contexto actual
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null || echo "ninguno")
    
    local kind_context="kind-${expected_context}"
    if [[ "$current_context" != "$kind_context" ]]; then
        log_info "🔄 Cambiando contexto a $kind_context..."
        if ! kubectl config use-context "$kind_context" >/dev/null 2>&1; then
            log_error "❌ Contexto $kind_context no disponible"
            return 1
        fi
    fi
    
    # Verificar conectividad
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "❌ No se puede conectar al cluster"
        return 1
    fi
    
    # Verificar nodos ready
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
    
    if [[ "$ready_nodes" -eq 0 ]]; then
        log_error "❌ No hay nodos Ready en el cluster"
        return 1
    fi
    
    log_success "✅ Cluster disponible ($ready_nodes nodos Ready)"
    return 0
}

# Listar contextos disponibles
list_contexts() {
    log_info "📋 Contextos kubectl disponibles:"
    kubectl config get-contexts
}

# Cambiar contexto activo
switch_context() {
    local context="$1"
    local kind_context="kind-${context}"
    
    if kubectl config use-context "$kind_context" >/dev/null 2>&1; then
        log_success "✅ Contexto cambiado a: $kind_context"
        return 0
    else
        log_error "❌ No se pudo cambiar a contexto: $kind_context"
        return 1
    fi
}

# ============================================================================
# FUNCIONES PRINCIPALES
# ============================================================================

# Crear cluster de desarrollo
create_dev_cluster() {
    log_section "Creación de Cluster de Desarrollo"
    
    # Extraer configuración dev
    local dev_config
    dev_config=$(printf '%s\n' "${CLUSTER_PROFILES[@]}" | grep "^gitops-dev:")
    
    if [[ -z "$dev_config" ]]; then
        log_error "❌ Configuración cluster dev no encontrada"
        return 1
    fi
    
    # Parsear configuración
    IFS=':' read -r profile cpus memory preset description <<< "$dev_config"

    # Dimensionado dinámico opcional (basado en stack GitOps + límites del host)
    if [[ "$DYNAMIC_DEV_SIZING" == "true" ]]; then
        local est_cpus est_mem sug_cpus sug_mem
        read -r est_cpus est_mem < <(estimate_dev_resources_from_stack)
        read -r sug_cpus sug_mem < <(_suggest_dev_resources)

        # Aplicar overrides explícitos si se han definido
        if [[ -n "$CLUSTER_DEV_CPUS" ]]; then est_cpus="$CLUSTER_DEV_CPUS"; fi
        if [[ -n "$CLUSTER_DEV_MEMORY" ]]; then est_mem="$CLUSTER_DEV_MEMORY"; fi

        # Si el perfil define "auto", usar la estimación como base numérica
        if [[ "$cpus" == "auto" ]]; then cpus="$est_cpus"; fi
        if [[ "$memory" == "auto" ]]; then memory="$est_mem"; fi

        # Tomar el máximo entre perfil base y estimación del stack
        if (( est_cpus < cpus )); then est_cpus="$cpus"; fi
        if (( est_mem  < memory )); then est_mem="$memory"; fi

        log_info "🧠 Estimación por stack: CPUs=$est_cpus, Memoria=${est_mem}MB"
        log_info "🧮 Sugerencia por host: CPUs=$sug_cpus, Memoria=${sug_mem}MB"

    # Elegir la mayor entre estimación y sugerencia, dentro de límites del host ya aplicados internamente
        if (( sug_cpus > est_cpus )); then cpus="$sug_cpus"; else cpus="$est_cpus"; fi
        if (( sug_mem  > est_mem  )); then memory="$sug_mem"; else memory="$est_mem"; fi

        log_info "📐 Dimensionado final dev: CPUs=$cpus, Memoria=${memory}MB"
    fi
    
    # Crear cluster
    if create_minikube_cluster "$profile" "$cpus" "$memory" "$preset" "$description"; then
    setup_cluster_addons "$profile" "$preset"
        kubectl config use-context "$profile"
    log_success "Cluster desarrollo configurado"
        return 0
    else
    log_error "Error creando cluster desarrollo"
        return 1
    fi
}

# Crear clusters de promoción mínimos (pre y pro)
create_promotion_clusters() {
    log_section "🚀 Creación de Clusters de Promoción (mínimos)"
    create_cluster_by_profile "gitops-pre" || return 1
    create_cluster_by_profile "gitops-pro" || return 1
    log_success "✅ Clusters pre y pro creados"
}

# Mostrar resumen de clusters
show_clusters_summary() {
    log_section "📋 Resumen de Clusters"
    
    if command -v kind >/dev/null 2>&1; then
        log_info "🔍 Clusters kind:"
        kind get clusters || log_info "  Ningún cluster encontrado"
    fi
    
    log_info "🔍 Contextos kubectl:"
    kubectl config get-contexts 2>/dev/null || log_info "  Ningún contexto encontrado"
    
    log_info "🔍 Cluster actual:"
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null || echo "ninguno")
    log_info "  Contexto: $current_context"
    
    if [[ "$current_context" != "ninguno" ]]; then
        local ready_nodes
        ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo "0")
        log_info "  Nodos Ready: $ready_nodes"
    fi
}
