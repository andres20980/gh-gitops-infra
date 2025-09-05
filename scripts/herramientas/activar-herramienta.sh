#!/usr/bin/env bash
set -euo pipefail

# Activa una herramienta GitOps (por nombre de archivo YAML en herramientas-gitops)
# - Actualiza dinámicamente targetRevision al último chart estable
# - Copia el Application a herramientas-gitops/activas/<tool>.yaml (sólo uno activo)
# - Commit y push a main
# - Aplica App-of-Apps si no existe

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
TOOLS_DIR="$REPO_ROOT/herramientas-gitops"
ACTIVE_DIR="$TOOLS_DIR/active"
APP_OF_APPS="$REPO_ROOT/argo-apps/aplicacion-de-herramientas-gitops.yaml"

log() { echo "[activate-tool] $*"; }
die() { echo "[activate-tool][ERROR] $*" >&2; exit 1; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
  cat <<EOF
Uso: scripts/herramientas/activar-herramienta.sh <tool>
Ej:   scripts/herramientas/activar-herramienta.sh cert-manager
EOF
  exit 0
fi

TOOL="$1"
# Origen del Application: priorizar herramientas-gitops/inactivas si no existe en raíz
if [[ -f "$TOOLS_DIR/${TOOL}.yaml" ]]; then
  SRC_APP="$TOOLS_DIR/${TOOL}.yaml"
elif [[ -f "$TOOLS_DIR/inactive/${TOOL}.yaml" ]]; then
  SRC_APP="$TOOLS_DIR/inactive/${TOOL}.yaml"
else
  die "No existe ni en raíz ni en inactive: $TOOLS_DIR/{,inactive/}${TOOL}.yaml"
fi

mkdir -p "$ACTIVE_DIR"

pushd "$REPO_ROOT" >/dev/null
current_branch=$(git rev-parse --abbrev-ref HEAD)
# Cambiar a main y fusionar si estamos en otra rama
if [[ "$current_branch" != "main" ]]; then
  git fetch --all --tags || true
  if git show-ref --verify --quiet refs/heads/main; then
    git checkout main
  else
    git checkout -b main
  fi
  if git show-ref --verify --quiet "refs/heads/$current_branch" && [[ "$current_branch" != "main" ]]; then
    git merge --no-ff "$current_branch" -m "merge: $current_branch into main for gated tools activation" || die "Conflictos en merge"
  fi
fi

# Resolver repoURL y chart
repo_url=$(awk '/^[[:space:]]*repoURL:/{print $2; exit}' "$SRC_APP" | tr -d '"')
chart=$(awk '/^[[:space:]]*chart:/{print $2; exit}' "$SRC_APP" | tr -d '"')
path_src=$(awk '/^[[:space:]]*path:/{print $2; exit}' "$SRC_APP" | tr -d '"') || true
latest_ver=""

get_latest_chart_version() {
  local repo_url="$1" chart="$2"
  local repo_name
  repo_name="temp-$(echo "$chart" | tr ':/_.' '-' )-$$"
  helm repo add "$repo_name" "$repo_url" >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  local line
  line=$(helm search repo "${repo_name}/${chart}" --versions 2>/dev/null | awk 'NR==2{print $0}')
  if [[ -z "$line" ]]; then
    return 1
  fi
  echo "$line" | awk '{print $2}'
}

if [[ "$repo_url" =~ ^https?:// && ! "$repo_url" =~ \\.(git)$ ]]; then
  latest_ver=$(get_latest_chart_version "$repo_url" "$chart" || true)
fi

# Mantener activos previos (activación acumulativa)

DEST_APP="$ACTIVE_DIR/${TOOL}.yaml"

# Extraer campos clave del YAML fuente
app_name=$(awk '/^metadata:/,0 { if ($1=="name:") {print $2; exit} }' "$SRC_APP" | tr -d '"') || true
[[ -n "${app_name:-}" ]] || app_name="$TOOL"
dest_ns=$(awk '/^spec:/,/^  syncPolicy:/ { if ($1=="namespace:") {print $2; exit} }' "$SRC_APP" | tr -d '"') || true
dest_ns=${dest_ns:-argocd}
dest_server=$(awk '/^spec:/,/^  syncPolicy:/ { if ($1=="server:") {print $2; exit} }' "$SRC_APP" | tr -d '"') || true
dest_server=${dest_server:-https://kubernetes.default.svc}
project=$(awk '/^spec:/,/^  source:/ { if ($1=="project:") {print $2; exit} }' "$SRC_APP" | tr -d '"') || true
project=${project:-default}

# Detectar values file (primera entrada)
values_file=$(awk '/valueFiles:/,0 { if ($1=="-" && $2!="") {print $2; exit} }' "$SRC_APP" | tr -d '"') || true
# Normalizar ruta a valores en repo (prefijo herramientas-gitops si faltase)
if [[ -n "${values_file:-}" ]]; then
  if [[ "$values_file" != herramientas-gitops/* ]]; then
    values_file="herramientas-gitops/${values_file}"
  fi
fi
# Fallback por convención si no se detectó values_file
if [[ -z "${values_file:-}" ]]; then
  if [[ -f "${TOOLS_DIR}/values-dev/${TOOL}-dev-values.yaml" ]]; then
    values_file="herramientas-gitops/values-dev/${TOOL}-dev-values.yaml"
  fi
fi

# Detectar opciones de sync relevantes en el YAML fuente
opt_server_side_apply="false"
opt_apply_out_of_sync_only="false"
grep -q 'ServerSideApply=true' "$SRC_APP" && opt_server_side_apply="true" || true
grep -q 'ApplyOutOfSyncOnly=true' "$SRC_APP" && opt_apply_out_of_sync_only="true" || true

# Construir Application multi-source si repo_url es Helm chart repo (no .git)
if [[ "$repo_url" =~ ^https?:// && ! "$repo_url" =~ \\.(git)$ ]]; then
  chart_ver=${latest_ver:-$(awk '/^[[:space:]]*targetRevision:/{print $2; exit}' "$SRC_APP" | tr -d '"')}
  log "Render multi-source para ${TOOL} (chart ${chart}@${chart_ver}) con values ${values_file:-<ninguno>}"
  cat >"$DEST_APP" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${app_name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: ${project}
  sources:
    - repoURL: ${repo_url}
      chart: ${chart}
      targetRevision: "${chart_ver}"
      helm:
        valueFiles:
$(if [[ -n "${values_file:-}" ]]; then echo "          - \$values/${values_file}"; else echo "          - values.yaml"; fi)
    - repoURL: https://github.com/andres20980/gh-gitops-infra.git
      targetRevision: HEAD
      ref: values
      path: .
  destination:
    server: ${dest_server}
    namespace: ${dest_ns}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
$(if [[ "$opt_server_side_apply" == "true" ]]; then echo "    - ServerSideApply=true"; fi)
$(if [[ "$opt_apply_out_of_sync_only" == "true" ]]; then echo "    - ApplyOutOfSyncOnly=true"; fi)
EOF
else
  # Si el origen ya es Git, respetar YAML con posible actualización de targetRevision
  # Multi-source para Git chart path + values repo
  git_rev=$(awk '/^[[:space:]]*targetRevision:/{print $2; exit}' "$SRC_APP" | tr -d '"')
  log "Render multi-source (git) para ${TOOL} path ${path_src:-.} @ ${git_rev} con values ${values_file:-<ninguno>}"
  cat >"$DEST_APP" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${app_name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: ${project}
  sources:
    - repoURL: ${repo_url}
      targetRevision: "${git_rev}"
      path: ${path_src:-.}
      helm:
        valueFiles:
$(if [[ -n "${values_file:-}" ]]; then echo "          - \$values/${values_file}"; else echo "          - values.yaml"; fi)
    - repoURL: https://github.com/andres20980/gh-gitops-infra.git
      targetRevision: HEAD
      ref: values
      path: .
  destination:
    server: ${dest_server}
    namespace: ${dest_ns}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
$(if [[ "$opt_server_side_apply" == "true" ]]; then echo "    - ServerSideApply=true"; fi)
$(if [[ "$opt_apply_out_of_sync_only" == "true" ]]; then echo "    - ApplyOutOfSyncOnly=true"; fi)
EOF
fi

# Commit y push a main
git add -f "$DEST_APP" "$APP_OF_APPS"
if ! git diff --cached --quiet; then
  git commit -m "feat(gitops): activate ${TOOL} (chart ${chart}${latest_ver:+ -> ${latest_ver}})"
  git push -u origin main
else
  log "No hay cambios para commitear"
fi
popd >/dev/null

# Aplicar el App-of-Apps
kubectl apply -f "$APP_OF_APPS"

log "Activado ${TOOL}. Argo CD sincronizará herramientas-gitops/activas."
