#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
VENDOR_DIR="$ROOT_DIR/charts/vendor"
mkdir -p "$VENDOR_DIR"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Falta dependencia: $1" >&2; exit 1; }; }
need helm; need awk; need sed

# vendor_one <app_yaml>
vendor_one(){
  local app_file="$1"
  local chart repo ver name subdir
  # Extraer del application YAML (primer source tipo repo Helm)
  repo="$(awk '/^\s*sources?:\s*$/{in=1;next} in && /repoURL: (http|https):\/\//{print $2; exit} in && /^\s*[^- ]/{in=0}' "$app_file" | tr -d '"')"
  chart="$(awk '/^\s*sources?:\s*$/{in=1;next} in && /chart: /{print $2; exit} in && /^\s*[^- ]/{in=0}' "$app_file" | tr -d '"')"
  ver="$(awk '/^\s*sources?:\s*$/{in=1;next} in && /targetRevision: /{print $2; exit} in && /^\s*[^- ]/{in=0}' "$app_file" | tr -d '"')"
  [[ -z "$repo" || -z "$chart" || -z "$ver" ]] && { echo "[skip] No se pudo extraer repo/chart/version de $app_file" >&2; return 0; }
  name="$chart"
  subdir="$VENDOR_DIR/$name/$ver"
  if [[ -d "$subdir" ]]; then
    echo "[ok] chart ya vendorizado: $name@$ver"
    return 0
  fi
  echo "[vendor] $name@$ver desde $repo"
  local alias host path
  host="$(sed -E 's#https?://([^/]+)/?.*#\1#' <<<"$repo")"
  path="$(sed -E 's#https?://[^/]+/?(.*)$#\1#' <<<"$repo" | tr '/' '-')"
  alias="$(printf '%s-%s' "$host" "${path:-repo}" | tr -cd '[:alnum:]-' | tr 'A-Z' 'a-z' | sed 's/--*/-/g; s/-$//')"
  helm repo add "$alias" "$repo" >/dev/null 2>&1 || true
  helm repo update "$alias" >/dev/null 2>&1 || true
  mkdir -p "$VENDOR_DIR/$name"
  helm pull "$alias/$chart" --untar --untardir "$VENDOR_DIR/$name" --version "$ver"
}

if [[ $# -gt 0 ]]; then
  for f in "$@"; do vendor_one "$f"; done
else
  # Por defecto vendorizar Kargo y Loki si existen
  for f in \
    "$ROOT_DIR/herramientas-gitops/activas/kargo.yaml" \
    "$ROOT_DIR/herramientas-gitops/activas/loki.yaml"; do
    [[ -f "$f" ]] && vendor_one "$f" || true
  done
fi

echo "[done] charts vendorizados en $VENDOR_DIR"

