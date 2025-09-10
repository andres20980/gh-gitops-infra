#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
VENDOR_DIR="$ROOT_DIR/charts/vendor"
mkdir -p "$VENDOR_DIR"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Falta dependencia: $1" >&2; exit 1; }; }
need helm; need awk; need sed; need jq

vendor_known() {
  # Loki
  mkdir -p "$VENDOR_DIR/loki"
  if [[ ! -d "$VENDOR_DIR/loki/5.44.0" ]]; then
    helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo update grafana >/dev/null 2>&1 || true
    helm pull grafana/loki --version 5.44.0 --untar --untardir "$VENDOR_DIR/loki"
    echo "[vendor] loki@5.44.0"
  fi
  # Kargo
  mkdir -p "$VENDOR_DIR/kargo"
  if [[ ! -d "$VENDOR_DIR/kargo/0.6.0" ]]; then
    helm repo add kargo https://charts.kargo.akuity.io >/dev/null 2>&1 || true
    helm repo update kargo >/dev/null 2>&1 || true
    helm pull kargo/kargo --version 0.6.0 --untar --untardir "$VENDOR_DIR/kargo"
    echo "[vendor] kargo@0.6.0"
  fi
}

# vendor_one <app_yaml>
vendor_one(){
  local app_file="$1"
  local chart repo ver name subdir
  # Extraer del application YAML (primer source tipo repo Helm)
  repo="$(awk '
    /^\s*sources?:\s*$/ {in=1; next}
    in && /repoURL:/ {print $2; exit}
    in && /^\s*[^- ]/ {in=0}
  ' "$app_file" | tr -d '"')"
  chart="$(awk '/^\s*sources?:\s*$/{in=1;next} in && /chart: /{print $2; exit} in && /^\s*[^- ]/{in=0}' "$app_file" | tr -d '"')"
  ver="$(awk '/^\s*sources?:\s*$/{in=1;next} in && /targetRevision: /{print $2; exit} in && /^\s*[^- ]/{in=0}' "$app_file" | tr -d '"')"
  if [[ -z "$repo" || -z "$chart" || -z "$ver" ]]; then
    echo "[warn] $app_file: no se pudo extraer repo/chart/version; usando vendor_known()" >&2
    vendor_known
    return 0
  fi
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
  # Reescribir el application YAML para usar el chart vendorizado desde Gitea
  local tmp; tmp="$(mktemp)"
  awk -v chart="$chart" -v ver="$ver" '
    BEGIN{in_sources=0; in_first=0}
    /^\s*sources:\s*$/ {in_sources=1}
    in_sources && /^\s*-\s*repoURL:/ {
      if (in_first==0) { in_first=1 }
      else { in_first=2 }
    }
    # Primera fuente: sustituir repoURL/chart/targetRevision
    in_sources && in_first==1 && /^\s*-\s*repoURL:/ {
      gsub(/repoURL:.*/, "repoURL: http://gitea-http-stable.gitea.svc.cluster.local:3000/admin/gitops-infra.git"); print; next
    }
    in_sources && in_first==1 && /^\s*chart:\s*/ {
      gsub(/chart:.*/, "path: charts\/vendor\/" chart "/" ver); print; next
    }
    in_sources && in_first==1 && /^\s*targetRevision:\s*/ {
      gsub(/targetRevision:.*/, "targetRevision: HEAD"); print; next
    }
    { print }
  ' "$app_file" > "$tmp" && mv "$tmp" "$app_file"
}

if [[ $# -gt 0 ]]; then
  for f in "$@"; do vendor_one "$f"; done
else
  # Vendorizar todos los Application manifests activos que referencien charts helm
  any=0
  while IFS= read -r -d '' f; do vendor_one "$f"; any=1; done < <(find "$ROOT_DIR/herramientas-gitops/activas" -maxdepth 1 -type f -name '*.yaml' -print0)
  if [[ "$any" == "0" ]]; then
    vendor_known
  fi
fi

echo "[done] charts vendorizados en $VENDOR_DIR"
