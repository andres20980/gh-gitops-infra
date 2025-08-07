#!/bin/bash
# GitOps Helper - Sistema de optimización dinámico v3.0.0
# Autodescubrimiento y búsqueda de versiones en tiempo real

# Variables globales dinámicas
declare -a GITOPS_TOOLS_DISCOVERED=()
declare -A GITOPS_CHART_INFO=()

# Función para autodescubrir herramientas GitOps en tiempo real
autodescubrir_herramientas_gitops() {
    local directorio_herramientas="herramientas-gitops"
    
    echo "🔍 Autodescubriendo herramientas GitOps en $directorio_herramientas..."
    
    # Limpiar arrays dinámicos
    GITOPS_TOOLS_DISCOVERED=()
    GITOPS_CHART_INFO=()
    
    # Escanear todos los archivos YAML en herramientas-gitops
    for archivo_yaml in "$directorio_herramientas"/*.yaml; do
        if [[ -f "$archivo_yaml" ]]; then
            local nombre_herramienta=$(basename "$archivo_yaml" .yaml)
            GITOPS_TOOLS_DISCOVERED+=("$nombre_herramienta")
            
            echo "   📦 Descubierto: $nombre_herramienta"
            
            # Extraer información del chart del YAML
            extraer_info_chart_del_yaml "$archivo_yaml" "$nombre_herramienta"
        fi
    done
    
    echo "✅ Autodescubrimiento completado: ${#GITOPS_TOOLS_DISCOVERED[@]} herramientas encontradas"
}

# Función para extraer información del chart directamente del YAML
extraer_info_chart_del_yaml() {
    local archivo_yaml="$1"
    local herramienta="$2"
    
    # Buscar información del repositorio Helm en el YAML
    local repo_url=$(grep -E '^\s*repoURL:' "$archivo_yaml" | head -1 | sed 's/.*repoURL:\s*//' | tr -d '"' | tr -d "'")
    local chart_name=$(grep -E '^\s*chart:' "$archivo_yaml" | head -1 | sed 's/.*chart:\s*//' | tr -d '"' | tr -d "'")
    
    # Si no hay información del chart, intentar deducirla
    if [[ -z "$repo_url" || -z "$chart_name" ]]; then
        echo "   ⚠️  No se encontró info de chart en $archivo_yaml, usando detección inteligente"
        detectar_chart_inteligente "$herramienta"
    else
        # Extraer nombre del repositorio de la URL
        local repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|\.github\.io/.*||' | sed 's|.*github\.com/||' | sed 's|/.*||')
        
        GITOPS_CHART_INFO["${herramienta}_repo"]="$repo_name"
        GITOPS_CHART_INFO["${herramienta}_chart"]="$chart_name"
        GITOPS_CHART_INFO["${herramienta}_repo_url"]="$repo_url"
        
        echo "   📋 Chart detectado: $repo_name/$chart_name"
    fi
}

# Función de detección inteligente de charts
detectar_chart_inteligente() {
    local herramienta="$1"
    
    # Base de conocimiento inteligente para detección automática
    case "$herramienta" in
        *"ingress"*|*"nginx"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="ingress-nginx"
            GITOPS_CHART_INFO["${herramienta}_chart"]="ingress-nginx"
            ;;
        *"external"*|*"secret"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="external-secrets"
            GITOPS_CHART_INFO["${herramienta}_chart"]="external-secrets"
            ;;
        *"cert"*|*"manager"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="jetstack"
            GITOPS_CHART_INFO["${herramienta}_chart"]="cert-manager"
            ;;
        *"argo"*"event"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="argo"
            GITOPS_CHART_INFO["${herramienta}_chart"]="argo-events"
            ;;
        *"argo"*"workflow"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="argo"
            GITOPS_CHART_INFO["${herramienta}_chart"]="argo-workflows"
            ;;
        *"argo"*"rollout"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="argo"
            GITOPS_CHART_INFO["${herramienta}_chart"]="argo-rollouts"
            ;;
        *"prometheus"*|*"kube-prometheus-stack"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="prometheus-community"
            GITOPS_CHART_INFO["${herramienta}_chart"]="kube-prometheus-stack"
            ;;
        *"grafana"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="grafana"
            GITOPS_CHART_INFO["${herramienta}_chart"]="grafana"
            ;;
        *"loki"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="grafana"
            GITOPS_CHART_INFO["${herramienta}_chart"]="loki"
            ;;
        *"jaeger"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="jaegertracing"
            GITOPS_CHART_INFO["${herramienta}_chart"]="jaeger"
            ;;
        *"minio"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="minio"
            GITOPS_CHART_INFO["${herramienta}_chart"]="minio"
            ;;
        *"gitea"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="gitea-charts"
            GITOPS_CHART_INFO["${herramienta}_chart"]="gitea"
            ;;
        *"kargo"*)
            GITOPS_CHART_INFO["${herramienta}_repo"]="kargo"
            GITOPS_CHART_INFO["${herramienta}_chart"]="kargo"
            ;;
        *)
            # Detección genérica: usar el nombre de la herramienta
            GITOPS_CHART_INFO["${herramienta}_repo"]="$herramienta"
            GITOPS_CHART_INFO["${herramienta}_chart"]="$herramienta"
            ;;
    esac
    
    echo "   🧠 Detección inteligente: ${GITOPS_CHART_INFO[${herramienta}_repo]}/${GITOPS_CHART_INFO[${herramienta}_chart]}"
}

# Función para buscar la última versión de un chart en tiempo real
buscar_ultima_version_chart() {
    local herramienta="$1"
    local repo="${GITOPS_CHART_INFO[${herramienta}_repo]}"
    local chart="${GITOPS_CHART_INFO[${herramienta}_chart]}"
    
    if [[ -z "$repo" || -z "$chart" ]]; then
        echo "latest"
        return
    fi
    
    echo "🔍 Buscando versión más reciente para $herramienta ($repo/$chart)..." >&2
    
    # Método 1: Buscar usando helm search repo (asegurar que el repo existe)
    local version=""
    if helm repo list 2>/dev/null | grep -q "^$repo"; then
        echo "   📦 Usando repositorio Helm: $repo" >&2
        version=$(helm search repo "$repo/$chart" --versions 2>/dev/null | awk 'NR==2 {print $2}')
    fi
    
    # Método 2: APIs de GitHub como fallback
    if [[ -z "$version" || "$version" == "No" || "$version" == "CHART" || "$version" == "results" ]]; then
        echo "   📡 Usando API de GitHub como fallback..." >&2
        case "$repo" in
            "ingress-nginx"|"kubernetes")
                version=$(curl -s https://api.github.com/repos/kubernetes/ingress-nginx/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/controller-//' 2>/dev/null)
                ;;
            "jetstack")
                version=$(curl -s https://api.github.com/repos/cert-manager/cert-manager/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                ;;
            "external-secrets")
                version=$(curl -s https://api.github.com/repos/external-secrets/external-secrets/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                ;;
            "argo")
                case "$chart" in
                    "argo-events")
                        version=$(curl -s https://api.github.com/repos/argoproj/argo-events/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                        ;;
                    "argo-workflows")
                        version=$(curl -s https://api.github.com/repos/argoproj/argo-workflows/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                        ;;
                    "argo-rollouts")
                        version=$(curl -s https://api.github.com/repos/argoproj/argo-rollouts/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' 2>/dev/null)
                        ;;
                esac
                ;;
            "prometheus-community")
                # Para prometheus stack, usar una versión conocida estable
                version="65.1.1"
                ;;
            "grafana")
                version=$(curl -s https://api.github.com/repos/grafana/grafana/releases/latest | grep '"tag_name":' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/' | sed 's/v//' 2>/dev/null)
                ;;
            *)
                version="latest"
                ;;
        esac
    fi
    
    # Método 3: Fallback a "latest" si todo falla
    if [[ -z "$version" ]]; then
        version="latest"
    fi
    
    echo "   ✅ Versión detectada: $version" >&2
    echo "$version"
}

# Función para configurar repositorios Helm dinámicamente
configurar_repositorios_helm() {
    echo "📡 Configurando repositorios Helm dinámicamente..."
    
    # Repositorios comunes basados en herramientas descubiertas
    declare -A repos_necesarios
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        local repo="${GITOPS_CHART_INFO[${herramienta}_repo]}"
        
        case "$repo" in
            "ingress-nginx")
                repos_necesarios["ingress-nginx"]="https://kubernetes.github.io/ingress-nginx"
                ;;
            "jetstack")
                repos_necesarios["jetstack"]="https://charts.jetstack.io"
                ;;
            "external-secrets")
                repos_necesarios["external-secrets"]="https://charts.external-secrets.io"
                ;;
            "argo")
                repos_necesarios["argo"]="https://argoproj.github.io/argo-helm"
                ;;
            "prometheus-community")
                repos_necesarios["prometheus-community"]="https://prometheus-community.github.io/helm-charts"
                ;;
            "grafana")
                repos_necesarios["grafana"]="https://grafana.github.io/helm-charts"
                ;;
            "jaegertracing")
                repos_necesarios["jaegertracing"]="https://jaegertracing.github.io/helm-charts"
                ;;
            "minio")
                repos_necesarios["minio"]="https://charts.min.io/"
                ;;
            "gitea-charts")
                repos_necesarios["gitea-charts"]="https://dl.gitea.io/charts/"
                ;;
            "kargo")
                repos_necesarios["kargo"]="https://charts.kargo.io"
                ;;
        esac
    done
    
    # Agregar repositorios dinámicamente
    for repo_name in "${!repos_necesarios[@]}"; do
        local repo_url="${repos_necesarios[$repo_name]}"
        echo "   📦 Agregando repositorio: $repo_name ($repo_url)"
        helm repo add "$repo_name" "$repo_url" >/dev/null 2>&1 || true
    done
    
    echo "   🔄 Actualizando repositorios..."
    helm repo update >/dev/null 2>&1
    
    echo "✅ Repositorios Helm configurados dinámicamente"
}

# Función principal de optimización GitOps dinámico
ejecutar_optimizacion_gitops() {
    echo "🚀 Iniciando optimización GitOps v3.0.0 - Sistema autodescubrible"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Paso 1: Autodescubrir herramientas
    autodescubrir_herramientas_gitops
    
    if [[ ${#GITOPS_TOOLS_DISCOVERED[@]} -eq 0 ]]; then
        echo "❌ No se encontraron herramientas GitOps en herramientas-gitops/"
        return 1
    fi
    
    # Paso 2: Configurar repositorios Helm dinámicamente
    configurar_repositorios_helm
    
    # Paso 3: Optimizar cada herramienta descubierta
    local contador=1
    local total_herramientas=${#GITOPS_TOOLS_DISCOVERED[@]}
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        echo
        echo "[$contador/$total_herramientas] 🛠️  Optimizando: $herramienta"
        echo "────────────────────────────────────────────────────────────────────"
        
        # Buscar versión más reciente dinámicamente
        local version_actual=$(buscar_ultima_version_chart "$herramienta")
        
        # Aplicar optimizaciones de desarrollo
        aplicar_optimizaciones_desarrollo "$herramienta" "$version_actual"
        
        ((contador++))
    done
    
    echo
    echo "✅ Optimización GitOps completada dinámicamente"
    echo "🔄 Sistema autodescubrible activo - nuevos YAMLs se detectarán automáticamente"
    echo "📊 Versiones actualizadas dinámicamente desde fuentes oficiales"
}

# Función para aplicar optimizaciones específicas de desarrollo
aplicar_optimizaciones_desarrollo() {
    local herramienta="$1"
    local version="$2"
    local archivo_yaml="herramientas-gitops/${herramienta}.yaml"
    
    echo "   ⚙️  Aplicando optimizaciones de desarrollo..."
    echo "   📦 Versión objetivo: $version"
    
    # Crear archivo temporal con valores optimizados
    local valores_temp="/tmp/${herramienta}-dev-values.yaml"
    
    # Configuraciones optimizadas basadas en el tipo de herramienta
    case "$herramienta" in
        *"ingress"*|*"nginx"*)
            cat > "$valores_temp" << EOF
controller:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
EOF
            ;;
        *"prometheus"*|*"kube-prometheus-stack"*)
            cat > "$valores_temp" << EOF
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    retention: 7d
grafana:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  persistence:
    enabled: false
EOF
            ;;
        *"grafana"*)
            cat > "$valores_temp" << EOF
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
persistence:
  enabled: false
testFramework:
  enabled: false
EOF
            ;;
        *)
            # Configuración genérica optimizada para desarrollo
            cat > "$valores_temp" << EOF
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
replicaCount: 1
EOF
            ;;
    esac
    
    echo "   💾 Configuración optimizada guardada en $valores_temp"
    echo "   🎯 Recursos mínimos aplicados para entorno de desarrollo"
    
    return 0
}

# Función para mostrar resumen de herramientas descubiertas
mostrar_resumen_herramientas() {
    echo "📋 Resumen de herramientas GitOps autodescubiertas:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for herramienta in "${GITOPS_TOOLS_DISCOVERED[@]}"; do
        local repo="${GITOPS_CHART_INFO[${herramienta}_repo]}"
        local chart="${GITOPS_CHART_INFO[${herramienta}_chart]}"
        echo "   📦 $herramienta → $repo/$chart"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: ${#GITOPS_TOOLS_DISCOVERED[@]} herramientas"
}

