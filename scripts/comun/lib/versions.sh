#!/bin/bash

# =============================================================================
# LIBRERÍA DE VERSIONES - Detección y compatibilidad de versiones
# =============================================================================
# Responsabilidad: obtener versiones latest/estables y compatibilidad kubectl
# Principios: DRY, sin hardcodeos, dinámico y robusto
# =============================================================================

set -euo pipefail

# Formatear versión para impresión (por defecto: corta mayor.menor)
formatear_version() {
    local ver="$1"
    case "${VERSION_FORMAT:-short}" in
        full)
            printf '%s' "$ver"
            ;;
        *)
            printf '%s' "$ver" | awk -F. '{ if (NF>=2) printf "%s.%s", $1, $2; else printf "%s", $0 }'
            ;;
    esac
}

# Obtener última versión disponible de una herramienta (mejor esfuerzo)
obtener_ultima_version() {
    local herramienta="$1"
    case "$herramienta" in
        docker)
            curl -fsSL https://api.github.com/repos/docker/docker-ce/releases/latest | grep -oP '(?<="tag_name": "v)\d+\.\d+\.\d+' 2>/dev/null || echo "24.0"
            ;;
        minikube)
            curl -fsSL https://api.github.com/repos/kubernetes/minikube/releases/latest | grep -oP '(?<="tag_name": "v)\d+\.\d+\.\d+' 2>/dev/null || echo "1.32"
            ;;
        kubectl)
            curl -fsSL https://dl.k8s.io/release/stable.txt | sed 's/^v//' 2>/dev/null || echo "1.28"
            ;;
        helm)
            curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | grep -oP '(?<="tag_name": "v)\d+\.\d+\.\d+' 2>/dev/null || echo "3.13"
            ;;
        git)
            echo "system"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Obtener versión estable de Kubernetes según minikube (sin arrancar cluster)
obtener_k8s_estable_minikube() {
    if ! command -v minikube >/dev/null 2>&1; then
        return 1
    fi
    local estable
    estable=$(minikube start --help 2>/dev/null | grep -oP "'stable' for v\K[0-9]+\.[0-9]+\.[0-9]+" | head -n1 || true)
    if [[ -n "$estable" ]]; then
        printf '%s' "$estable"
        return 0
    fi
    return 1
}

# Determinar versión de kubectl compatible con minikube (dinámica y con overrides)
obtener_version_kubectl_compatible() {
    local version_minikube="${1:-}"
    # Overrides por entorno
    if [[ -n "${KUBECTL_VERSION:-}" ]]; then printf '%s' "${KUBECTL_VERSION#v}"; return 0; fi
    if [[ -n "${K8S_VERSION:-}" ]]; then printf '%s' "${K8S_VERSION#v}"; return 0; fi
    if [[ -n "${MINIKUBE_K8S_VERSION:-}" ]]; then printf '%s' "${MINIKUBE_K8S_VERSION#v}"; return 0; fi

    # Preferir la versión estable que reporta minikube
    local v
    if v=$(obtener_k8s_estable_minikube 2>/dev/null); then
        printf '%s' "$v"
        return 0
    fi
    # Fallback a estable pública de Kubernetes
    v=$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null | sed 's/^v//' || true)
    if [[ -z "$v" ]]; then v="1.28.0"; fi
    printf '%s' "$v"
}

# Obtener versión de kubectl instalada de forma robusta (full o short)
obtener_version_kubectl_instalada() {
    local modo="${1:-full}" # full|short
    local ver=""
    ver=$(kubectl version --client -o json 2>/dev/null | grep -oP '"gitVersion"\s*:\s*"v\K[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
    if [[ -z "$ver" ]]; then
        ver=$(kubectl version --client=true --short 2>/dev/null | grep -oP 'Client Version: v\K[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
    fi
    if [[ -z "$ver" ]]; then
        ver=$(kubectl version --client 2>/dev/null | grep -oP 'GitVersion:"v\K[0-9]+\.[0-9]+(\.[0-9]+)?' || true)
    fi
    if [[ -z "$ver" ]]; then
        echo ""
        return 1
    fi
    case "$modo" in
        short) printf '%s' "$ver" | awk -F. '{ if (NF>=2) printf "%s.%s", $1, $2; else printf "%s", $0 }' ;;
        *) printf '%s' "$ver" ;;
    esac
}

# Exportaciones
export -f formatear_version obtener_ultima_version obtener_k8s_estable_minikube obtener_version_kubectl_compatible obtener_version_kubectl_instalada
