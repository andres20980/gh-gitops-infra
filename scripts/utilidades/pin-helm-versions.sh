#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
APPS_DIR="$ROOT_DIR/herramientas-gitops/activas"
WRITE=false
ONLY_FILE=""

usage(){
  echo "Uso: $0 [--write] [--file <application.yaml>]" >&2
  echo "  --write   Sobrescribe targetRevision en los manifests (por defecto solo muestra)" >&2
  echo "  --file    Pin solo un fichero concreto (por defecto, todos en $APPS_DIR)" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write) WRITE=true; shift ;;
    --file) ONLY_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage; exit 1 ;;
  esac
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Falta dependencia: $1" >&2; exit 1; }; }
need helm; need jq; need sed; need awk

files=()
if [[ -n "$ONLY_FILE" ]]; then
  files=("$ONLY_FILE")
else
  mapfile -t files < <(find "$APPS_DIR" -maxdepth 1 -type f -name '*.yaml' | sort)
fi

pin_file(){
  local file="$1"
  # Extraer primer repoURL y chart bajo 'sources:' (primer item)
  local repo chart
  repo="$(awk '/^\s*sources:\s*$/{flag=1;next} flag && /repoURL:/{print $2; exit} flag && /^\s*[^- ]/{flag=0}' "$file" | tr -d '"')"
  chart="$(awk '/^\s*sources:\s*$/{flag=1;next} flag && /chart:/{print $2; exit} flag && /^\s*[^- ]/{flag=0}' "$file" | tr -d '"')"
  if [[ -z "$repo" || -z "$chart" ]]; then
    echo "[skip] $file: no se pudo extraer repoURL/chart" >&2
    return 0
  fi
  # Derivar alias del repo a partir del host y path
  local host path alias
  host="$(sed -E 's#https?://([^/]+)/?.*#\1#' <<<"$repo")"
  path="$(sed -E 's#https?://[^/]+/?(.*)$#\1#' <<<"$repo" | tr '/' '-')"
  alias="$(printf '%s-%s' "$host" "${path:-repo}" | tr -cd '[:alnum:]-' | tr 'A-Z' 'a-z' | sed 's/--*/-/g; s/-$//')"
  # Añadir repo helm y actualizar
  helm repo add "$alias" "$repo" >/dev/null 2>&1 || true
  helm repo update "$alias" >/dev/null 2>&1 || true
  # Buscar última versión estable
  local name latest
  name="$alias/$chart"
  latest="$(helm search repo "$name" --versions -o json 2>/dev/null | jq -r --arg n "$name" '[.[] | select(.name==$n) | .version | select(test("-")|not)][0] // (.[0].version // "")')"
  if [[ -z "$latest" ]]; then
    echo "[warn] $file: no se pudo resolver versión para $name" >&2
    return 0
  fi
  echo "[pin] $file -> $chart@$latest"
  if $WRITE; then
    # Reemplazar la primera targetRevision dentro del primer bloque de source
    local tmp; tmp="$(mktemp)"
    awk -v chart="$chart" -v ver="$latest" '
      BEGIN{in_sources=0; in_first=0; pinned=0}
      /^\s*sources:\s*$/ {in_sources=1}
      in_sources && /^\s*-\s*repoURL:/ {in_first=1}
      in_first && /^\s*chart:\s*/ {
        if ($2==chart) { in_chart=1 } else { in_chart=0 }
      }
      in_chart && /^\s*targetRevision:\s*/ && pinned==0 {
        sub(/targetRevision:.*/, "      targetRevision: \"" ver "\""); pinned=1
      }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
  fi
}

for f in "${files[@]}"; do
  pin_file "$f"
done

if ! $WRITE; then
  echo "(uso --write para aplicar cambios)" >&2
fi

