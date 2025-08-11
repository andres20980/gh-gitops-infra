#!/usr/bin/env bash
set -euo pipefail

# Activa una herramienta GitOps (por nombre de archivo YAML en herramientas-gitops)
# - Actualiza dinámicamente targetRevision al último chart estable
# - Copia el Application a herramientas-gitops/active/<tool>.yaml (sólo uno activo)
# - Commit y push a main
# - Aplica App-of-Apps si no existe

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
TOOLS_DIR="$REPO_ROOT/herramientas-gitops"
ACTIVE_DIR="$TOOLS_DIR/active"
APP_OF_APPS="$REPO_ROOT/argo-apps/app-of-tools-gitops.yaml"

log() { echo "[activate-tool] $*"; }
die() { echo "[activate-tool][ERROR] $*" >&2; exit 1; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
  cat <<EOF
Uso: scripts/tools/activate-tool.sh <tool>
Ej:   scripts/tools/activate-tool.sh cert-manager
EOF
  exit 0
fi

TOOL="$1"
SRC_APP="$TOOLS_DIR/${TOOL}.yaml"
[[ -f "$SRC_APP" ]] || die "No existe: $SRC_APP"

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

# Limpiar activos anteriores
rm -f "$ACTIVE_DIR"/*.yaml 2>/dev/null || true

DEST_APP="$ACTIVE_DIR/${TOOL}.yaml"
if [[ -n "$latest_ver" ]]; then
  log "Actualizando ${TOOL} a chart ${chart} version ${latest_ver}"
  awk -v ver="$latest_ver" '
    BEGIN{updated=0}
    /^\s*targetRevision:/ { print "    targetRevision: " ver; updated=1; next }
    { print }
  ' "$SRC_APP" > "$DEST_APP"
else
  log "Manteniendo targetRevision actual para ${TOOL} (no se resolvió última versión)"
  cp "$SRC_APP" "$DEST_APP"
fi

# Commit y push a main
git add "$DEST_APP" "$APP_OF_APPS"
if ! git diff --cached --quiet; then
  git commit -m "feat(gitops): activate ${TOOL} (chart ${chart}${latest_ver:+ -> ${latest_ver}})"
  git push -u origin main
else
  log "No hay cambios para commitear"
fi
popd >/dev/null

# Aplicar el App-of-Apps
kubectl apply -f "$APP_OF_APPS"

log "Activado ${TOOL}. Argo CD sincronizará herramientas-gitops/active."
