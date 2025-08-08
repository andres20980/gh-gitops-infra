#!/bin/bash

# ============================================================================
# GENERADOR DE APLICACIONES CUSTOM CON INTEGRACIÓN GITOPS COMPLETA
# ============================================================================
# Genera manifiestos de aplicaciones custom totalmente integradas con todas
# las herramientas GitOps: monitoring, logging, tracing, secrets, CI/CD, etc.
# ============================================================================

set -euo pipefail

# Cargar funciones base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/base.sh"

# ============================================================================
# FUNCIONES DE GENERACIÓN DE MANIFIESTOS GITOPS
# ============================================================================

# Generar ServiceMonitor para Prometheus
generar_service_monitor() {
    local app_name="$1"
    local namespace="$2"
    local port="${3:-http}"
    local path="${4:-/metrics}"
    
    cat << EOF
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${app_name}-metrics
  namespace: ${namespace}
  labels:
    app: ${app_name}
    monitoring: enabled
spec:
  selector:
    matchLabels:
      app: ${app_name}
  endpoints:
  - port: ${port}
    path: ${path}
    interval: 30s
    scrapeTimeout: 10s
EOF
}

# Generar PrometheusRule para alertas
generar_prometheus_rule() {
    local app_name="$1"
    local namespace="$2"
    
    cat << EOF
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ${app_name}-alerts
  namespace: ${namespace}
  labels:
    app: ${app_name}
    alerting: enabled
spec:
  groups:
  - name: ${app_name}.rules
    rules:
    - alert: ${app_name^}HighErrorRate
      expr: rate(http_requests_total{job="${app_name}",code=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: warning
        app: ${app_name}
      annotations:
        summary: "High error rate detected for ${app_name}"
        description: "Error rate is {{ \$value }} errors per second"
    
    - alert: ${app_name^}HighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="${app_name}"}[5m])) > 0.5
      for: 5m
      labels:
        severity: warning
        app: ${app_name}
      annotations:
        summary: "High latency detected for ${app_name}"
        description: "95th percentile latency is {{ \$value }}s"
EOF
}

# Generar Rollout para progressive delivery
generar_rollout() {
    local app_name="$1"
    local namespace="$2"
    local image="$3"
    local replicas="${4:-3}"
    
    cat << EOF
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ${app_name}
  namespace: ${namespace}
  labels:
    app: ${app_name}
    deployment-strategy: progressive
spec:
  replicas: ${replicas}
  strategy:
    canary:
      maxSurge: 1
      maxUnavailable: 0
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - setWeight: 50
      - pause: {duration: 30s}
      - setWeight: 80
      - pause: {duration: 30s}
      canaryService: ${app_name}-canary
      stableService: ${app_name}-stable
      trafficRouting:
        nginx:
          stableIngress: ${app_name}-ingress
          annotationPrefix: nginx.ingress.kubernetes.io
      analysis:
        templates:
        - templateName: ${app_name}-analysis
        startingStep: 2
        args:
        - name: service-name
          value: ${app_name}
  selector:
    matchLabels:
      app: ${app_name}
  template:
    metadata:
      labels:
        app: ${app_name}
        version: stable
      annotations:
        # Jaeger tracing
        sidecar.jaegertracing.io/inject: "true"
        # Prometheus monitoring
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
        # Loki logging
        logging.coreos.com/enabled: "true"
    spec:
      containers:
      - name: ${app_name}
        image: ${image}
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8081
          name: metrics
        env:
        - name: JAEGER_AGENT_HOST
          value: "jaeger-agent.observability.svc.cluster.local"
        - name: JAEGER_SERVICE_NAME
          value: "${app_name}"
        - name: OTEL_EXPORTER_JAEGER_ENDPOINT
          value: "http://jaeger-collector.observability.svc.cluster.local:14268/api/traces"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
EOF
}

# Generar AnalysisTemplate para Argo Rollouts
generar_analysis_template() {
    local app_name="$1"
    local namespace="$2"
    
    cat << EOF
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: ${app_name}-analysis
  namespace: ${namespace}
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 60s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(http_requests_total{job="{{args.service-name}}",code!~"5.."}[5m])) /
          sum(rate(http_requests_total{job="{{args.service-name}}"}[5m]))
  
  - name: avg-response-time
    interval: 60s
    count: 5
    successCondition: result[0] <= 0.5
    provider:
      prometheus:
        address: http://prometheus-stack-kube-prom-prometheus.monitoring.svc.cluster.local:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{job="{{args.service-name}}"}[5m])) by (le)
          )
EOF
}

# Generar ExternalSecret para gestión de secretos
generar_external_secret() {
    local app_name="$1"
    local namespace="$2"
    
    cat << EOF
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${app_name}-config
  namespace: ${namespace}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: ${app_name}-secret
    creationPolicy: Owner
  data:
  - secretKey: database-url
    remoteRef:
      key: ${app_name}/database
      property: url
  - secretKey: api-key
    remoteRef:
      key: ${app_name}/api
      property: key
EOF
}

# Generar Certificate para TLS automático
generar_certificate() {
    local app_name="$1"
    local namespace="$2"
    local domain="${3:-${app_name}.local}"
    
    cat << EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${app_name}-tls
  namespace: ${namespace}
spec:
  secretName: ${app_name}-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - ${domain}
  - www.${domain}
EOF
}

# Generar Ingress con todas las anotaciones GitOps
generar_ingress_gitops() {
    local app_name="$1"
    local namespace="$2"
    local domain="${3:-${app_name}.local}"
    
    cat << EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${app_name}-ingress
  namespace: ${namespace}
  annotations:
    # Ingress NGINX
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    
    # Cert Manager
    cert-manager.io/cluster-issuer: letsencrypt-prod
    
    # Argo Rollouts traffic splitting
    nginx.ingress.kubernetes.io/canary: "false"
    
    # Rate limiting
    nginx.ingress.kubernetes.io/rate-limit: "100"
    
    # Security headers
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    
    # Prometheus monitoring
    nginx.ingress.kubernetes.io/enable-metrics: "true"
spec:
  tls:
  - hosts:
    - ${domain}
    secretName: ${app_name}-tls-secret
  rules:
  - host: ${domain}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${app_name}-stable
            port:
              number: 80
EOF
}

# Generar Workflow para CI/CD
generar_workflow() {
    local app_name="$1"
    local namespace="$2"
    local git_repo="${3:-https://github.com/demo/repo.git}"
    
    cat << EOF
---
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ${app_name}-cicd
  namespace: ${namespace}
spec:
  entrypoint: build-test-deploy
  arguments:
    parameters:
    - name: git-repo
      value: ${git_repo}
    - name: git-branch
      value: main
    - name: image-tag
      value: latest
  
  templates:
  - name: build-test-deploy
    dag:
      tasks:
      - name: git-clone
        template: git-clone
        arguments:
          parameters:
          - name: repo
            value: "{{workflow.parameters.git-repo}}"
          - name: branch
            value: "{{workflow.parameters.git-branch}}"
      
      - name: run-tests
        template: run-tests
        dependencies: [git-clone]
      
      - name: build-image
        template: build-image
        dependencies: [run-tests]
        arguments:
          parameters:
          - name: tag
            value: "{{workflow.parameters.image-tag}}"
      
      - name: security-scan
        template: security-scan
        dependencies: [build-image]
      
      - name: deploy-staging
        template: deploy-staging
        dependencies: [security-scan]
      
      - name: integration-tests
        template: integration-tests
        dependencies: [deploy-staging]
      
      - name: promote-production
        template: promote-production
        dependencies: [integration-tests]

  - name: git-clone
    inputs:
      parameters:
      - name: repo
      - name: branch
    container:
      image: alpine/git
      command: [sh, -c]
      args: ["git clone {{inputs.parameters.repo}} /workspace && cd /workspace && git checkout {{inputs.parameters.branch}}"]
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: run-tests
    container:
      image: node:18-alpine
      command: [sh, -c]
      args: ["cd /workspace && npm test"]
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: build-image
    inputs:
      parameters:
      - name: tag
    container:
      image: gcr.io/kaniko-project/executor:latest
      command: [/kaniko/executor]
      args:
      - --dockerfile=/workspace/Dockerfile
      - --context=/workspace
      - --destination=registry.local/${app_name}:{{inputs.parameters.tag}}
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: security-scan
    container:
      image: aquasec/trivy
      command: [trivy]
      args: [image, registry.local/${app_name}:{{workflow.parameters.image-tag}}]

  - name: deploy-staging
    resource:
      action: apply
      manifest: |
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
          name: ${app_name}-staging
          namespace: argocd
        spec:
          project: default
          source:
            repoURL: {{workflow.parameters.git-repo}}
            targetRevision: {{workflow.parameters.git-branch}}
            path: manifests/staging
          destination:
            server: https://kubernetes.default.svc
            namespace: ${namespace}-staging

  - name: integration-tests
    container:
      image: postman/newman
      command: [newman]
      args: [run, /workspace/tests/integration.postman_collection.json]
      volumeMounts:
      - name: workspace
        mountPath: /workspace

  - name: promote-production
    resource:
      action: apply
      manifest: |
        apiVersion: kargo.akuity.io/v1alpha1
        kind: Promotion
        metadata:
          name: ${app_name}-to-production
          namespace: ${namespace}
        spec:
          stage: production
          freight: "{{workflow.parameters.image-tag}}"

  volumeClaimTemplates:
  - metadata:
      name: workspace
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 1Gi
EOF
}

# Generar configuración completa para una aplicación
generar_app_gitops_completa() {
    local app_name="$1"
    local namespace="$2"
    local image="$3"
    local domain="${4:-${app_name}.local}"
    local git_repo="${5:-https://github.com/demo/repo.git}"
    local output_dir="$6"
    
    log_info "🚀 Generando manifiestos GitOps completos para $app_name..."
    
    # Crear directorio de salida
    mkdir -p "$output_dir"
    
    # Generar todos los manifiestos
    {
        echo "# ============================================================================"
        echo "# APLICACIÓN $app_name - MANIFIESTOS GITOPS COMPLETOS"
        echo "# ============================================================================"
        echo "# Generado automáticamente con integración completa de herramientas GitOps:"
        echo "# • Argo Rollouts (progressive delivery)"
        echo "# • Prometheus + Grafana (monitoring & alerting)"
        echo "# • Jaeger (distributed tracing)"
        echo "# • Loki (log aggregation)"
        echo "# • External Secrets (secrets management)"
        echo "# • Cert Manager (TLS certificates)"
        echo "# • Argo Workflows (CI/CD)"
        echo "# • Kargo (promotion pipeline)"
        echo "# • Ingress NGINX (traffic routing)"
        echo "# ============================================================================"
        echo ""
        
        # Namespace
        cat << EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${namespace}
  labels:
    name: ${namespace}
    monitoring: enabled
    logging: enabled
    tracing: enabled
    gitops: enabled
EOF
        
        # Rollout (reemplaza Deployment)
        generar_rollout "$app_name" "$namespace" "$image"
        
        # Services para Rollout
        cat << EOF

---
apiVersion: v1
kind: Service
metadata:
  name: ${app_name}-stable
  namespace: ${namespace}
  labels:
    app: ${app_name}
    service: stable
spec:
  selector:
    app: ${app_name}
  ports:
  - port: 80
    targetPort: http
    name: http
  - port: 8081
    targetPort: metrics
    name: metrics

---
apiVersion: v1
kind: Service
metadata:
  name: ${app_name}-canary
  namespace: ${namespace}
  labels:
    app: ${app_name}
    service: canary
spec:
  selector:
    app: ${app_name}
  ports:
  - port: 80
    targetPort: http
    name: http
  - port: 8081
    targetPort: metrics
    name: metrics
EOF
        
        # Monitoring
        generar_service_monitor "$app_name" "$namespace"
        generar_prometheus_rule "$app_name" "$namespace"
        
        # Progressive Delivery
        generar_analysis_template "$app_name" "$namespace"
        
        # Security & Secrets
        generar_external_secret "$app_name" "$namespace"
        generar_certificate "$app_name" "$namespace" "$domain"
        
        # Networking
        generar_ingress_gitops "$app_name" "$namespace" "$domain"
        
        # CI/CD
        generar_workflow "$app_name" "$namespace" "$git_repo"
        
    } > "$output_dir/${app_name}-gitops-complete.yaml"
    
    log_success "✅ Manifiestos GitOps completos generados en: $output_dir/${app_name}-gitops-complete.yaml"
    log_info "📊 Integraciones incluidas:"
    log_info "   • Progressive Delivery con Argo Rollouts"
    log_info "   • Monitoring completo con Prometheus + Grafana"
    log_info "   • Distributed Tracing con Jaeger"
    log_info "   • Log Aggregation con Loki"
    log_info "   • Secrets Management con External Secrets"
    log_info "   • TLS automatizado con Cert Manager"
    log_info "   • CI/CD pipeline con Argo Workflows"
    log_info "   • Traffic Routing con Ingress NGINX"
    log_info "   • Promotion Pipeline con Kargo"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local comando="${1:-help}"
    
    case "$comando" in
        "generar")
            local app_name="${2:-demo-app}"
            local namespace="${3:-$app_name}"
            local image="${4:-nginx:latest}"
            local domain="${5:-$app_name.local}"
            local git_repo="${6:-https://github.com/demo/repo.git}"
            local output_dir="${7:-./manifests-gitops}"
            
            generar_app_gitops_completa "$app_name" "$namespace" "$image" "$domain" "$git_repo" "$output_dir"
            ;;
        
        "help"|*)
            cat << 'EOF'
Generador de Aplicaciones Custom con Integración GitOps Completa

SINTAXIS:
  ./generar-apps-gitops-completas.sh generar [app-name] [namespace] [image] [domain] [git-repo] [output-dir]

EJEMPLOS:
  # Generar app básica
  ./generar-apps-gitops-completas.sh generar my-app

  # Generar app completa
  ./generar-apps-gitops-completas.sh generar backend api-backend node:18 api.example.com https://github.com/my/repo ./manifests

INTEGRACIONES GITOPS INCLUIDAS:
  • Argo Rollouts - Progressive delivery con canary deployments
  • Prometheus - Metrics collection y service monitoring
  • Grafana - Dashboards automáticos y alerting rules
  • Jaeger - Distributed tracing automático
  • Loki - Log aggregation y shipping
  • External Secrets - Gestión segura de secretos
  • Cert Manager - TLS certificates automáticos
  • Argo Workflows - CI/CD pipeline completo
  • Kargo - Promotion pipeline entre entornos
  • Ingress NGINX - Traffic routing y load balancing
EOF
            ;;
    esac
}

# Ejecutar función principal
main "$@"
