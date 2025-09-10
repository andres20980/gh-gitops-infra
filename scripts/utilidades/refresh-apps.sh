#!/usr/bin/env bash

set -euo pipefail

NS="argocd"
MODE="nonok"   # nonok|all
DO_SYNC=false
WAIT=false
ATTEMPTS=10
TIMEOUT="300"

usage() {
  echo "Uso: $0 [--all] [--sync] [--wait] [--namespace <ns>] [--timeout <s>]" >&2
  echo "  --all         Refresca TODAS las Applications (por defecto solo no OK)" >&2
  echo "  --sync        Además de refresh, intenta 'sync' (CLI argocd si disponible)" >&2
  echo "  --wait        Espera hasta que queden Synced+Healthy (intentos: $ATTEMPTS)" >&2
  echo "  --namespace   Namespace de ArgoCD (defecto: argocd)" >&2
  echo "  --timeout     Timeout para sync en segundos (defecto: 300)" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) MODE="all"; shift ;;
    --sync) DO_SYNC=true; shift ;;
    --wait) WAIT=true; shift ;;
    --namespace|-n) NS="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage; exit 1 ;;
  esac
done

# Comprobar acceso a cluster
if ! kubectl get ns "$NS" >/dev/null 2>&1; then
  echo "ERROR: No se puede acceder al namespace '$NS'. ¿Cluster activo?" >&2
  exit 1
fi

# Obtener lista de apps objetivo
apps=()
if [[ "$MODE" == "all" ]]; then
  mapfile -t apps < <(kubectl get applications -n "$NS" -o json \
    | jq -r '.items[].metadata.name' 2>/dev/null)
else
  mapfile -t apps < <(kubectl get applications -n "$NS" -o json \
    | jq -r '.items[] | select((.status.sync.status // "Unknown") != "Synced" or (.status.health.status // "Unknown") != "Healthy") | .metadata.name' 2>/dev/null)
fi

if [[ ${#apps[@]} -eq 0 ]]; then
  if [[ "$MODE" == "all" ]]; then
    echo "No hay Applications en '$NS'."
  else
    echo "Todas las Applications están Synced+Healthy. Nada que refrescar."
  fi
  exit 0
fi

echo "Refrescando ${#apps[@]} Applications en '$NS' (modo: $MODE)" >&2
for app in "${apps[@]}"; do
  echo "- refresh: $app" >&2
  kubectl -n "$NS" annotate applications.argoproj.io/"$app" \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
  # Asegurar opciones de sync idempotentes
  kubectl -n "$NS" annotate applications.argoproj.io/"$app" \
    argocd.argoproj.io/sync-options=Replace=true --overwrite >/dev/null 2>&1 || true
done

if $DO_SYNC; then
  if command -v argocd >/dev/null 2>&1; then
    # Intentar autologin si hay password inicial
    PASS=$(kubectl -n "$NS" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
    if [[ -n "$PASS" ]]; then
      argocd login 127.0.0.1:8080 --insecure --username admin --password "$PASS" >/dev/null 2>&1 || true
    fi
    for app in "${apps[@]}"; do
      echo "- sync: $app" >&2
      argocd app sync "$app" --timeout "$TIMEOUT" || true
    done
  else
    # Sin CLI: activar auto-sync y re-anotar
    for app in "${apps[@]}"; do
      kubectl -n "$NS" patch application "$app" --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' >/dev/null 2>&1 || true
      kubectl -n "$NS" annotate application "$app" argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
    done
  fi
fi

show_state() {
  kubectl get applications -n "$NS" -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status --no-headers || true
}

echo "Hecho. Estado actual:" >&2
show_state

if $WAIT; then
  i=0
  while [[ $i -lt $ATTEMPTS ]]; do
    # Recalcular no OK
    mapfile -t nonok < <(kubectl get applications -n "$NS" -o json \
      | jq -r '.items[] | select((.status.sync.status // "Unknown") != "Synced" or (.status.health.status // "Unknown") != "Healthy") | .metadata.name' 2>/dev/null)
    total=$(kubectl get applications -n "$NS" -o json | jq -r '.items | length' 2>/dev/null || echo 0)
    ok=$((total - ${#nonok[@]}))
    echo "[espera] OK: $ok/$total (pendientes: ${#nonok[@]})" >&2
    [[ ${#nonok[@]} -eq 0 ]] && break
    sleep 8
    i=$((i+1))
    # Forzar refresh en las pendientes
    for app in "${nonok[@]}"; do
      kubectl -n "$NS" annotate applications.argoproj.io/"$app" argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
    done
  done
  echo "Estado final:" >&2
  show_state
fi
