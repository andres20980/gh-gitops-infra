#!/bin/bash

# =============================================================================
# FASE 0: PREPARACIÓN/RESET DEL ENTORNO (SEGURA POR DEFECTO)
# =============================================================================
# Modos:
#  - (default)       Seguro: sin acciones destructivas; detiene PF del proyecto,
#                    limpia temporales, muestra estado y recomendaciones.
#  - --fix           Arreglos no destructivos.
#  - --soft-clean    Limpia SOLO recursos del proyecto (clusters kind gitops-*,
#                    contextos kube gitops-*, PF); backup kubeconfig.
#  - --nuke --yes    Reseteo profundo SOLO de recursos del proyecto.
#  - --dry-run       Muestra el plan de acciones sin ejecutarlas.
# =============================================================================

set -euo pipefail

DRY_RUN=false
MODE="safe"
ASSUME_YES=false

usage() { echo "Uso: $0 [--dry-run] [--fix|--soft-clean|--nuke] [--yes]" >&2; }
plan()  { if [[ "$DRY_RUN" == "true" ]]; then echo "[plan] $*"; else eval "$*"; fi; }

stop_project_port_forwards() {
  log_info "Deteniendo port-forwards en puertos 8080-8091..."
  for p in $(seq 8080 8091); do
    if lsof -t -i :"$p" >/dev/null 2>&1; then plan "lsof -t -i :$p | xargs -r kill -9 || true"; fi
  done
  [[ -f "$PROJECT_ROOT/scripts/accesos-herramientas.sh" ]] && plan "bash \"$PROJECT_ROOT/scripts/accesos-herramientas.sh\" stop || true"
}

backup_kubeconfig() {
  if [[ -f "$HOME/.kube/config" ]]; then
    local ts; ts=$(date +%Y%m%d-%H%M%S)
    local dest="$HOME/.kube/config.backup-$ts"
    log_info "Backup kubeconfig → $dest"; plan "mkdir -p \"$HOME/.kube\" && cp \"$HOME/.kube/config\" \"$dest\""
  fi
}

delete_kind_cluster_if_gitops() {
  local name="$1"
  if kind get clusters 2>/dev/null | grep -q "^${name}$"; then log_info "Eliminando cluster kind: $name"; plan "kind delete cluster --name \"$name\" || true"; fi
}

remove_gitops_contexts() {
  log_info "Eliminando contextos kube gitops-* (si existen)"
  for ctx in kind-gitops-dev kind-gitops-pre kind-gitops-pro; do
    if kubectl config get-contexts "$ctx" >/dev/null 2>&1; then plan "kubectl config delete-context \"$ctx\" || true"; fi
  done
}

report_env() {
  log_section "📋 Estado actual del entorno"; log_info "Clusters kind:"; kind get clusters 2>/dev/null || true; log_info "Contextos kube:"; kubectl config get-contexts 2>/dev/null || true
}

confirm_or_abort() {
  local msg="$1"; [[ "$ASSUME_YES" == "true" ]] && return 0; log_warning "$msg"; echo "Usa --yes para continuar sin confirmación." >&2; return 1
}

main() {
  # Parseo de flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --fix) MODE="fix"; shift ;;
      --soft-clean) MODE="soft-clean"; shift ;;
      --nuke) MODE="nuke"; shift ;;
      --yes|-y) ASSUME_YES=true; shift ;;
      -h|--help) usage; return 0 ;;
      *) log_warning "Flag desconocida: $1"; usage; return 1 ;;
    esac
  done

  log_section "🧹 FASE 0: Preparación/Reset (modo: $MODE)"

  # Siempre: detener PF y mostrar estado
  stop_project_port_forwards
  report_env

  case "$MODE" in
    safe)
      log_info "Modo seguro: sin acciones destructivas."
      log_info "Siguiente paso sugerido: ./instalar.sh fase-02"
      ;;
    fix)
      log_info "Aplicando arreglos no destructivos..."
      command -v kind >/dev/null 2>&1 || log_info "kind no encontrado; se instalará en Fase 02"
      log_success "✅ Arreglos básicos aplicados (no destructivo)"
      ;;
    soft-clean)
      backup_kubeconfig
      delete_kind_cluster_if_gitops gitops-dev
      delete_kind_cluster_if_gitops gitops-pre
      delete_kind_cluster_if_gitops gitops-pro
      remove_gitops_contexts
      log_success "✅ Soft-clean completado (solo recursos del proyecto)"
      ;;
    nuke)
      confirm_or_abort "⚠️ Nuke: se eliminarán clusters kind gitops-(dev|pre|pro) y contextos kube asociados" || return 1
      backup_kubeconfig
      delete_kind_cluster_if_gitops gitops-dev
      delete_kind_cluster_if_gitops gitops-pre
      delete_kind_cluster_if_gitops gitops-pro
      remove_gitops_contexts
      log_success "✅ Nuke del entorno del proyecto completado"
      ;;
    *) log_error "Modo desconocido: $MODE"; return 1 ;;
  esac

    # Sección anterior eliminada: acciones destructivas pasan a --soft-clean/--nuke
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
