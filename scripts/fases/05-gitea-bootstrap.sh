#!/bin/bash

# Active installer phase removed: Gitea is handled as an external dependency.
# See the preserved implementation in `scripts/fases/obsolete/05-gitea-bootstrap.sh`.

echo "[INFO] fase-05 (gitea bootstrap) has been removed from the active installer."
echo "See: scripts/fases/obsolete/05-gitea-bootstrap.sh"
exit 0
#!/bin/bash

# This file has been archived in `/home/asanchez/gh-gitops-infra/gh-gitops-infra/scripts/fases/obsolete/05-gitea-bootstrap.sh`.
# Gitea is now treated as an external dependency and should be installed
# outside the automated phase-runner. The preserved implementation is available
# under `/home/asanchez/gh-gitops-infra/gh-gitops-infra/scripts/fases/obsolete/` for reference.

echo "[INFO] fase-05 has been archived. See /home/asanchez/gh-gitops-infra/gh-gitops-infra/scripts/fases/obsolete/05-gitea-bootstrap.sh"
exit 0
#!/bin/bash

# This file has been archived in `scripts/fases/obsolete/05-gitea-bootstrap.sh`.
# Gitea is now treated as an external dependency and should be installed
# outside the automated phase-runner. The preserved implementation is available
# under `scripts/fases/obsolete/` for reference.

echo "[INFO] fase-05 has been archived. See scripts/fases/obsolete/05-gitea-bootstrap.sh"
exit 0
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

  # Create an initial README.md inside the repository via Gitea API (in-pod)
  local readme_content
  readme_content="# gitops-infra\n\nBootstrap repository created by instalar.sh fase-05 on $(date -u +%Y-%m-%dT%H:%M:%SZ)\n"
  local readme_b64
  readme_b64=$(printf "%s" "$readme_content" | base64 | tr -d '\n')
  kubectl -n gitea exec "$podn" -- sh -c "curl -sS -u ${user}:${pass} -H 'Content-Type: application/json' -X POST http://127.0.0.1:3000/api/v1/repos/${user}/${repo}/contents/README.md -d '{\"message\":\"bootstrap\",\"content\":\"${readme_b64}\",\"branch\":\"main\"}' >/dev/null 2>&1 || true"

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


  # Create a lightweight ArgoCD Application so Gitea appears in the ArgoCD UI
  # Use git remote origin if available; otherwise point to in-cluster Gitea (repo may not exist yet)
  repo_url="$(git -C "${PWD}" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$repo_url" ]]; then
    # Normalize SSH url to https if needed
    if [[ "$repo_url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
      host="${BASH_REMATCH[1]}"; path="${BASH_REMATCH[2]}"; repo_url="https://$host/$path.git"
    fi
  else
    repo_url="http://gitea-http-stable.gitea.svc.cluster.local:3000/admin/gitops-infra.git"
  fi

  log_info "Creando Application 'tool-gitea' en ArgoCD apuntando a $repo_url (path: herramientas-gitops/activas)"
  cat <<EOF | kubectl apply -n argocd -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tool-gitea
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "$repo_url"
    targetRevision: HEAD
    path: herramientas-gitops/activas
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
EOF

  log_info "Application 'tool-gitea' creada (si ArgoCD puede acceder al repo, aparecerá en la UI)."

  log_success "Fase 05 completada"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

