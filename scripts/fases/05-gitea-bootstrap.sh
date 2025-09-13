#!/bin/bash

# =============================================================================
# FASE 5 (Bootstrap Gitea):
# - Garantiza Gitea desplegado vía Argo Application activa de gitea
# - Crea repositorio en Gitea y empuja el contenido actual del proyecto
# - Reemplaza placeholders con la URL interna de Gitea
# - Crea la Application de herramientas GitOps (app-of-tools) y espera Sync/Healthy
# - Registra clusters pre/pro en ArgoCD (si CLI disponible)
# =============================================================================

set -euo pipefail

main() {
    log_section "🧩 FASE 5 (Bootstrap Gitea y Argo Apps)"

    # 1) Verificaciones previas
    if ! check_cluster_available "gitops-dev"; then
        log_error "❌ Cluster gitops-dev no está disponible"
        return 1
    fi
    if ! check_argocd_exists; then
        log_error "❌ ArgoCD no está instalado (ejecutar Fase 4 primero)"
        return 1
    fi

    # 2) Instalar Gitea sin repos externos (helm template de chart vendorizado)
    if [[ "${GITOPS_MODE:-online}" == "airgap" ]]; then
      log_info "📦 Instalando Gitea desde chart vendorizado (modo airgap)"
      kubectl get ns gitea >/dev/null 2>&1 || kubectl create ns gitea
      # Usar imagen no-rootless por defecto para mayor compatibilidad en entornos kind
      local gitea_image="${GITEA_IMAGE:-gitea/gitea:1.24.3}"
      if command -v docker >/dev/null 2>&1; then docker pull "$gitea_image" >/dev/null 2>&1 || true; fi
      if command -v kind >/dev/null 2>&1; then kind load docker-image "$gitea_image" --name gitops-dev >/dev/null 2>&1 || true; fi
      helm template gitea "$PROJECT_ROOT/charts/vendor/gitea" \
        --namespace gitea \
        --set image.repository="${gitea_image%:*}" \
        --set image.tag="${gitea_image##*:}" \
        --set persistence.enabled=false \
        --set postgresql.enabled=false \
        --set postgresql-ha.enabled=false \
        --set redis-cluster.enabled=false \
        --set valkey.enabled=false \
        --set gitea.admin.username=admin \
        --set gitea.admin.password=admin1234 \
        --set gitea.config.server.DISABLE_SSH=true \
        --set gitea.config.service.REQUIRE_SIGNIN_VIEW=false \
        --set gitea.config.repository.DEFAULT_PRIVATE=public \
        --set gitea.config.repository.ALLOW_ANONYMOUS_GIT_ACCESS=true \
        --set gitea.config.repository.DISABLE_HTTP_GIT=false \
        | kubectl -n gitea apply -f -
    else
      log_info "📦 Asegurando Application de Gitea (repo externo pinneado)"
      cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitea
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
        repoURL: https://dl.gitea.io/charts
    chart: gitea
    targetRevision: "12.1.3"
    helm:
      values: |
        image:
          repository: gitea/gitea
          tag: 1.24.3
        persistence:
          enabled: false
        postgresql-ha:
          enabled: false
        postgresql:
          enabled: false
        redis-cluster:
          enabled: false
        valkey:
          enabled: false
        gitea:
          admin:
            username: "admin"
            password: "admin1234"
          config:
            server:
              DISABLE_SSH: true
            service:
              REQUIRE_SIGNIN_VIEW: false
            repository:
              DEFAULT_PRIVATE: public
              ALLOW_ANONYMOUS_GIT_ACCESS: true
              DISABLE_HTTP_GIT: false
            database:
              DB_TYPE: sqlite3
              PATH: /data/gitea/gitea.db
            cache:
              ADAPTER: memory
            session:
              PROVIDER: memory
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
      # Forzar Replace para permitir recreación limpia si hay cambios en selectores/imagen
      kubectl -n argocd annotate application gitea argocd.argoproj.io/sync-options=Replace=true --overwrite || true
      kubectl -n argocd annotate application gitea argocd.argoproj.io/refresh=hard --overwrite || true
      # Esperar unos segundos a que Argo procese
      sleep 8
      # Esperar a que el namespace 'gitea' lo cree ArgoCD; si no aparece, crearlo manualmente
      local waited_ns=0; local max_ns_wait=60
      until kubectl get ns gitea >/dev/null 2>&1; do
        sleep 2; waited_ns=$((waited_ns+2)); if (( waited_ns >= max_ns_wait )); then
          log_warning "⚠️ Namespace 'gitea' no fue creado por ArgoCD en ${max_ns_wait}s; creando manualmente"
          kubectl create ns gitea || true
          break
        fi
      done

      # Si existe un deployment con imagen inválida (rootless-rootless), eliminarlo y refrescar
      local bad_img=""
      if kubectl get ns gitea >/dev/null 2>&1; then
        bad_img=$(kubectl -n gitea get deploy gitea -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
      fi
      if echo "$bad_img" | grep -q 'rootless-rootless'; then
        log_warning "⚠️ Detectada imagen inválida en gitea: $bad_img; recreando deployment"
        kubectl -n gitea delete deploy gitea || true
        kubectl -n argocd annotate application gitea argocd.argoproj.io/refresh=hard --overwrite || true
      fi
    fi

  # 3) Esperar a que Gitea esté disponible (servicio HTTP y endpoints listos)
    log_info "⏳ Esperando servicio de Gitea..."
    # Esperar despliegue y endpoints
  # Asegurar namespace antes de esperar por rollout
  kubectl get ns gitea >/dev/null 2>&1 || kubectl create ns gitea >/dev/null 2>&1 || true
  kubectl -n gitea rollout status deploy -l app.kubernetes.io/name=gitea --timeout=600s || true
    # Debug de estado si no disponible
    if ! kubectl -n gitea get deploy -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].status.availableReplicas}' 2>/dev/null | grep -q "1"; then
      log_info "🔎 Estado Gitea (pods):"; kubectl -n gitea get pods -o wide || true
      log_info "🔎 Eventos namespace gitea:"; kubectl -n gitea get events --sort-by=.lastTimestamp | tail -n 20 || true
      # Mostrar describe del primer pod
      local podn; podn=$(kubectl -n gitea get pods -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [[ -n "$podn" ]]; then
        log_info "🔎 Describe pod $podn:"; kubectl -n gitea describe pod "$podn" | tail -n 80 || true
        log_info "🔎 Logs pod $podn (primer contenedor):"; kubectl -n gitea logs "$podn" --tail=80 || true
      fi
  # Fallback: desplegar manifiesto mínimo sin init containers
      log_warning "⚠️ Gitea del chart no está disponible; aplicando fallback mínimo offline"
  # Asegurar namespace antes de aplicar manifiesto de fallback
  kubectl get ns gitea >/dev/null 2>&1 || kubectl create ns gitea || true
  cat <<EOF | kubectl -n gitea apply -f -
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
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          env:
            - name: GITEA__database__DB_TYPE
              value: sqlite3
            - name: GITEA__database__PATH
              value: /data/gitea/gitea.db
            - name: GITEA__security__INSTALL_LOCK
              value: "true"
            - name: GITEA__server__DISABLE_SSH
              value: "true"
            - name: GITEA__service__REQUIRE_SIGNIN_VIEW
              value: "false"
            - name: GITEA__repository__DEFAULT_PRIVATE
              value: public
            - name: GITEA__repository__ALLOW_ANONYMOUS_GIT_ACCESS
              value: "true"
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          emptyDir: {}
EOF
      kubectl -n gitea rollout status deploy/gitea --timeout=300s || true
      # Crear admin por CLI (ignorar si ya existe)
      if kubectl -n gitea get deploy/gitea >/dev/null 2>&1; then
        # Esperar a que exista un pod Ready y usarlo para ejecutar el comando gitea
        local podn=""
        local pod_wait=0; local pod_max_wait=180
        until podn=$(kubectl -n gitea get pods -l app=gitea -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true) && [[ -n "$podn" && $(kubectl -n gitea get pod "$podn" -o jsonpath='{.status.phase}' 2>/dev/null) == "Running" && $(kubectl -n gitea get pod "$podn" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null) == "true" ]]; do
          sleep 3; pod_wait=$((pod_wait+3)); if (( pod_wait >= pod_max_wait )); then
            log_warning "⚠️ No se encontró pod Ready de Gitea en ${pod_max_wait}s; se continuará intentando"
            break
          fi
        done
        if [[ -n "$podn" ]]; then
          log_info "🔧 Creando usuario admin dentro del pod $podn"
          kubectl -n gitea exec "$podn" -- /bin/sh -c "gitea admin user create --username admin --password admin1234 --email admin@example.com --admin --must-change-password=false" || true
        else
          log_warning "⚠️ No se pudo determinar pod para crear admin; omitiendo creación automática"
        fi
      fi
    fi
  # Esperar endpoints del servicio http (más tiempo para inicialización completa)
  local waited=0; local max_wait=600
  until kubectl -n gitea get endpoints gitea-http -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -qE '.'; do
    sleep 3; waited=$((waited+3)); if (( waited >= max_wait )); then break; fi
  done

    # Confirmación estricta de que Gitea está operativo y accesible desde ArgoCD
    log_info "✅ Verificando salud de Gitea (Deployment + Service + Endpoints)"
    if ! kubectl -n gitea get deploy gitea >/dev/null 2>&1; then
      log_error "❌ Deployment gitea no presente"
      return 1
    fi
    if ! kubectl -n gitea get svc gitea-http >/dev/null 2>&1; then
      log_error "❌ Service gitea-http no presente"
      return 1
    fi
    if ! kubectl -n gitea get endpoints gitea-http -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -qE '.'; then
      log_error "❌ Service gitea-http sin endpoints"
      return 1
    fi
    # Esperar endpoints del servicio
    local waited=0; local max_wait=120
    until kubectl -n gitea get endpoints gitea-http -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -qE '.'; do
        sleep 2; waited=$((waited+2)); [[ $waited -ge $max_wait ]] && break
    done

  # 4) Configurar port-forward temporal para Gitea y validar API
    log_info "🔌 Iniciando port-forward temporal a Gitea (localhost:8088)"
  # Preferir Service estable si existe, si no usar gitea-http
  local pf_target="svc/gitea-http"
  if kubectl -n gitea get svc gitea-http-stable >/dev/null 2>&1; then
    pf_target="svc/gitea-http-stable"
  fi
  kubectl -n gitea port-forward $pf_target 8088:3000 >/tmp/gitea-pf.log 2>&1 &
  local pf_pid=$!
    # Esperar a que responda la API
  waited=0; max_wait=300
  until curl -fsS http://localhost:8088/api/v1/version >/dev/null 2>&1; do
    sleep 3; waited=$((waited+3)); if (( waited >= max_wait )); then
      log_warning "⚠️ Gitea API no respondió en ${max_wait}s; se continuará con intentos posteriores"
      break
    fi
  done

    local gitea_user="admin" gitea_pass="admin1234" repo_name="gitops-infra"
    local api="http://localhost:8088/api/v1"

    # Intento de autenticación: admin/admin; si falla probamos gitea/gitea
    log_info "📚 Asegurando repositorio en Gitea: $repo_name"
    # Comprobar si existe
    # Reintentos para creación de repo vía API con backoff
    local repo_created=false
    for attempt in 1 2 3; do
      if curl -fsS -u "$gitea_user:$gitea_pass" "$api/repos/$gitea_user/$repo_name" >/dev/null 2>&1; then
        repo_created=true
        break
      fi
      if curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1; then
        repo_created=true
        break
      fi
      log_info "ℹ️ Intento $attempt: repo no disponible todavía, reintentando en 5s..."
      sleep 5
    done
    if ! $repo_created; then
        # Intentar con admin/admin crear repo público; fallback a gitea/gitea
        if ! curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
            -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1; then
        gitea_user="gitea"; gitea_pass="gitea"
            log_warning "⚠️ admin/admin no válido; probando gitea/gitea"
            # Rechequear existencia con nuevo usuario
            if ! curl -fsS -u "$gitea_user:$gitea_pass" "$api/repos/$gitea_user/$repo_name" >/dev/null 2>&1; then
        curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
          -X POST "$api/user/repos" -d "{\"name\":\"$repo_name\",\"private\":false}" >/dev/null 2>&1 || true
            fi
        fi
    else
        log_info "✅ Repositorio ya existe: $gitea_user/$repo_name"
    fi

    # 5) Empujar contenido local al nuevo remoto (primera publicación)
    local remote_url="http://$gitea_user:$gitea_pass@localhost:8088/$gitea_user/$repo_name.git"
  log_info "🔁 Publicando repositorio actual en Gitea..."
    (
        set -e
        cd "$PROJECT_ROOT"
        git init >/dev/null 2>&1 || true
        git branch -M main >/dev/null 2>&1 || true
        if git remote get-url gitea >/dev/null 2>&1; then
            git remote set-url gitea "$remote_url"
        else
            git remote add gitea "$remote_url"
        fi
        git add -A
        git commit -m "feat(bootstrap): publicación inicial en Gitea" >/dev/null 2>&1 || true
        # Reintentar push hasta que Gitea acepte la conexión
        for i in 1 2 3; do
          git push -u gitea main >/dev/null 2>&1 && break || (sleep 3)
        done
    )

    # 5b) Forzar repo público por si la instancia requiere autenticación por defecto
    log_info "🔓 Asegurando visibilidad pública del repo..."
    curl -fsS -u "$gitea_user:$gitea_pass" -H 'Content-Type: application/json' \
        -X PATCH "$api/repos/$gitea_user/$repo_name" -d '{"private": false}' >/dev/null 2>&1 || true

    # 6) Verificar charts vendorizados requeridos (no usamos repos externos)
    if [[ -x "$PROJECT_ROOT/scripts/utilidades/vendor-charts.sh" ]]; then
        log_info "🔍 Verificando charts vendorizados requeridos..."
        "$PROJECT_ROOT/scripts/utilidades/vendor-charts.sh"
    fi

    # 7) Reemplazar placeholders de repoURL con la URL interna del servicio Gitea (para uso dentro del cluster)
    # IMPORTANTE: el Service gitea-http es headless; creamos un Service estable ClusterIP para endpoints Ready-only
  log_info "🔧 Creando Service estable para Gitea (ClusterIP)"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: gitea-http-stable
  namespace: gitea
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: gitea
    app.kubernetes.io/instance: gitea
  ports:
  - name: http
    port: 3000
    targetPort: 3000
EOF

  # Si ya había un port-forward activo, reiniciarlo hacia el service estable
  if ps -p "$pf_pid" >/dev/null 2>&1; then
    kill "$pf_pid" >/dev/null 2>&1 || true
    sleep 1
    kubectl -n gitea port-forward svc/gitea-http-stable 8088:3000 >/tmp/gitea-pf.log 2>&1 &
    pf_pid=$!
  fi

    # Usar el service estable para URLs internas
    local internal_repo_url="http://gitea-http-stable.gitea.svc.cluster.local:3000/$gitea_user/$repo_name.git"
    log_info "📝 Sustituyendo URLs de repo hacia: $internal_repo_url"
    # Placeholder genérico
    find "$PROJECT_ROOT" -type f -name "*.yaml" -print0 \
      | xargs -0 -I{} sed -i "s|http://gitea-service/your-user/your-repo.git|$internal_repo_url|g" {}
    # Variantes conocidas sin puerto, con hostname antiguo y/o ruta con 'gitea/'
    grep -RIl "http://gitea-http\.gitea\.svc\.cluster\.local" "$PROJECT_ROOT" 2>/dev/null \
      | xargs -r sed -i \
        -e "s|http://gitea-http.gitea.svc.cluster.local/$gitea_user/$repo_name.git|$internal_repo_url|g" \
        -e "s|http://gitea-http.gitea.svc.cluster.local/gitea/$repo_name.git|$internal_repo_url|g" \
        -e "s|http://gitea-http.gitea.svc.cluster.local:3000/$gitea_user/$repo_name.git|$internal_repo_url|g"
    # Variantes sobre hostname estable pero sin puerto explícito
    grep -RIl "http://gitea-http-stable\.gitea\.svc\.cluster\.local" "$PROJECT_ROOT" 2>/dev/null \
      | xargs -r sed -i \
        -e "s|http://gitea-http-stable.gitea.svc.cluster.local/$gitea_user/$repo_name.git|$internal_repo_url|g"

    # 7b) Publicar cambios de sustitución (asegura que Gitea contiene manifests correctos antes de Argo)
    log_info "🔁 Publicando cambios de placeholders en Gitea..."
    (
        set -e
        cd "$PROJECT_ROOT"
        git add -A
        git commit -m "chore(bootstrap): sustituye URLs a Gitea interno (:3000)" >/dev/null 2>&1 || true
        git push -u gitea main >/dev/null 2>&1 || true
    )

    # 6c) (Nuevo) Pin de versiones Helm: fija targetRevision a la última estable antes de aplicar herramientas
    if [[ -x "$PROJECT_ROOT/scripts/utilidades/pin-helm-versions.sh" ]]; then
        log_info "📌 Pinneando versiones de charts Helm (latest estable) antes del despliegue..."
        if "$PROJECT_ROOT/scripts/utilidades/pin-helm-versions.sh" --write >/dev/null 2>&1; then
            (
                set -e
                cd "$PROJECT_ROOT"
                if ! git diff --quiet; then
                    git add -A
                    git commit -m "chore(helm): pin charts a versiones estables antes de aplicar herramientas" >/dev/null 2>&1 || true
                    git push -u gitea main >/dev/null 2>&1 || true
                    log_success "✅ Charts pinneados y publicados en Gitea"
                else
                    log_info "ℹ️ No hay cambios de pin de versiones"
                fi
            )
        else
            log_warning "⚠️ No se pudo pinnear versiones de charts (verifica conectividad helm)"
        fi
    else
        log_info "ℹ️ Script de pin de versiones no encontrado; omitiendo"
    fi

    # 6d) (Nuevo) Vendor de charts críticos para evitar dependencias externas (loki, kargo)
    if [[ -x "$PROJECT_ROOT/scripts/utilidades/vendor-charts.sh" ]]; then
        log_info "📦 Vendorizando charts críticos (loki, kargo)..."
        if "$PROJECT_ROOT/scripts/utilidades/vendor-charts.sh" >/dev/null 2>&1; then
            (
                set -e
                cd "$PROJECT_ROOT"
                if ! git diff --quiet; then
                    git add -A
                    git commit -m "chore(charts): vendor loki/kargo para despliegue offline reproducible" >/dev/null 2>&1 || true
                    git push -u gitea main >/dev/null 2>&1 || true
                    log_success "✅ Charts vendorizados y publicados"
                else
                    log_info "ℹ️ No hay novedades de vendor"
                fi
            )
        else
            log_warning "⚠️ Vendor de charts no completado (revisa red/repos)"
        fi
    fi

    # 8) Validación previa: conectividad y acceso git al repo desde el cluster
    local svc_url="http://gitea-http-stable.gitea.svc.cluster.local:3000"
    if kubectl -n argocd run --rm -i gitea-check --image=curlimages/curl:8.10.1 --restart=Never -- \
        -sSf ${svc_url}/api/v1/version >/dev/null 2>&1; then
        log_success "✅ Conectividad HTTP a Gitea OK"
    else
        log_error "❌ Conectividad HTTP a Gitea falló; no se aplicarán Applications"
        return 1
    fi
    # Verificar git ls-remote (acceso al repo) desde el cluster (sin y con credenciales)
    local repo_http_url="${svc_url}/${gitea_user}/${repo_name}.git"
    if kubectl -n argocd run --rm -i gitea-git-check --image=alpine/git:latest --restart=Never -- \
        ls-remote "$repo_http_url" >/dev/null 2>&1; then
        log_success "✅ Acceso git anónimo al repositorio OK"
    else
        log_warning "⚠️ Acceso git anónimo falló; configurando credenciales en ArgoCD"
        # Crear Secret de repositorio en ArgoCD
        cat <<EOF | kubectl apply -n argocd -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-gitea-gitops-infra
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  url: ${repo_http_url}
  username: ${gitea_user}
  password: ${gitea_pass}
  type: git
EOF
        # Reintentar ls-remote con credenciales embebidas
        if kubectl -n argocd run --rm -i gitea-git-check --image=alpine/git:latest --restart=Never -- \
            ls-remote "http://${gitea_user}:${gitea_pass}@${svc_url#http://}/${gitea_user}/${repo_name}.git" >/dev/null 2>&1; then
            log_success "✅ Acceso git con credenciales OK (ls-remote)"
        else
            log_error "❌ No se pudo acceder al repositorio ni con credenciales: $repo_http_url"
            return 1
        fi
    fi

    # 8b) Validación de contenido del repo: deben existir manifests para App-of-Tools
    log_info "🔎 Verificando contenido esencial en el repositorio remoto..."
    if curl -fsS -u "$gitea_user:$gitea_pass" \
         "$api/repos/$gitea_user/$repo_name/contents/argo-apps/aplicacion-de-herramientas-gitops.yaml?ref=main" >/dev/null 2>&1 && \
       curl -fsS -u "$gitea_user:$gitea_pass" \
         "$api/repos/$gitea_user/$repo_name/contents/herramientas-gitops/activas?ref=main" >/dev/null 2>&1; then
        log_success "✅ Repo contiene App-of-Tools y carpeta de herramientas activas"
    else
        log_error "❌ El repo no contiene los manifests requeridos (argo-apps/ y herramientas-gitops/activas)."
        return 1
    fi

    # 9) Crear la Application que apunta a herramientas-gitops/activas en el repositorio Gitea (app-of-tools)
    local app_tools="$PROJECT_ROOT/argo-apps/aplicacion-de-herramientas-gitops.yaml"
    if [[ -f "$app_tools" ]]; then
        log_info "🚀 Aplicando Application de herramientas GitOps (app-of-tools)"
        kubectl apply -f "$app_tools"
        # Forzar refresh/sync para que recoja los cambios recién publicados en Gitea
        log_info "🔄 Forzando refresh/sync de app-of-tools-gitops"
        # Intentar con CLI si está disponible (autologin incluido en setup_argocd_cli)
        setup_argocd_cli || true
        if command -v argocd >/dev/null 2>&1; then
            argocd app sync app-of-tools-gitops --prune --timeout 300 >/dev/null 2>&1 || true
        fi
        # Anotar recurso para refresh hard como respaldo
        kubectl -n argocd annotate applications.argoproj.io/app-of-tools-gitops \
            argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
    else
        log_warning "⚠️ No se encontró $app_tools"
    fi

    # 9) Registrar clusters pre/pro en ArgoCD (si CLI disponible)
    register_additional_clusters || true

    # 10) Esperar a que todas las Applications estén en Sync/Healthy
    wait_all_apps_healthy argocd 600 || true

    # 11) Limpiar port-forward
    if ps -p "$pf_pid" >/dev/null 2>&1; then
        kill "$pf_pid" >/dev/null 2>&1 || true
    fi

    log_success "✅ Fase 5 (Bootstrap Gitea y Argo Apps) completada"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
