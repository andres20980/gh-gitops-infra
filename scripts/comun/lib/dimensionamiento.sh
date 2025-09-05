#!/bin/bash

# =============================================================================
# SIZING LIB - Estimación de recursos y capacidad del sistema
# =============================================================================
# Responsabilidad: calcular recursos necesarios para el clúster dev y respetar
# los límites del sistema (Ubuntu/WSL). Provee mínimos dinámicos para pre/pro.
# =============================================================================

set -euo pipefail

# Leer CPUs totales del sistema
leer_cpus_totales() {
    nproc 2>/dev/null || echo 2
}

# Leer memoria total (MB) del sistema
leer_mem_total_mb() {
    awk '/MemTotal/ { printf "%d\n", $2/1024 }' /proc/meminfo 2>/dev/null || echo 2048
}

# Detectar si es WSL
es_wsl() {
    grep -qi 'microsoft' /proc/version 2>/dev/null
}

# Calcular capacidad utilizable aplicando headroom del SO
capacidad_util_sistema() {
    local cpus_total mem_total
    cpus_total=$(leer_cpus_totales)
    mem_total=$(leer_mem_total_mb)

    local headroom_frac
    headroom_frac=${OS_HEADROOM:-0.25} # 25% por defecto

    # Cálculo
    local cpus_util mem_util
    cpus_util=$(awk -v c="$cpus_total" -v h="$headroom_frac" 'BEGIN { printf "%d", (c - (c*h)) }')
    mem_util=$(awk -v m="$mem_total" -v h="$headroom_frac" 'BEGIN { printf "%d", (m - (m*h)) }')

    # Asegurar mínimos razonables
    if [[ "$cpus_util" -lt 2 ]]; then cpus_util=2; fi
    if [[ "$mem_util" -lt 2048 ]]; then mem_util=2048; fi

    echo "$cpus_util $mem_util"
}

# Estimar recursos requeridos por las herramientas GitOps (peticiones)
# Si existe yq, se usa; si no, heurística sencilla.
estimar_recursos_gitops() {
    local base_dir="${PROJECT_ROOT:-$(pwd)}/herramientas-gitops"
    local values_dir="$base_dir/values-dev"
    local cpu_millicores=0
    local mem_mb=0

    if command -v yq >/dev/null 2>&1; then
        # Sumar recursos de todos los values*.yaml
        while IFS= read -r f; do
            # Extraer todas las peticiones de cpu (en millicores) y memoria (Mi/M)
            local cpu_list mem_list
            cpu_list=$(yq -r '..|.resources?.requests?.cpu? // empty' "$f" 2>/dev/null || true)
            mem_list=$(yq -r '..|.resources?.requests?.memory? // empty' "$f" 2>/dev/null || true)
            # CPU: convertir a millicores
            if [[ -n "$cpu_list" ]]; then
                while IFS= read -r c; do
                    [[ -z "$c" ]] && continue
                    if [[ "$c" =~ ^([0-9]+)m$ ]]; then
                        cpu_millicores=$((cpu_millicores + ${BASH_REMATCH[1]}))
                    elif [[ "$c" =~ ^([0-9]+(\.[0-9]+)?)$ ]]; then
                        # en cores
                        cpu_millicores=$((cpu_millicores + ${BASH_REMATCH[1]%.*}*1000))
                    fi
                done <<< "$cpu_list"
            fi
            # Memoria: convertir a MB
            if [[ -n "$mem_list" ]]; then
                while IFS= read -r m; do
                    [[ -z "$m" ]] && continue
                    if [[ "$m" =~ ^([0-9]+)Mi?$ ]]; then
                        mem_mb=$((mem_mb + ${BASH_REMATCH[1]}))
                    elif [[ "$m" =~ ^([0-9]+)Gi?$ ]]; then
                        mem_mb=$((mem_mb + ${BASH_REMATCH[1]}*1024))
                    fi
                done <<< "$mem_list"
            fi
        done < <(find "$values_dir" -type f -name '*values*.yaml' 2>/dev/null)
    else
        # Heurística: si no hay yq, tomar un baseline conservador
        # Ajustable por entorno GITOPS_BASELINE_CPU/mem
        local baseline_cpu_mc=${GITOPS_BASELINE_CPU_MC:-3000}   # 3 cores
        local baseline_mem_mb=${GITOPS_BASELINE_MEM_MB:-6144}  # 6 GiB
        cpu_millicores=$baseline_cpu_mc
        mem_mb=$baseline_mem_mb
    fi

    # Overhead configurable para sistema y pods base
    local overhead_frac=${SIZING_OVERHEAD:-0.25}
    local cpu_mc_total mem_mb_total
    cpu_mc_total=$(awk -v c="$cpu_millicores" -v o="$overhead_frac" 'BEGIN { printf "%d", (c * (1+o)) }')
    mem_mb_total=$(awk -v m="$mem_mb" -v o="$overhead_frac" 'BEGIN { printf "%d", (m * (1+o)) }')

    # Redondear CPU a enteros (cores)
    local cpu_cores=$(( (cpu_mc_total + 999) / 1000 ))
    if [[ "$cpu_cores" -lt 2 ]]; then cpu_cores=2; fi
    if [[ "$mem_mb_total" -lt 2048 ]]; then mem_mb_total=2048; fi

    echo "$cpu_cores $mem_mb_total"
}

# Proponer sizing para clúster dev: min(max(requerido, mínimos), capacidad_util)
proponer_sizing_dev() {
    # Overrides directos
    if [[ -n "${DEV_CPUS:-}" && -n "${DEV_MEMORY_MB:-}" ]]; then
        echo "${DEV_CPUS} ${DEV_MEMORY_MB}"
        return 0
    fi

    local req_cpus req_mem util_cpus util_mem
    read -r req_cpus req_mem < <(estimar_recursos_gitops)
    read -r util_cpus util_mem < <(capacidad_util_sistema)

    # Aplicar límites
    local cpus="$req_cpus"
    local mem="$req_mem"
    if (( cpus > util_cpus )); then cpus=$util_cpus; fi
    if (( mem > util_mem )); then mem=$util_mem; fi

    # Garantizar mínimos
    if (( cpus < 2 )); then cpus=2; fi
    if (( mem < 2048 )); then mem=2048; fi

    echo "$cpus $mem"
}

# Obtener mínimos para pre/pro (dinámicos con escalado posterior en start)
minimos_pre_pro() {
    # Valores iniciales conservadores; el escalado lo hará kubernetes.sh si falla el arranque
    local min_cpus=${PREPRO_MIN_CPUS:-2}
    local min_mem=${PREPRO_MIN_MEM_MB:-2048}

    # No exceder capacidad util del sistema (por si el host es muy pequeño)
    local util_cpus util_mem
    read -r util_cpus util_mem < <(capacidad_util_sistema)
    if (( min_cpus > util_cpus )); then min_cpus=$util_cpus; fi
    if (( min_mem > util_mem )); then min_mem=$util_mem; fi

    echo "$min_cpus $min_mem"
}

# Exportar
export -f leer_cpus_totales leer_mem_total_mb es_wsl capacidad_util_sistema estimar_recursos_gitops proponer_sizing_dev minimos_pre_pro
