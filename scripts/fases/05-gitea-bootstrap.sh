#!/bin/bash

# FASE 5 (Bootstrap Gitea) - Clean single-file implementation
set -euo pipefail

# Ensure confirmar exists
if ! declare -f confirmar >/dev/null 2>&1; then
  confirmar() { return 0; }
fi

log_section "🧩 FASE 5 (Bootstrap Gitea)"

main() {
  if ! check_cluster_available "gitops-dev"; then log_error "Cluster gitops-dev no disponible"; return 1; fi
  if ! check_argocd_exists; then log_error "ArgoCD no instalado"; return 1; fi

  kubectl get ns gitea >/dev/null 2>&1 || kubectl create ns gitea || true

  cat <<'YAML' | kubectl -n gitea apply -f -
apiVersion: v1
kind: Service
metadata:
  name: gitea-http
  labels:
    app: gitea
spec:
  selector:
    app: gitea
  ports:
    - name: http
      port: 3000
      targetPort: 3000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitea
  labels:
    app: gitea
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitea
  template:
    metadata:
      labels:
        app: gitea
    spec:
      containers:
        - name: gitea
          image: ${GITEA_IMAGE:-gitea/gitea:1.22.3-rootless}
          ports:
            - containerPort: 3000
          env:
            - name: GITEA__database__DB_TYPE
              value: sqlite3
            - name: GITEA__database__PATH
              value: /data/gitea/gitea.db
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          emptyDir: {}
YAML

  # wait pod Ready
  local podn=""; local wait=0; local max=120
  until podn=$(kubectl -n gitea get pods -l app=gitea -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true) && [[ -n "$podn" ]] && kubectl -n gitea get pod "$podn" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Running; do
    sleep 2; wait=$((wait+2)); if (( wait >= max )); then break; fi
  done

  # Use in-pod HTTP to avoid host port forwarding and make behavior deterministic
  local repo="gitops-infra"; local created=false
  if [[ -z "$podn" ]]; then
    log_error "No hay pod de gitea disponible"; return 1
  fi

  # Wait until in-pod HTTP API responds
  local ready_wait=0; local ready_max=120
  until kubectl -n gitea exec "$podn" -- sh -c "curl -sS http://127.0.0.1:3000/api/v1/version >/dev/null 2>&1" || (( ready_wait >= ready_max )); do
    sleep 2; ready_wait=$((ready_wait+2))
  done

  # Prefer deterministic users: bootstrap (admin), then automation
  for candidate in "bootstrap:bootstrap" "automation:automation"; do
    u="${candidate%%:*}"; p="${candidate#*:}"
    if kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u ${u}:${p} http://127.0.0.1:3000/api/v1/user >/dev/null 2>&1"; then
      user="$u"; pass="$p"; break
    fi
  done

  # If no user, create bootstrap admin deterministically
  if [[ -z "${user:-}" ]]; then
    kubectl -n gitea exec "$podn" -- sh -c "gitea admin user create --username bootstrap --password bootstrap --email bootstrap@example.com --admin --must-change-password=false" >/dev/null 2>&1 || true
    if kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u bootstrap:bootstrap http://127.0.0.1:3000/api/v1/user >/dev/null 2>&1"; then
      user="bootstrap"; pass="bootstrap"
    fi
  fi

  if [[ -z "${user:-}" ]]; then
    log_error "No se encontraron/crearon credenciales válidas para Gitea"; return 1
  fi

  # Check repo existence and create if needed
  if kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u ${user}:${pass} http://127.0.0.1:3000/api/v1/repos/${user}/${repo} >/dev/null 2>&1"; then
    created=true
  fi

  if ! $created; then
    kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u ${user}:${pass} -H 'Content-Type: application/json' -X POST http://127.0.0.1:3000/api/v1/user/repos -d '{\"name\":\"${repo}\",\"private\":false}' >/dev/null 2>&1" || true
    if kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u ${user}:${pass} http://127.0.0.1:3000/api/v1/repos/${user}/${repo} >/dev/null 2>&1"; then
      created=true
    fi
  fi

  # If still not created and we are bootstrap admin, create automation user and repo
  if ! $created && [[ "${user}" == "bootstrap" ]]; then
    kubectl -n gitea exec "$podn" -- sh -c "gitea admin user create --username automation --password automation --email automation@example.com --must-change-password=false" >/dev/null 2>&1 || true
    kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u bootstrap:bootstrap -H 'Content-Type: application/json' -X POST http://127.0.0.1:3000/api/v1/admin/users/automation/repos -d '{\"name\":\"${repo}\",\"private\":false}' >/dev/null 2>&1" || true
    if kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u automation:automation http://127.0.0.1:3000/api/v1/repos/automation/${repo} >/dev/null 2>&1"; then
      created=true; user="automation"; pass="automation"
    fi
  fi

  if ! $created; then log_error "No se pudo crear el repo en Gitea (in-pod)"; return 1; fi

  # Push repository to created remote (attempt, non-fatal)
  (cd "$PROJECT_ROOT" && git init >/dev/null 2>&1 || true; git branch -M main >/dev/null 2>&1 || true; git remote remove gitea >/dev/null 2>&1 || true; git remote add gitea "http://${user}:${pass}@127.0.0.1:3000/${user}/${repo}.git" >/dev/null 2>&1 || true; git add -A; git commit -m "bootstrap" >/dev/null 2>&1 || true; git push -u gitea main >/dev/null 2>&1 || true)

  cat <<EOF | kubectl apply -n gitea -f -
apiVersion: v1
kind: Service
metadata:
  name: gitea-http-stable
spec:
  type: ClusterIP
  selector:
    app: gitea
  ports:
    - name: http
      port: 3000
      targetPort: 3000
EOF

  # Wait briefly for endpoints to appear so in-cluster DNS works for ArgoCD
  local wait_ep=0; until kubectl -n gitea get endpoints gitea-http-stable -o jsonpath='{.subsets}' 2>/dev/null | grep -q . || (( wait_ep >= 30 )); do
    sleep 1; wait_ep=$((wait_ep+1));
  done

  register_additional_clusters || true
  wait_all_apps_healthy argocd 600 || true

  log_success "Fase 05 completada"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

