#!/bin/bash

# =============================================================================
# FASE 0: RESETEO LIMPIO DEL ENTORNO LOCAL
# =============================================================================
# Objetivo: dejar el entorno limpio (clusters kind, namespaces, CRDs, PF)
# para ejecutar una instalación real, desatendida y reproducible.
# =============================================================================

set -euo pipefail

main() {
    log_section "🧹 FASE 0: Reset Limpio del Entorno"

    # Confirmación fuerte salvo ejecución no interactiva con --yes o variable
    local force="false"
    while [[ ${1:-} ]]; do
      case "$1" in
        --yes|-y) force="true"; shift ;;
        *) shift ;;
      esac
    done
    if [[ "${GITOPS_FORCE_RESET:-}" == "true" || "${GITOPS_FORCE_RESET:-}" == "1" ]]; then
      force="true"
    fi
    if [[ "$force" != "true" ]]; then
      if [[ -t 0 ]]; then
        echo "ADVERTENCIA: Esta acción eliminará clusters kind, binarios (kubectl/helm/kind/argocd) y datos Docker/containerd." >&2
        read -r -p "¿Deseas continuar? Escribe 'YES' para confirmar: " ans
        if [[ "$ans" != "YES" ]]; then
          log_warning "Reset cancelado por el usuario"
          return 0
        fi
      else
        log_error "Fase 0 requiere confirmación. Reintenta con --yes o GITOPS_FORCE_RESET=true"
        return 1
      fi
    fi

    # 0. Detener port-forwards locales (rangos 8080-8091 y conocidos)
    log_info "Deteniendo port-forwards en puertos 8080-8091..."
    for p in $(seq 8080 8091); do
        if lsof -t -i :"$p" >/dev/null 2>&1; then
            lsof -t -i :"$p" | xargs -r kill -9 || true
        fi
    done

    # 1. No intentamos borrar namespaces/CRDs: vamos a borrar los clusters directamente
    log_info "Omitiendo borrado de Namespaces/CRDs: se eliminarán directamente los clusters kind"

    # 2. Eliminar clusters kind (si existen)
    for c in gitops-dev gitops-pre gitops-pro; do
      if kind get clusters 2>/dev/null | grep -q "^${c}$"; then
        log_info "Eliminando cluster kind: $c"
        kind delete cluster --name "$c" || true
      fi
    done

    # 3. Purga de dependencias del sistema (siempre en Fase 00)
    log_section "🧽 Purga de dependencias del sistema"
    # Mejor esfuerzo: si hay apt y sudo disponibles, desinstalar paquetes; además, borrar binarios sueltos
    if command -v apt-get >/dev/null 2>&1; then
      log_info "Eliminando paquetes apt relacionados (Docker/kubectl/helm/jq)..."
      sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io jq helm kubectl 2>/dev/null || true
      sudo apt-get autoremove -y 2>/dev/null || true
      # Borrar repositorios/llaves Docker para evitar reinstalación accidental de canal inadecuado
      sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
      sudo rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
      sudo apt-get update || true
    else
      log_info "apt-get no disponible; se omitirá purga vía paquetes"
    fi

    log_info "Eliminando binarios en /usr/local/bin (kubectl, helm, kind, argocd)..."
    sudo rm -f /usr/local/bin/kubectl /usr/local/bin/helm /usr/local/bin/kind /usr/local/bin/argocd 2>/dev/null || true

    # Limpiar configuraciones locales
    log_info "Limpiando configuraciones locales (kubeconfig/argocd/helm caches)..."
    rm -rf "$HOME/.kube" 2>/dev/null || true
    rm -rf "$HOME/.config/argocd" 2>/dev/null || true
    rm -rf "$HOME/.cache/helm" "$HOME/.config/helm" 2>/dev/null || true

    # Eliminar datos de Docker/containerd
    log_warning "Eliminando datos de Docker local (/var/lib/docker, /var/lib/containerd)" 
    sudo systemctl stop docker 2>/dev/null || true
    # En entornos sin systemd, puede no parar; continuar igualmente
    sudo rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || true
    log_success "✅ Purga de dependencias completada"

    log_success "✅ Entorno limpio"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
