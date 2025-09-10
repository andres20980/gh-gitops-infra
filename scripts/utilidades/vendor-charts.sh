#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
VENDOR_DIR="$ROOT_DIR/charts/vendor"
mkdir -p "$VENDOR_DIR"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Falta dependencia: $1" >&2; exit 1; }; }
need awk; need sed; need helm

vendor_known() { :; }

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
  # Normalizar estructura: si existe charts/vendor/<name>/<name>, aplanar a charts/vendor/<name>
  normalize_chart_dir() {
    local name="$1"; local base="$VENDOR_DIR/$name"
    if [[ -d "$base/$name" && ! -f "$base/Chart.yaml" && -f "$base/$name/Chart.yaml" ]]; then
      echo "[normalize] $name: moviendo $base/$name/* a $base/" >&2
      mkdir -p "$base.tmp"
      rsync -a "$base/$name/" "$base.tmp/" >/dev/null 2>&1 || cp -R "$base/$name/"* "$base.tmp/" 2>/dev/null || true
      rm -rf "$base/$name"
      rm -rf "$base"
      mv "$base.tmp" "$base"
    fi
  }

  charts=(
    argo-events
    argo-rollouts
    argo-workflows
    cert-manager
    grafana
    ingress-nginx
    jaeger
    kargo
    loki
    minio
    kube-prometheus-stack
    gitea
  )
  for c in "${charts[@]}"; do normalize_chart_dir "$c"; done

  # Si faltan charts, intentamos descargarlos con helm pull (una sola vez)
  add_repo() { local alias="$1" url="$2"; helm repo add "$alias" "$url" >/dev/null 2>&1 || true; }
  update_repo() { local alias="$1"; helm repo update "$alias" >/dev/null 2>&1 || true; }

  declare -A REPO_URL=(
    [argo-events]="https://argoproj.github.io/argo-helm"
    [argo-workflows]="https://argoproj.github.io/argo-helm"
    [argo-rollouts]="https://argoproj.github.io/argo-helm"
    [cert-manager]="https://charts.jetstack.io"
    [grafana]="https://grafana.github.io/helm-charts"
    [ingress-nginx]="https://kubernetes.github.io/ingress-nginx"
    [jaeger]="https://jaegertracing.github.io/helm-charts"
    [kargo]="https://charts.kargo.akuity.io"
    [loki]="https://grafana.github.io/helm-charts"
    [minio]="https://charts.min.io"
    [kube-prometheus-stack]="https://prometheus-community.github.io/helm-charts"
    [gitea]="https://dl.gitea.io/charts"
  )
  declare -A CHART_NAME=(
    [argo-events]="argo-events"
    [argo-workflows]="argo-workflows"
    [argo-rollouts]="argo-rollouts"
    [cert-manager]="cert-manager"
    [grafana]="grafana"
    [ingress-nginx]="ingress-nginx"
    [jaeger]="jaeger"
    [kargo]="kargo"
    [loki]="loki"
    [minio]="minio"
    [kube-prometheus-stack]="kube-prometheus-stack"
    [gitea]="gitea"
  )
  # Versiones pinneadas conocidas; vacío => latest estable
  declare -A CHART_VER=(
    [argo-rollouts]="2.38.0"
    [loki]="5.44.0"
    [kargo]="0.6.0"
    [gitea]="12.1.3"
  )

  for c in "${charts[@]}"; do
    if [[ ! -f "$VENDOR_DIR/$c/Chart.yaml" ]]; then
      echo "[vendor] descargando chart $c ..." >&2
      mkdir -p "$VENDOR_DIR/$c"
      repo="${REPO_URL[$c]}"; chart="${CHART_NAME[$c]}"; ver="${CHART_VER[$c]:-}"
      alias="repo-${c}"
      if add_repo "$alias" "$repo" && update_repo "$alias"; then
        if [[ -n "$ver" ]]; then
          if helm pull "$alias/$chart" --version "$ver" --untar --untardir "$VENDOR_DIR/$c"; then
            normalize_chart_dir "$c"
          fi
        else
          if helm pull "$alias/$chart" --untar --untardir "$VENDOR_DIR/$c"; then
            normalize_chart_dir "$c"
          fi
        fi
      fi
    fi
  done

  # Verificar que existan charts vendorizados requeridos (forma aplanada)
  missing=()
  for c in "${charts[@]}"; do
    [[ -f "$VENDOR_DIR/$c/Chart.yaml" ]] || missing+=("$VENDOR_DIR/$c")
  done
  if (( ${#missing[@]} > 0 )); then
    echo "⚠️ No se pudieron vendorizar algunos charts:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    # Fallback: reescribir Applications a no-op para que Argo no falle y permitir instalación parcial
    declare -A CHART_APP_FILE=(
      [argo-events]="herramientas-gitops/activas/argo-events.yaml"
      [argo-workflows]="herramientas-gitops/activas/argo-workflows.yaml"
      [argo-rollouts]="herramientas-gitops/activas/argo-rollouts.yaml"
      [cert-manager]="herramientas-gitops/activas/cert-manager.yaml"
      [grafana]="herramientas-gitops/activas/grafana.yaml"
      [ingress-nginx]="herramientas-gitops/activas/ingress-nginx.yaml"
      [jaeger]="herramientas-gitops/activas/jaeger.yaml"
      [kargo]="herramientas-gitops/activas/kargo.yaml"
      [loki]="herramientas-gitops/activas/loki.yaml"
      [minio]="herramientas-gitops/activas/minio.yaml"
      [kube-prometheus-stack]="herramientas-gitops/activas/prometheus-stack.yaml"
      [gitea]="herramientas-gitops/activas/gitea.yaml"
    )
    for m in "${missing[@]}"; do
      base="$(basename "$m")"
      app_file="${CHART_APP_FILE[$base]:-}"
      if [[ -n "$app_file" && -f "$app_file" ]]; then
        echo "  ↪️  fallback no-op: $base → $app_file" >&2
        sed -i "s#path: charts/vendor/${base}#path: herramientas-gitops/empty#g" "$app_file"
        # añadir allowEmpty si no existe
        if ! grep -q "allowEmpty:" "$app_file"; then
          sed -i "/selfHeal: true/a\\      allowEmpty: true" "$app_file"
        fi
      fi
    done
  fi
fi

echo "[done] charts vendorizados en $VENDOR_DIR"
