#!/bin/bash

set -euo pipefail

echo "[RESET] Iniciando limpieza del entorno GitOps local..."

# Parar port-forwards locales (rangos 8080-8091 y conocidos)
echo "[RESET] Deteniendo port-forwards en puertos 8080-8091..."
for p in $(seq 8080 8091); do
  if lsof -t -i :"$p" >/dev/null 2>&1; then
    lsof -t -i :"$p" | xargs -r kill -9 || true
  fi
done

# Borrar Applications de ArgoCD si el CRD existe
if kubectl api-resources 2>/dev/null | grep -q "applications.argoproj.io"; then
  echo "[RESET] Eliminando Applications en argocd..."
  kubectl -n argocd delete application --all --ignore-not-found=true || true
  kubectl -n argocd delete applicationset --all --ignore-not-found=true || true
fi

# Eliminar namespaces de herramientas
NS=(
  argocd
  gitea
  monitoring
  observability
  argo-rollouts
  argo-workflows
  argo-events
  kargo
  storage
  ingress-nginx
  cert-manager
)
echo "[RESET] Eliminando namespaces: ${NS[*]}"
kubectl delete ns "${NS[@]}" --ignore-not-found=true || true

# Eliminar CRDs de ArgoCD si existen
echo "[RESET] Eliminando CRDs de ArgoCD (si existen)..."
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io 2>/dev/null || true

# Eliminar clusters kind
for c in gitops-dev gitops-pre gitops-pro; do
  if kind get clusters 2>/dev/null | grep -q "^${c}$"; then
    echo "[RESET] Eliminando cluster kind: $c"
    kind delete cluster --name "$c" || true
  fi
done

# Opcional: purgar binarios instalados por el instalador
if [[ "${PURGE_BINARIES:-false}" == "true" ]]; then
  echo "[RESET] Purga de binarios en /usr/local/bin (kind, argocd)"
  sudo rm -f /usr/local/bin/kind /usr/local/bin/argocd || true
fi

echo "[RESET] Limpieza completada."

