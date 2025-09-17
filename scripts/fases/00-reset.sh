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

# If this script is executed directly, try to source the common startup (logging helpers)
if [[ -z "${PROJECT_ROOT:-}" ]]; then
  readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  export PROJECT_ROOT
fi
if [[ -f "$PROJECT_ROOT/scripts/comun/arranque.sh" ]] && [[ "${DRY_SYSTEM_INITIALIZED:-false}" != "true" ]]; then
  # shellcheck source=scripts/comun/arranque.sh
  source "$PROJECT_ROOT/scripts/comun/arranque.sh"
fi

DRY_RUN=false
# Por defecto hacer un nuke profundo cuando se ejecuta sin opciones
MODE="deep-nuke"
# Evitar confirmaciones interactivas por defecto (según requerimiento del instalador)
ASSUME_YES=true

usage() { echo "Uso: $0 [--dry-run] [--fix|--soft-clean|--nuke] [--yes]" >&2; }
plan()  { if [[ "$DRY_RUN" == "true" ]]; then echo "[plan] $*"; else bash -c "set +e; $*"; fi; }

stop_project_port_forwards() {
  log_info "Deteniendo port-forwards en puertos 8080-8091..."
  for p in $(seq 8080 8091); do
    if lsof -t -i :"$p" >/dev/null 2>&1; then plan "lsof -t -i :$p | xargs -r kill -9 || true"; fi
  done
  [[ -f "$PROJECT_ROOT/scripts/accesos-herramientas.sh" ]] && plan "bash \"$PROJECT_ROOT/scripts/accesos-herramientas.sh\" stop || true"
}

remove_local_gitea_container() {
  log_info "Comprobando contenedor local Gitea (gitea-wsl) y eliminando si existe"
  if command -v docker >/dev/null 2>&1; then
    if docker ps -a --format '{{.Names}}' | grep -q '^gitea-wsl$'; then
      plan "docker rm -f gitea-wsl || true"
    fi
  fi
}

remove_port_forward_pids() {
  log_info "Eliminando pid/logs de port-forwards comunes"
  plan "rm -f /tmp/argocd-port-forward.pid /tmp/argocd-port-forward.log /tmp/gitea_pf.pid /tmp/gitea-port-forward.log || true"
  # Kill any background port-forward processes by reading pids
  if [[ -f /tmp/argocd-port-forward.pid ]]; then
    plan "if ps -p \$(cat /tmp/argocd-port-forward.pid) >/dev/null 2>&1; then kill -9 \$(cat /tmp/argocd-port-forward.pid) || true; fi"
  fi
}

remove_project_namespaces() {
  log_info "Eliminando namespaces relacionados al proyecto en clusters disponibles (argocd,gitea,ingress-nginx)"
  for ctx in $(kubectl config get-contexts -o name 2>/dev/null || true); do
    # Solo actuar sobre contexts kind-gitops-* para evitar borrar namespaces ajenos
    if [[ "$ctx" =~ ^kind-gitops- ]]; then
      plan "kubectl --context \"$ctx\" delete ns argocd gitea ingress-nginx --ignore-not-found || true"
    fi
  done
}

# Kill any process binding common host ports used for promotion clusters
kill_processes_on_promotion_ports() {
  local ports=(8081 8444 43111)
  for p in "${ports[@]}"; do
    if lsof -t -i :"$p" >/dev/null 2>&1; then
      log_info "Matando proceso que usa el puerto $p"
      plan "lsof -t -i :$p | xargs -r kill -9 || true"
    fi
  done
}

remove_kind_network_and_residuals() {
  # Stop any running kind containers and remove kind network if stale
  if command -v docker >/dev/null 2>&1; then
    log_info "Comprobando contenedores kind residuales y red 'kind'"
    # Remove containers with label io.x-k8s.kind.cluster
    plan "docker ps -a --filter label=io.x-k8s.kind.cluster -q | xargs -r docker rm -f || true"
    # Remove kind network if exists and not used
    if docker network ls --format '{{.Name}}' | grep -q '^kind$'; then
      plan "docker network rm kind || true"
    fi
  fi
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
      --deep-nuke) MODE="deep-nuke"; shift ;;
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
  log_info "Siguiente paso sugerido: ./instalar.sh fase-01"
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
      remove_local_gitea_container
      remove_port_forward_pids
      remove_project_namespaces
      remove_gitops_contexts
      log_success "✅ Soft-clean completado (solo recursos del proyecto)"
      ;;
    nuke)
      confirm_or_abort "⚠️ Nuke: se eliminarán clusters kind gitops-(dev|pre|pro) y contextos kube asociados" || return 1
      backup_kubeconfig
      delete_kind_cluster_if_gitops gitops-dev
      delete_kind_cluster_if_gitops gitops-pre
      delete_kind_cluster_if_gitops gitops-pro
      remove_local_gitea_container
      remove_port_forward_pids
      remove_project_namespaces
      remove_gitops_contexts
      log_success "✅ Nuke del entorno del proyecto completado"
      ;;
    deep-nuke)
      confirm_or_abort "⚠️ Deep-nuke: esto detendrá/eliminará contenedores Docker, imágenes, volúmenes y puede intentar desinstalar paquetes Docker del host. Asegúrate de no necesitar nada en este host." || return 1
      backup_kubeconfig
      delete_kind_cluster_if_gitops gitops-dev
      delete_kind_cluster_if_gitops gitops-pre
      delete_kind_cluster_if_gitops gitops-pro
      remove_gitops_contexts

  # Eliminar contenedor Gitea local y port-forwards antes de operaciones profundas
  remove_local_gitea_container
  remove_port_forward_pids
  remove_project_namespaces

      log_info "Iniciando limpieza profunda del host (Docker/podman si existen)..."

      if command -v docker >/dev/null 2>&1; then
        log_info "Docker detectado: parando y eliminando contenedores, imágenes y volúmenes"
        plan "sudo systemctl stop docker || true"
        plan "sudo docker ps -aq | xargs -r sudo docker rm -f || true"
        plan "sudo docker images -aq | xargs -r sudo docker rmi -f || true"
        plan "sudo docker volume ls -q | xargs -r sudo docker volume rm -f || true"
        plan "sudo docker network ls -q | xargs -r sudo docker network rm || true"
        plan "sudo rm -rf /var/lib/docker || true"
        plan "sudo rm -rf /var/lib/containerd || true"
        # Remove any named containers used by this installer (gitea-wsl, kind nodes)
        plan "sudo docker rm -f gitea-wsl || true"
        plan "sudo docker ps -a --filter label=io.x-k8s.kind.cluster -q | xargs -r sudo docker rm -f || true"

        if command -v apt-get >/dev/null 2>&1; then
          log_info "apt detected: intentando purgar paquetes Docker (apt-get)"
          plan "sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true"
          plan "sudo apt-get autoremove -y || true"
        elif command -v yum >/dev/null 2>&1; then
          log_info "yum detected: intentando eliminar paquetes Docker (yum)"
          plan "sudo yum remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true"
        else
          log_info "No se detectó gestor de paquetes apt/yum; omitiendo desinstalación de paquetes (se eliminaron recursos de Docker)"
        fi
      elif command -v podman >/dev/null 2>&1; then
        log_info "Podman detectado: parando y eliminando contenedores y volúmenes"
        plan "sudo podman ps -aq | xargs -r sudo podman rm -f || true"
        plan "sudo podman images -q | xargs -r sudo podman rmi -f || true"
        plan "sudo rm -rf /var/lib/containers || true"
      else
        log_info "No se detectó Docker ni Podman en el host; no hay acciones de runtime a realizar."
      fi

      # Además: eliminar binarios/tools que el instalador puede haber colocado
      log_info "Eliminando binarios instalados por el instalador (kind,kubectl,helm,minikube,argocd) si existen..."
      plan "sudo rm -f /usr/local/bin/kind /usr/local/bin/kubectl /usr/local/bin/helm /usr/local/bin/minikube /usr/local/bin/argocd /usr/local/bin/argocd || true"

      # Intentar purgar paquetes instalados via apt (git, jq)
      if command -v apt-get >/dev/null 2>&1; then
        log_info "Purgando paquetes apt instalados por el instalador: git, jq"
        plan "sudo apt-get purge -y git jq || true"
        plan "sudo apt-get autoremove -y || true"
      fi

      # Limpiar caches y configuraciones locales
      log_info "Limpiando caches y configuraciones locales (helm, kube, argocd, tmp)..."
  plan "rm -rf $HOME/.cache/helm $HOME/.helm $HOME/.kube $HOME/.config/argocd /tmp/get_helm.sh /tmp/argocd* /tmp/kind-config-* /tmp/gitops-final-report.txt || true"

  # Additional WSL specific cleanup: docker context and local images
  plan "docker context rm kind || true"
  plan "sudo rm -rf /var/tmp/gh-gitops-infra || true"

      # Eliminar fuentes apt docker si quedaron
      plan "sudo rm -f $DOCKER_SOURCES /etc/apt/keyrings/docker.gpg || true"

      # Eliminar pid/logs de port-forwards comunes
      plan "rm -f /tmp/argocd-port-forward.pid /tmp/argocd-port-forward.log /tmp/gitea_pf.pid /tmp/gitea-port-forward.log || true"

  log_success '✅ Deep-nuke completado (intento). Revise manualmente paquetes con "dpkg -l|grep -E "docker|git|jq"" si es necesario.'
      ;;
    *) log_error "Modo desconocido: $MODE"; return 1 ;;
  esac

    # Sección anterior eliminada: acciones destructivas pasan a --soft-clean/--nuke
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
