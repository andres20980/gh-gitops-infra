#!/bin/bash

# ============================================================================
# OPTIMIZADOR DE HERRAMIENTAS GITOPS - Seguir mejores prácticas
# ============================================================================
# Actualiza las configuraciones de cada herramienta según documentación oficial
# Incluye valores optimizados para entorno de desarrollo/producción
# ============================================================================

set -euo pipefail

# Cargar módulo base
OPTIMIZADOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./base.sh
source "$OPTIMIZADOR_SCRIPT_DIR/base.sh"

# ============================================================================
# CONFIGURACIONES OPTIMIZADAS POR HERRAMIENTA
# ============================================================================

optimizar_prometheus_stack() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/prometheus-stack.yaml"
    
    log_info "🔧 Optimizando Prometheus Stack según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-stack
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-prometheus-stack
    targetRevision: 75.15.2
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Deshabilitar Grafana (tenemos instancia separada)
        grafana:
          enabled: false
          
        # Prometheus optimizado para desarrollo
        prometheus:
          prometheusSpec:
            # Recursos optimizados
            resources:
              limits:
                cpu: 1000m
                memory: 2Gi
              requests:
                cpu: 500m
                memory: 1Gi
            
            # Retención optimizada para desarrollo
            retention: 15d
            retentionSize: 8GB
            
            # Storage class automático
            storageSpec:
              volumeClaimTemplate:
                spec:
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 10Gi
            
            # Configuración de scraping
            scrapeInterval: 30s
            scrapeTimeout: 10s
            evaluationInterval: 30s
            
            # Habilitar servicios adicionales
            serviceMonitorSelectorNilUsesHelmValues: false
            podMonitorSelectorNilUsesHelmValues: false
            ruleSelectorNilUsesHelmValues: false
            
            # Configuración de red
            portName: web
            
        # AlertManager optimizado
        alertmanager:
          alertmanagerSpec:
            resources:
              limits:
                cpu: 200m
                memory: 256Mi
              requests:
                cpu: 100m
                memory: 128Mi
            
            # Storage para AlertManager
            storage:
              volumeClaimTemplate:
                spec:
                  accessModes: ["ReadWriteOnce"]
                  resources:
                    requests:
                      storage: 2Gi
        
        # Node Exporter optimizado
        nodeExporter:
          enabled: true
          resources:
            limits:
              cpu: 200m
              memory: 180Mi
            requests:
              cpu: 100m
              memory: 90Mi
          
        # Kube State Metrics optimizado
        kubeStateMetrics:
          enabled: true
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
              
        # Configuración del Operator
        prometheusOperator:
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de admisión
          admissionWebhooks:
            enabled: true
            patch:
              enabled: true
              resources:
                limits:
                  cpu: 200m
                  memory: 256Mi
                requests:
                  cpu: 100m
                  memory: 128Mi
        
        # Configuraciones de componentes adicionales
        coreDns:
          enabled: true
        kubeDns:
          enabled: false
        kubeApiServer:
          enabled: true
        kubeControllerManager:
          enabled: true
        kubeScheduler:
          enabled: true
        kubeProxy:
          enabled: true
        kubeEtcd:
          enabled: true
          
        # Configuración global
        global:
          rbac:
            create: true
            pspEnabled: false
          
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Prometheus Stack optimizado"
}

optimizar_grafana() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/grafana.yaml"
    
    log_info "🔧 Optimizando Grafana según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: grafana
    targetRevision: 9.3.1
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración administrativa
        adminUser: admin
        adminPassword: admin123
        
        # Configuración de recursos
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
        
        # Persistencia habilitada
        persistence:
          enabled: true
          type: pvc
          size: 2Gi
          accessModes:
            - ReadWriteOnce
        
        # Configuración de servicio
        service:
          type: ClusterIP
          port: 80
          targetPort: 3000
        
        # Ingress para acceso externo
        ingress:
          enabled: true
          ingressClassName: nginx
          annotations:
            nginx.ingress.kubernetes.io/rewrite-target: /
          hosts:
            - grafana.local
          tls: []
        
        # Configuración de datasources
        datasources:
          datasources.yaml:
            apiVersion: 1
            datasources:
            - name: Prometheus
              type: prometheus
              url: http://prometheus-stack-kube-prom-prometheus:9090
              access: proxy
              isDefault: true
            - name: Loki
              type: loki
              url: http://loki:3100
              access: proxy
            - name: Jaeger
              type: jaeger
              url: http://jaeger-query:16686
              access: proxy
        
        # Dashboards automáticos
        dashboardProviders:
          dashboardproviders.yaml:
            apiVersion: 1
            providers:
            - name: 'default'
              orgId: 1
              folder: ''
              type: file
              disableDeletion: false
              editable: true
              options:
                path: /var/lib/grafana/dashboards/default
        
        # Dashboards predefinidos
        dashboards:
          default:
            kubernetes-cluster-monitoring:
              gnetId: 7249
              revision: 1
              datasource: Prometheus
            kubernetes-pod-monitoring:
              gnetId: 6417
              revision: 1
              datasource: Prometheus
            node-exporter:
              gnetId: 1860
              revision: 29
              datasource: Prometheus
            
        # Configuración de plugins
        plugins:
          - grafana-piechart-panel
          - grafana-worldmap-panel
          - grafana-clock-panel
          - vonage-status-panel
        
        # Configuración de seguridad
        grafana.ini:
          server:
            root_url: http://grafana.local
          security:
            admin_user: admin
            admin_password: admin123
          auth.anonymous:
            enabled: true
            org_role: Viewer
          log:
            mode: console
            level: info
        
        # ServiceAccount
        serviceAccount:
          create: true
          autoMount: true
          
        # Configuración RBAC
        rbac:
          create: true
          pspEnabled: false
          
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Grafana optimizado"
}

optimizar_loki() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/loki.yaml"
    
    log_info "🔧 Optimizando Loki según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: loki
    targetRevision: 6.34.0
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Modo de despliegue
        deploymentMode: SingleBinary
        
        # Configuración de Loki
        loki:
          auth_enabled: false
          
          # Configuración del servidor
          server:
            http_listen_port: 3100
            grpc_listen_port: 9095
            
          # Configuración de ingesta
          ingester:
            lifecycler:
              ring:
                kvstore:
                  store: inmemory
                replication_factor: 1
            chunk_idle_period: 1h
            chunk_retain_period: 30s
            max_transfer_retries: 0
            wal:
              dir: /var/loki/wal
              
          # Configuración de schema
          schema_config:
            configs:
              - from: 2020-10-24
                store: boltdb-shipper
                object_store: filesystem
                schema: v11
                index:
                  prefix: index_
                  period: 24h
          
          # Configuración de storage
          storage_config:
            boltdb_shipper:
              active_index_directory: /var/loki/boltdb-shipper-active
              cache_location: /var/loki/boltdb-shipper-cache
              cache_ttl: 24h
              shared_store: filesystem
            filesystem:
              directory: /var/loki/chunks
          
          # Configuración de compactor
          compactor:
            working_directory: /var/loki/boltdb-shipper-compactor
            shared_store: filesystem
            compaction_interval: 10m
            retention_enabled: true
            retention_delete_delay: 2h
            retention_delete_worker_count: 150
          
          # Límites
          limits_config:
            retention_period: 744h  # 31 days
            enforce_metric_name: false
            reject_old_samples: true
            reject_old_samples_max_age: 168h
            ingestion_rate_mb: 8
            ingestion_burst_size_mb: 16
            per_stream_rate_limit: 3MB
            per_stream_rate_limit_burst: 15MB
            max_streams_per_user: 10000
            max_line_size: 256000
            
          # Configuración de query
          query_range:
            results_cache:
              cache:
                embedded_cache:
                  enabled: true
                  max_size_mb: 100
        
        # Configuración de single binary
        singleBinary:
          replicas: 1
          resources:
            limits:
              cpu: 500m
              memory: 1Gi
            requests:
              cpu: 250m
              memory: 512Mi
          
          # Persistencia
          persistence:
            enabled: true
            size: 5Gi
            storageClass: ""
            accessModes:
              - ReadWriteOnce
        
        # Configuración de servicio
        gateway:
          enabled: false
          
        # Configuración de test
        test:
          enabled: false
          
        # Configuración de monitoreo
        monitoring:
          selfMonitoring:
            enabled: false
            grafanaAgent:
              installOperator: false
          
        # Configuración de logs
        lokiCanary:
          enabled: false
          
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Loki optimizado"
}

optimizar_cert_manager() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/cert-manager.yaml"
    
    log_info "🔧 Optimizando Cert-Manager según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: v1.18.2
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Instalar CRDs automáticamente
        crds:
          enabled: true
          keep: true
        
        # Configuración global
        global:
          logLevel: 2
          leaderElection:
            namespace: cert-manager
          
        # Configuración del controlador
        controller:
          replicaCount: 1
          
          # Recursos optimizados
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración de pods
          podDisruptionBudget:
            enabled: true
            minAvailable: 1
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
          
          # Configuración de contenedor
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
          
          # Configuración de servicio
          serviceAccount:
            create: true
            automountServiceAccountToken: true
          
        # Configuración del webhook
        webhook:
          replicaCount: 1
          
          # Recursos del webhook
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 64Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
          
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
          
          # Configuración de red
          networkPolicy:
            enabled: false
            
        # Configuración del CA Injector
        cainjector:
          enabled: true
          replicaCount: 1
          
          # Recursos del CA Injector
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 1000
          
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
        
        # Configuración ACME solver
        acmesolver:
          image:
            repository: quay.io/jetstack/cert-manager-acmesolver
            
        # Configuración de Prometheus
        prometheus:
          enabled: true
          servicemonitor:
            enabled: true
            prometheusInstance: default
            targetPort: 9402
            path: /metrics
            interval: 60s
            scrapeTimeout: 30s
            
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Cert-Manager optimizado"
}

optimizar_ingress_nginx() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/ingress-nginx.yaml"
    
    log_info "🔧 Optimizando Ingress NGINX según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingress-nginx
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://kubernetes.github.io/ingress-nginx
    chart: ingress-nginx
    targetRevision: 4.13.0
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración del controlador
        controller:
          name: controller
          image:
            repository: registry.k8s.io/ingress-nginx/controller
            tag: "v1.12.2"
            digest: ""
            pullPolicy: IfNotPresent
            runAsUser: 101
            runAsNonRoot: true
          
          # Configuración de réplicas
          replicaCount: 1
          minAvailable: 1
          
          # Recursos optimizados
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de autoscaling
          autoscaling:
            enabled: false
            minReplicas: 1
            maxReplicas: 3
            targetCPUUtilizationPercentage: 50
            targetMemoryUtilizationPercentage: 50
          
          # Configuración del servicio
          service:
            enabled: true
            type: NodePort
            ports:
              http: 80
              https: 443
            targetPorts:
              http: http
              https: https
            nodePorts:
              http: 30080
              https: 30443
            
          # Configuración de métricas
          metrics:
            enabled: true
            serviceMonitor:
              enabled: true
              additionalLabels: {}
              namespace: ""
              namespaceSelector: {}
              scrapeInterval: 30s
              targetLabels: []
              relabelings: []
              metricRelabelings: []
            prometheusRule:
              enabled: false
          
          # Configuración de logs
          config:
            # Configuración de logs
            log-format-upstream: '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_length $request_time [$proxy_upstream_name] [$proxy_alternative_upstream_name] $upstream_addr $upstream_response_length $upstream_response_time $upstream_status $req_id'
            
            # Configuración de proxy
            proxy-connect-timeout: "5"
            proxy-send-timeout: "60"
            proxy-read-timeout: "60"
            proxy-buffering: "off"
            proxy-buffer-size: "4k"
            
            # Configuración de SSL
            ssl-protocols: "TLSv1.2 TLSv1.3"
            ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-RSA-AES128-GCM-SHA256,ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES256-GCM-SHA384"
            
            # Configuración de rate limiting
            rate-limit-connections: "20"
            rate-limit-rps: "10"
            
            # Configuración de upstream
            upstream-keepalive-connections: "50"
            upstream-keepalive-timeout: "60"
            upstream-keepalive-requests: "100"
            
            # Configuración de worker
            worker-processes: "auto"
            worker-connections: "16384"
            worker-cpu-affinity: "auto"
            
            # Configuración de cliente
            client-max-body-size: "1m"
            client-body-buffer-size: "1k"
            client-header-buffer-size: "1k"
            
          # Configuración de probe
          livenessProbe:
            httpGet:
              path: "/healthz"
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 1
            successThreshold: 1
            failureThreshold: 5
            
          readinessProbe:
            httpGet:
              path: "/healthz"
              port: 10254
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 1
            successThreshold: 1
            failureThreshold: 3
          
          # Configuración de seguridad
          containerSecurityContext:
            runAsUser: 101
            runAsNonRoot: true
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
          
          # Configuración de pods
          podSecurityContext:
            runAsNonRoot: true
            runAsUser: 101
            fsGroup: 101
            
        # Configuración del webhook de admisión
        admissionWebhooks:
          enabled: true
          
          # Configuración del patch job
          patch:
            enabled: true
            image:
              repository: registry.k8s.io/ingress-nginx/kube-webhook-certgen
              tag: "v1.5.3"
              pullPolicy: IfNotPresent
            resources:
              limits:
                cpu: 100m
                memory: 128Mi
              requests:
                cpu: 50m
                memory: 64Mi
          
        # Configuración por defecto del backend
        defaultBackend:
          enabled: false
          
        # Configuración RBAC
        rbac:
          create: true
          scope: false
          
        # Configuración de ServiceAccount
        serviceAccount:
          create: true
          name: ""
          automountServiceAccountToken: true
          
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Ingress NGINX optimizado"
}

optimizar_external_secrets() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/external-secrets.yaml"
    
    log_info "🔧 Optimizando External Secrets según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    chart: external-secrets
    targetRevision: 0.19.0
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración de réplicas
        replicaCount: 1
        
        # Configuración de imagen
        image:
          repository: ghcr.io/external-secrets/external-secrets
          pullPolicy: IfNotPresent
          tag: ""
        
        # Configuración de recursos
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
        
        # Configuración de seguridad
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
          fsGroup: 65534
        
        containerSecurityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
        
        # ServiceAccount
        serviceAccount:
          create: true
          automount: true
          annotations: {}
          name: ""
        
        # RBAC
        rbac:
          create: true
        
        # Configuración de métricas
        metrics:
          service:
            enabled: true
            port: 8080
          serviceMonitor:
            enabled: true
            namespace: ""
            interval: 30s
            scrapeTimeout: 25s
        
        # Configuración del webhook
        webhook:
          create: true
          port: 10250
          image:
            repository: ghcr.io/external-secrets/external-secrets
            pullPolicy: IfNotPresent
            tag: ""
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          securityContext:
            runAsNonRoot: true
            runAsUser: 65534
            fsGroup: 65534
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 65534
        
        # Cert Controller
        certController:
          create: true
          image:
            repository: ghcr.io/external-secrets/external-secrets
            pullPolicy: IfNotPresent
            tag: ""
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          securityContext:
            runAsNonRoot: true
            runAsUser: 65534
            fsGroup: 65534
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 65534
        
        # Configuración de CRDs
        crds:
          create: true
          createClusterExternalSecret: true
          createClusterSecretStore: true
          createPushSecret: true
        
        # Configuración de logs
        log:
          level: info
          timeEncoding: epoch
        
        # Configuración de concurrent reconciles
        concurrent: 1
        
        # Configuración de toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
        # Configuración de pod disruption budget
        podDisruptionBudget:
          enabled: false
          minAvailable: 1
        
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ External Secrets optimizado"
}

optimizar_argo_events() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/argo-events.yaml"
    
    log_info "🔧 Optimizando Argo Events según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-events
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-events
    targetRevision: 2.4.16
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración global
        global:
          image:
            tag: "v1.10.1"
        
        # Configuración de CRDs
        crds:
          install: true
          keep: true
        
        # Controller Manager
        controller:
          # Configuración de réplicas
          replicaCount: 1
          
          # Configuración de imagen
          image:
            repository: quay.io/argoproj/argo-events
            tag: ""
            pullPolicy: Always
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 9731
            fsGroup: 9731
          
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 9731
          
          # Configuración de métricas
          metrics:
            enabled: true
            port: 8080
            serviceMonitor:
              enabled: true
              additionalLabels: {}
              namespace: argo-events
          
          # Configuración de logs
          logging:
            level: info
            format: json
          
          # Configuración de namespace
          namespaceParallelism: 20
          
          # Configuración de liveness probe
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8081
            initialDelaySeconds: 3
            periodSeconds: 3
          
          # Configuración de readiness probe
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8081
            initialDelaySeconds: 3
            periodSeconds: 3
        
        # Webhook
        webhook:
          enabled: true
          port: 443
          
        # ServiceAccount
        serviceAccount:
          create: true
          name: ""
          annotations: {}
        
        # RBAC
        rbac:
          enabled: true
        
        # Configuración de configs
        configs:
          # Jetstream configuration
          jetstream:
            # Default JetStream settings, could be overridden by EventBus JetStream specs
            settings: |
              # https://docs.nats.io/running-a-nats-service/configuration#jetstream
              # Only support config file for now. Please
              max_memory_store: 64MB
              max_file_store: 1GB
            
            # The default properties of the streams to be created in this JetStream service
            streamConfig: |
              # The subject using for the stream. If not specified, defaults to the event source name.
              # subject: "foo"
              # Default to 1GB
              maxBytes: 1GB
              # Default to 72h, i.e. 3 days
              maxAge: 72h
              # Default to 1000000
              maxMsgs: 1000000
              # Default to 10MB
              maxMsgSize: 10MB
              # Default to 1
              replicas: 1
              # Default to 1000000
              duplicates: 1000000
        
        # Configuración adicional
        extraObjects: []
        
        # Toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
        # Pod Disruption Budget
        podDisruptionBudget:
          enabled: false
          minAvailable: 1
        
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-events
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Argo Events optimizado"
}

optimizar_argo_rollouts() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/argo-rollouts.yaml"
    
    log_info "🔧 Optimizando Argo Rollouts según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-rollouts
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-rollouts
    targetRevision: 2.40.3
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración global
        global:
          image:
            tag: "v1.8.2"
        
        # Configuración de imagen
        image:
          repository: quay.io/argoproj/argo-rollouts
          tag: ""
          pullPolicy: IfNotPresent
        
        # Configuración de réplicas
        replicaCount: 1
        
        # Configuración de recursos
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi
        
        # Configuración de seguridad
        securityContext:
          runAsNonRoot: true
          runAsUser: 999
          fsGroup: 999
        
        containerSecurityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 999
        
        # ServiceAccount
        serviceAccount:
          create: true
          annotations: {}
          name: ""
        
        # RBAC
        rbac:
          create: true
        
        # Configuración de métricas
        metrics:
          enabled: true
          serviceMonitor:
            enabled: true
            additionalLabels: {}
            namespace: ""
            interval: 30s
            relabelings: []
            metricRelabelings: []
            selector: {}
            targetLabels: []
        
        # Configuración de notificaciones
        notifications:
          # Install and upgrade
          secret:
            # Whether to create notifications secret
            create: false
            # Generic key:value pairs to be inserted into the secret
            # Can be used for templates, notification services etc.
            # Note: all values must be strings
            items: {}
          # Configures notification services
          notifiers: {}
          # Configuration for notification templates
          templates: {}
          # Configuration for notification triggers
          triggers: {}
          # The notification subscription configuration
          subscriptions: []
          # List of extra notifiers to use
          extraSecretItems: {}
        
        # Configuración del controller
        controller:
          # Log level for the controller
          logLevel: info
          # Log format for the controller
          logFormat: text
          # Metrics port
          metricsPort: 8090
          # Health probe port
          healthzPort: 8080
          # Leader election
          leaderElect: true
          
          # Configuración de trafficRouting
          trafficRouterPlugins:
            traefik:
              enabled: false
            nginx:
              enabled: true
            istio:
              enabled: false
            alb:
              enabled: false
          
          # Configuración de metricProviders
          metricProviderPlugins:
            prometheus:
              enabled: true
            datadog:
              enabled: false
            newrelic:
              enabled: false
            wavefront:
              enabled: false
            kayenta:
              enabled: false
            web:
              enabled: false
            job:
              enabled: false
        
        # Configuración de dashboard
        dashboard:
          enabled: false
          image:
            repository: quay.io/argoproj/kubectl-argo-rollouts
            tag: ""
            pullPolicy: IfNotPresent
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 64Mi
          serviceType: ClusterIP
          servicePort: 3100
          servicePortName: dashboard
          ingress:
            enabled: false
            annotations: {}
            labels: {}
            ingressClassName: ""
            hosts: []
            paths:
            - /
            pathType: Prefix
            tls: []
        
        # Configuración de CRDs
        installCRDs: true
        keepCRDs: true
        
        # Configuración adicional
        extraArgs: []
        extraEnv: []
        
        # Toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
        # Pod Disruption Budget
        podDisruptionBudget: {}
        
        # Priority Class
        priorityClassName: ""
        
        # Pod Annotations
        podAnnotations: {}
        
        # Pod Labels
        podLabels: {}
        
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-rollouts
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Argo Rollouts optimizado"
}

optimizar_argo_workflows() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/argo-workflows.yaml"
    
    log_info "🔧 Optimizando Argo Workflows según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-workflows
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-workflows
    targetRevision: 0.45.21
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración global
        global:
          image:
            tag: "v3.6.2"
        
        # Configuración de imágenes
        images:
          pullPolicy: IfNotPresent
        
        # Configuración de CRDs
        crds:
          install: true
          keep: true
        
        # Controller
        controller:
          image:
            repository: quay.io/argoproj/workflow-controller
            tag: ""
          
          # Configuración de réplicas
          replicas: 1
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 8737
            fsGroup: 8737
          
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 8737
          
          # Configuración de métricas
          metricsConfig:
            enabled: true
            path: /metrics
            port: 9090
            servicePort: 8080
            servicePortName: metrics
            serviceMonitor:
              enabled: true
              additionalLabels: {}
              namespace: ""
          
          # Configuración de telemetría
          telemetryConfig:
            enabled: false
          
          # Configuración de logs
          logging:
            level: info
            format: text
            globallevel: "0"
          
          # Configuración del controller
          workflowDefaults:
            spec:
              ttlStrategy:
                secondsAfterCompletion: 86400 # 1 day
                secondsAfterSuccess: 86400    # 1 day
                secondsAfterFailure: 259200   # 3 days
          
          # Configuración de namespace
          workflowNamespaces:
            - argo-workflows
          
          # Configuración de persistencia
          persistence:
            connectionPool:
              maxIdleConns: 100
              maxOpenConns: 0
            # save the entire workflow into etcd and DB
            nodeStatusOffLoad: false
            # save logs to db
            archive: false
            postgresql:
              host: localhost
              port: 5432
              database: postgres
              tableName: argo_workflows
              # the database secrets must be in the same namespace of the controller
              userNameSecret:
                name: argo-postgres-config
                key: username
              passwordSecret:
                name: argo-postgres-config
                key: password
        
        # Server
        server:
          enabled: true
          
          image:
            repository: quay.io/argoproj/argocli
            tag: ""
          
          # Configuración de réplicas
          replicas: 1
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 8737
            fsGroup: 8737
          
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 8737
          
          # Configuración del servicio
          serviceType: ClusterIP
          servicePort: 2746
          
          # Configuración de autenticación
          authModes:
            - server
          
          # Configuración de SSO
          sso: {}
          
          # Configuración de ingress
          ingress:
            enabled: true
            ingressClassName: nginx
            annotations:
              nginx.ingress.kubernetes.io/rewrite-target: /$2
              nginx.ingress.kubernetes.io/use-regex: "true"
            hosts:
              - host: argo-workflows.local
                paths:
                  - path: /workflows(/|$)(.*)
                    pathType: ImplementationSpecific
            tls: []
          
          # Configuración de logs
          logging:
            level: info
            format: text
            globallevel: "0"
        
        # Executor
        executor:
          image:
            repository: quay.io/argoproj/argoexec
            tag: ""
          
          # Configuración de recursos para executor
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 128Mi
        
        # Configuración de artefactos
        artifactRepository:
          # archiveLogs will archive the main container logs as an artifact
          archiveLogs: false
          s3:
            # Use the corresponding server-side encryption algorithm (e.g. AES256, aws:kms)
            # encryptionOptions:
            #   enableEncryption: true
            accessKeySecret:
              name: my-minio-cred
              key: accesskey
            secretKeySecret:
              name: my-minio-cred
              key: secretkey
            insecure: true
            bucket: my-bucket
            endpoint: minio:9000
        
        # ServiceAccount
        serviceAccount:
          create: true
          annotations: {}
          name: ""
        
        # RBAC
        rbac:
          create: true
        
        # Configuración adicional
        extraArgs: []
        extraEnv: []
        
        # Toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
        # Configuración de workflow
        workflow:
          serviceAccount:
            create: true
            annotations: {}
            name: ""
          rbac:
            create: true
        
        # Single Sign-On configuration
        singleNamespace: false
        
  destination:
    server: https://kubernetes.default.svc
    namespace: argo-workflows
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Argo Workflows optimizado"
}

optimizar_jaeger() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/jaeger.yaml"
    
    log_info "🔧 Optimizando Jaeger según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jaeger
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://jaegertracing.github.io/helm-charts
    chart: jaeger
    targetRevision: 3.4.1
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración global
        fullnameOverride: jaeger
        
        # Configuración de CRDs
        crd:
          install: false
        
        # Configuración de all-in-one (para desarrollo)
        allInOne:
          enabled: true
          image: jaegertracing/all-in-one
          tag: "1.62.0"
          pullPolicy: IfNotPresent
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de seguridad
          securityContext:
            runAsUser: 10001
            runAsGroup: 10001
            fsGroup: 10001
            runAsNonRoot: true
          
          containerSecurityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
              - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 10001
          
          # Configuración de ingress
          ingress:
            enabled: true
            ingressClassName: nginx
            annotations:
              nginx.ingress.kubernetes.io/rewrite-target: /
            hosts:
              - host: jaeger.local
                paths:
                  - path: /
                    pathType: Prefix
            tls: []
          
          # Configuración de storage
          args:
            - --memory.max-traces=50000
            - --query.base-path=/
            - --query.ui-config=/etc/jaeger/ui.json
          
          # Configuración de sampling
          sampling:
            strategies: |
              {
                "default_strategy": {
                  "type": "probabilistic",
                  "param": 0.1
                },
                "per_service_strategies": [
                  {
                    "service": "my-service",
                    "type": "probabilistic",
                    "param": 0.5
                  }
                ]
              }
        
        # Configuración de agent (deshabilitado en all-in-one)
        agent:
          enabled: false
        
        # Configuración de collector (deshabilitado en all-in-one)
        collector:
          enabled: false
        
        # Configuración de query (deshabilitado en all-in-one)
        query:
          enabled: false
        
        # Configuración de cassandra
        cassandra:
          enabled: false
        
        # Configuración de elasticsearch
        elasticsearch:
          enabled: false
        
        # Configuración de kafka
        kafka:
          enabled: false
        
        # Configuración de storage
        storage:
          type: memory
        
        # ServiceAccount
        serviceAccount:
          create: true
          name: ""
          annotations: {}
        
        # RBAC
        rbac:
          create: true
        
        # Configuración de esquema
        schema:
          annotations: {}
          image: jaegertracing/jaeger-cassandra-schema
          tag: "1.62.0"
          pullPolicy: IfNotPresent
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 256m
              memory: 128Mi
          serviceAccount:
            create: true
            name: ""
        
        # Configuración de hotrod (aplicación de ejemplo)
        hotrod:
          enabled: false
          image:
            repository: jaegertracing/example-hotrod
            tag: "1.62.0"
            pullPolicy: IfNotPresent
          service:
            type: ClusterIP
            port: 8080
          ingress:
            enabled: false
          tracing:
            host: null
            port: 14268
        
        # Configuración adicional
        extraConfigmapMounts: []
        extraSecretMounts: []
        
        # Toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
  destination:
    server: https://kubernetes.default.svc
    namespace: observability
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Jaeger optimizado"
}

optimizar_minio() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/minio.yaml"
    
    log_info "🔧 Optimizando MinIO según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: minio
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.min.io
    chart: minio
    targetRevision: 5.4.0
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración global
        fullnameOverride: minio
        
        # Configuración de imagen
        image:
          repository: quay.io/minio/minio
          tag: RELEASE.2024-12-19T22-06-38Z
          pullPolicy: IfNotPresent
        
        # Configuración de modo
        mode: standalone
        
        # Configuración de réplicas (para standalone)
        replicas: 1
        
        # Configuración de recursos
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 512Mi
        
        # Configuración de seguridad
        securityContext:
          enabled: true
          runAsUser: 1000
          runAsGroup: 1000
          fsGroup: 1000
          runAsNonRoot: true
        
        # Configuración de credenciales
        auth:
          rootUser: minioadmin
          rootPassword: minioadmin123
        
        # Configuración de persistencia
        persistence:
          enabled: true
          size: 10Gi
          accessMode: ReadWriteOnce
          storageClass: ""
        
        # Configuración de servicio
        service:
          type: ClusterIP
          port: 9000
          nodePort: 32000
          clusterIP: ""
          loadBalancerIP: ""
          loadBalancerSourceRanges: []
          externalIPs: []
        
        # Configuración de console
        consoleService:
          type: ClusterIP
          port: 9001
          nodePort: 32001
        
        # Configuración de ingress
        ingress:
          enabled: true
          ingressClassName: nginx
          annotations:
            nginx.ingress.kubernetes.io/rewrite-target: /
            nginx.ingress.kubernetes.io/proxy-body-size: "0"
            nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
            nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
          hosts:
            - host: minio.local
              paths:
                - path: /
                  pathType: Prefix
          tls: []
        
        # Configuración de console ingress
        consoleIngress:
          enabled: true
          ingressClassName: nginx
          annotations:
            nginx.ingress.kubernetes.io/rewrite-target: /
          hosts:
            - host: minio-console.local
              paths:
                - path: /
                  pathType: Prefix
          tls: []
        
        # Configuración de buckets por defecto
        defaultBuckets: "bucket1,bucket2,backup,artifacts"
        
        # Configuración de políticas
        policies: []
        
        # Configuración de usuarios
        users: []
        
        # Configuración de métricas
        metrics:
          serviceMonitor:
            enabled: true
            additionalLabels: {}
            namespace: ""
            interval: 30s
            scrapeTimeout: 25s
        
        # Configuración de environment
        environment:
          MINIO_BROWSER_REDIRECT_URL: "http://minio-console.local"
          MINIO_SERVER_URL: "http://minio.local"
          
        # Configuración de liveness probe
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 30
          timeoutSeconds: 20
          successThreshold: 1
          failureThreshold: 3
        
        # Configuración de readiness probe
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 15
          timeoutSeconds: 20
          successThreshold: 1
          failureThreshold: 3
        
        # Configuración de startup probe
        startupProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 20
          successThreshold: 1
          failureThreshold: 60
        
        # ServiceAccount
        serviceAccount:
          create: true
          name: ""
          annotations: {}
        
        # RBAC
        rbac:
          create: true
        
        # Configuración de red
        networkPolicy:
          enabled: false
          allowExternal: true
        
        # Configuración de PodDisruptionBudget
        podDisruptionBudget:
          enabled: false
          maxUnavailable: 1
        
        # Toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
        # Configuración adicional
        extraEnvVars: []
        extraVolumes: []
        extraVolumeMounts: []
        
  destination:
    server: https://kubernetes.default.svc
    namespace: storage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ MinIO optimizado"
}

optimizar_gitea() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/gitea.yaml"
    
    log_info "🔧 Optimizando Gitea según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
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
    targetRevision: 12.1.3
    helm:
      values: |
        # === CONFIGURACIÓN OPTIMIZADA PARA GITOPS ===
        
        # Configuración global
        global:
          imageRegistry: ""
          imagePullSecrets: []
          storageClass: ""
        
        # Configuración de imagen
        image:
          repository: gitea/gitea
          tag: "1.22.8"
          pullPolicy: IfNotPresent
          rootless: true
        
        # Configuración de réplicas
        replicaCount: 1
        
        # Configuración de recursos
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 250m
            memory: 512Mi
        
        # Configuración de seguridad
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
          readOnlyRootFilesystem: true
          runAsGroup: 1000
          runAsNonRoot: true
          runAsUser: 1000
          seccompProfile:
            type: RuntimeDefault
        
        # Configuración de persistencia
        persistence:
          enabled: true
          size: 10Gi
          accessModes:
            - ReadWriteOnce
          storageClass: ""
          
        # Configuración de servicio
        service:
          http:
            type: ClusterIP
            port: 3000
            clusterIP: None
          ssh:
            type: ClusterIP
            port: 22
            clusterIP: None
        
        # Configuración de ingress
        ingress:
          enabled: true
          className: nginx
          annotations:
            nginx.ingress.kubernetes.io/proxy-body-size: "1024m"
          hosts:
            - host: gitea.local
              paths:
                - path: /
                  pathType: Prefix
          tls: []
        
        # Configuración de PostgreSQL
        postgresql:
          enabled: true
          global:
            postgresql:
              auth:
                postgresPassword: "gitea123"
                username: "gitea"
                password: "gitea123"
                database: "gitea"
          primary:
            persistence:
              enabled: true
              size: 8Gi
            resources:
              limits:
                cpu: 250m
                memory: 256Mi
              requests:
                cpu: 125m
                memory: 128Mi
        
        # Configuración de PostgreSQL-HA (deshabilitado)
        postgresql-ha:
          enabled: false
        
        # Configuración de Redis
        redis:
          enabled: true
          architecture: standalone
          auth:
            enabled: false
          master:
            persistence:
              enabled: true
              size: 8Gi
            resources:
              limits:
                cpu: 150m
                memory: 128Mi
              requests:
                cpu: 100m
                memory: 64Mi
        
        # Configuración de Redis Cluster (deshabilitado)
        redis-cluster:
          enabled: false
        
        # Configuración de Gitea
        gitea:
          admin:
            username: "gitea_admin"
            password: "r8sA8CPHD9!bt6d"
            email: "gitea@local.domain"
          
          # Configuración de métricas
          metrics:
            enabled: true
            serviceMonitor:
              enabled: true
              additionalLabels: {}
              namespace: ""
          
          # Configuración LDAP (deshabilitado)
          ldap: []
          
          # Configuración OAuth2 (deshabilitado)
          oauth: []
          
          # Configuración del servidor
          config:
            APP_NAME: "Gitea: Git with a cup of tea"
            RUN_MODE: prod
            
            server:
              PROTOCOL: http
              DOMAIN: gitea.local
              HTTP_PORT: 3000
              ROOT_URL: http://gitea.local
              DISABLE_SSH: false
              SSH_PORT: 22
              SSH_LISTEN_PORT: 2222
              LFS_START_SERVER: true
              OFFLINE_MODE: false
              
            database:
              DB_TYPE: postgres
              HOST: gitea-postgresql:5432
              NAME: gitea
              USER: gitea
              PASSWD: gitea123
              CHARSET: utf8
              
            cache:
              ENABLED: true
              ADAPTER: redis
              HOST: redis://:@gitea-redis-master:6379/0
              
            session:
              PROVIDER: redis
              PROVIDER_CONFIG: redis://:@gitea-redis-master:6379/0
              
            queue:
              TYPE: redis
              CONN_STR: redis://:@gitea-redis-master:6379/0
              
            security:
              INSTALL_LOCK: true
              SECRET_KEY: "47 characters long"
              INTERNAL_TOKEN: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
              
            service:
              DISABLE_REGISTRATION: false
              REQUIRE_SIGNIN_VIEW: false
              REGISTER_EMAIL_CONFIRM: false
              ENABLE_NOTIFY_MAIL: false
              ALLOW_ONLY_EXTERNAL_REGISTRATION: false
              ENABLE_CAPTCHA: false
              DEFAULT_KEEP_EMAIL_PRIVATE: false
              DEFAULT_ALLOW_CREATE_ORGANIZATION: true
              DEFAULT_ENABLE_TIMETRACKING: true
              NO_REPLY_ADDRESS: noreply.example.org
              
            mailer:
              ENABLED: false
              
            log:
              MODE: console
              LEVEL: info
              ROOT_PATH: /data/gitea/log
              
            repository:
              ROOT: /data/git/repositories
              DEFAULT_BRANCH: main
              
            ui:
              DEFAULT_THEME: auto
              
        # Configuración de signing
        signing:
          enabled: false
          gpgHome: /data/git/.gnupg
        
        # ServiceAccount
        serviceAccount:
          create: true
          name: ""
          annotations: {}
        
        # RBAC
        rbac:
          create: true
        
        # Configuración de deployment
        deployment:
          env: []
          terminationGracePeriodSeconds: 60
          labels: {}
          annotations: {}
        
        # Configuración de StatefulSet
        statefulset:
          env: []
          terminationGracePeriodSeconds: 60
          labels: {}
          annotations: {}
        
        # Toleraciones y afinidad
        nodeSelector: {}
        tolerations: []
        affinity: {}
        
        # Configuración de test
        test:
          enabled: true
          image:
            name: busybox
            tag: latest
        
  destination:
    server: https://kubernetes.default.svc
    namespace: gitea
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Gitea optimizado"
}

optimizar_kargo() {
    local herramientas_dir="$1"
    local app_file="$herramientas_dir/kargo.yaml"
    
    log_info "🔧 Optimizando Kargo según mejores prácticas..."
    
    cat > "$app_file" << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kargo
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    # Repositorio Git directo desde GitHub - usando chart oficial
    repoURL: https://github.com/akuity/kargo.git
    targetRevision: v1.6.2
    path: charts/kargo
    helm:
      values: |
        # === CONFIGURACIÓN MÍNIMA PARA DESARROLLO ===
        
        # Configuración de imagen
        image:
          repository: ghcr.io/akuity/kargo
          tag: v1.6.2
          pullPolicy: IfNotPresent
        
        # API Server
        api:
          enabled: true
          replicas: 1
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración de servicio
          service:
            type: ClusterIP
            port: 80
          
          # Ingress para acceso web
          ingress:
            enabled: true
            className: nginx
            annotations:
              nginx.ingress.kubernetes.io/rewrite-target: /
            hosts:
              - host: kargo.local
                paths:
                  - path: /
                    pathType: Prefix
            tls: []
        
        # Controller
        controller:
          enabled: true
          replicas: 1
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
        
        # Webhooks
        webhooks:
          enabled: true
          replicas: 1
          resources:
            limits:
              cpu: 100m
              memory: 128Mi
            requests:
              cpu: 50m
              memory: 64Mi
        
        # Configuración RBAC
        rbac:
          installClusterRoles: true
        
        # ServiceAccount
        serviceAccount:
          create: true
          name: ""
          annotations: {}
        
        # Configuración de seguridad
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          fsGroup: 1000
        
        containerSecurityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          podAnnotations: {}
          env: []
          envFrom: []
          nodeSelector: {}
          tolerations: []
          affinity: {}
          securityContext: {}
        
        # Configuración de imagen
        image:
          repository: ghcr.io/akuity/kargo
          tag: "v1.6.2"
          pullPolicy: IfNotPresent
          pullSecrets: []
        
        # Configuración de CRDs
        crds:
          install: true
          keep: true
        
        # Configuración RBAC
        rbac:
          installClusterRoles: true
          installClusterRoleBindings: true
        
        # Configuración de webhooks
        webhooks:
          register: true
        
        # Configuración de API
        api:
          enabled: true
          replicas: 1
          host: kargo.local
          logLevel: INFO
          secretManagementEnabled: true
          permissiveCORSPolicyEnabled: false
          
          # Configuración de admin
          adminAccount:
            enabled: true
            passwordHash: "$2a$10$Zrhhie4vLz5ygtVSaif6d.WzqpTZmGa4VNjr9ACwUe/rLKxCB3z6m" # admin123
            tokenSigningKey: "5m2NgUMEnhJjV3QiQh3LBM7hJw8FiNxj"
            tokenTTL: 24h
          
          # Configuración OIDC
          oidc:
            enabled: false
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 65534
            fsGroup: 65534
          
          # Configuración de servicio
          service:
            type: ClusterIP
            nodePort: null
            annotations: {}
          
          # Configuración de ingress
          ingress:
            enabled: true
            annotations:
              nginx.ingress.kubernetes.io/rewrite-target: /
            ingressClassName: nginx
            hosts:
              - kargo.local
            pathType: ImplementationSpecific
            tls:
              enabled: false
          
          # Configuración TLS
          tls:
            enabled: true
            selfSignedCert: true
            terminatedUpstream: false
          
          # Configuración de ArgoCD
          argocd:
            urls: {}
          
          # Configuración de rollouts
          rollouts:
            integrationEnabled: true
        
        # Configuración del Controller
        controller:
          enabled: true
          logLevel: INFO
          isDefault: false
          shardName: null
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 65534
            fsGroup: 65534
          
          # Configuración de Git
          gitClient:
            name: Kargo
            email: kargo@local.domain
          
          # Configuración de ArgoCD
          argocd:
            integrationEnabled: true
            namespace: argocd
            watchArgocdNamespaceOnly: false
          
          # Configuración de rollouts
          rollouts:
            integrationEnabled: true
          
          # Configuración de reconcilers
          reconcilers:
            maxConcurrentReconciles: 4
        
        # Configuración del Management Controller
        managementController:
          enabled: true
          logLevel: INFO
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración de seguridad
          securityContext:
            runAsNonRoot: true
            runAsUser: 65534
            fsGroup: 65534
        
        # Configuración del Garbage Collector
        garbageCollector:
          enabled: true
          logLevel: INFO
          schedule: "0 * * * *"
          workers: 3
          maxRetainedPromotions: 20
          minPromotionDeletionAge: 336h
          maxRetainedFreight: 20
          minFreightDeletionAge: 336h
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
        
        # Configuración del Webhooks Server
        webhooksServer:
          enabled: true
          replicas: 1
          logLevel: INFO
          controlplaneUserRegex: ""
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración TLS
          tls:
            selfSignedCert: true
            caBundle: ""
        
        # Configuración del External Webhooks Server
        externalWebhooksServer:
          enabled: true
          replicas: 1
          host: kargo-webhooks.local
          logLevel: INFO
          
          # Configuración de recursos
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          
          # Configuración de servicio
          service:
            type: ClusterIP
            nodePort: null
            annotations: {}
          
          # Configuración TLS
          tls:
            enabled: true
            selfSignedCert: true
            terminatedUpstream: false
          
          # Configuración de ingress
          ingress:
            enabled: false
        
        # Configuración de ServiceAccount
        serviceAccount:
          labels: {}
          annotations: {}
        
        # Configuración adicional
        extraObjects: []
        
  destination:
    server: https://kubernetes.default.svc
    namespace: kargo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
    
    log_success "✅ Kargo optimizado"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local herramientas_dir="${1:-$(pwd)/herramientas-gitops}"
    
    if [[ ! -d "$herramientas_dir" ]]; then
        log_error "❌ Directorio de herramientas no encontrado: $herramientas_dir"
        return 1
    fi
    
    log_section "🛠️ Optimizando todas las herramientas GitOps"
    
    # Ejecutar optimizaciones
    optimizar_prometheus_stack "$herramientas_dir"
    optimizar_grafana "$herramientas_dir"
    optimizar_loki "$herramientas_dir"
    optimizar_cert_manager "$herramientas_dir"
    optimizar_ingress_nginx "$herramientas_dir"
    optimizar_external_secrets "$herramientas_dir"
    optimizar_argo_events "$herramientas_dir"
    optimizar_argo_rollouts "$herramientas_dir"
    optimizar_argo_workflows "$herramientas_dir"
    optimizar_jaeger "$herramientas_dir"
    optimizar_minio "$herramientas_dir"
    optimizar_gitea "$herramientas_dir"
    optimizar_kargo "$herramientas_dir"
    
    log_success "🎉 Todas las herramientas han sido optimizadas según mejores prácticas"
    log_info "💡 Ejecuta 'git diff' para revisar los cambios realizados"
}

# Auto-inicialización si se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
