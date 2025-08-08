#!/bin/bash
# ============================================================================
# MÓDULO DE OPTIMIZACIÓN Y DESARROLLO GITOPS - v3.0.0
# ============================================================================
# Especializado en optimizaciones específicas para desarrollo
# Máximo: 300 líneas - Principio de Responsabilidad Única

set +u  # Desactivar verificación de variables no definidas

# Función para hacer commit y push de los cambios antes del despliegue
hacer_commit_push_cambios() {
    echo
    echo "🔄 Realizando commit y push de cambios de versiones..."
    
    # Verificar si hay cambios para commitear
    if git diff --quiet && git diff --cached --quiet; then
        echo "ℹ️  No hay cambios para commitear"
        return 0
    fi
    
    # Mostrar archivos modificados
    mostrar_archivos_modificados
    
    # Procesar commit y push
    local fecha=$(date '+%Y-%m-%d %H:%M:%S')
    local mensaje="feat: actualización automática versiones GitOps - $fecha"
    
    if crear_commit_cambios "$mensaje"; then
        hacer_push_rama_actual
    else
        echo "❌ Error al crear commit"
        return 1
    fi
}

# Función para mostrar archivos modificados
mostrar_archivos_modificados() {
    echo "📝 Archivos modificados:"
    git status --porcelain | head -10
}

# Función para crear commit de cambios
crear_commit_cambios() {
    local mensaje="$1"
    
    echo "📦 Agregando cambios al staging..."
    git add .
    
    echo "💾 Creando commit: $mensaje"
    if git commit -m "$mensaje"; then
        echo "✅ Commit creado exitosamente"
        return 0
    else
        return 1
    fi
}

# Función para hacer push a rama actual
hacer_push_rama_actual() {
    local rama_actual=$(git branch --show-current)
    echo "🚀 Haciendo push a rama: $rama_actual"
    
    if git push origin "$rama_actual"; then
        echo "✅ Push completado exitosamente"
        echo "🌐 Cambios sincronizados con el repositorio remoto"
        
        # Esperar un momento para que GitHub procese los cambios
        echo "⏳ Esperando sincronización con GitHub (5 segundos)..."
        sleep 5
        return 0
    else
        echo "❌ Error al hacer push"
        echo "⚠️  Los cambios están commiteados localmente pero no sincronizados"
        return 1
    fi
}

# Función para aplicar la App of Tools a ArgoCD
aplicar_app_of_tools() {
    echo
    echo "🚀 Aplicando App of Tools a ArgoCD..."
    
    local app_tools_file="argo-apps/app-of-tools-gitops.yaml"
    
    if [[ ! -f "$app_tools_file" ]]; then
        echo "❌ Archivo $app_tools_file no encontrado"
        return 1
    fi
    
    echo "📋 Aplicando $app_tools_file..."
    if kubectl apply -f "$app_tools_file"; then
        echo "✅ App of Tools aplicada exitosamente"
        verificar_aplicacion_creada
    else
        echo "❌ Error al aplicar App of Tools"
        return 1
    fi
    
    return 0
}

# Función para verificar que la aplicación se creó
verificar_aplicacion_creada() {
    echo "🔍 Verificando aplicación en ArgoCD..."
    sleep 3
    
    if kubectl get application app-of-tools-gitops -n argocd >/dev/null 2>&1; then
        echo "✅ Aplicación app-of-tools-gitops creada en ArgoCD"
        mostrar_estado_inicial_aplicacion
    else
        echo "⚠️ Aplicación creada pero aún no visible en ArgoCD"
    fi
}

# Función para mostrar estado inicial de aplicación
mostrar_estado_inicial_aplicacion() {
    echo "📊 Estado inicial de la aplicación:"
    kubectl get application app-of-tools-gitops -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" 2>/dev/null || echo "   (Estado aún no disponible)"
}

# Función para aplicar optimizaciones específicas de desarrollo
aplicar_optimizaciones_desarrollo() {
    local herramienta="$1"
    local version="$2"
    local archivo_yaml="herramientas-gitops/${herramienta}.yaml"
    
    echo "   ⚙️  Aplicando optimizaciones de desarrollo..."
    echo "   📦 Versión objetivo: $version"
    
    # Actualizar la versión en el archivo YAML
    actualizar_version_yaml "$archivo_yaml" "$version"
    
    # Crear directorio para valores de desarrollo
    local dir_values_dev="herramientas-gitops/values-dev"
    mkdir -p "$dir_values_dev"
    
    # Generar configuración optimizada
    local valores_dev_file="$dir_values_dev/${herramienta}-dev-values.yaml"
    generar_configuracion_optimizada "$herramienta" "$valores_dev_file"
    
    # Actualizar referencia a valores de desarrollo
    actualizar_referencia_valores_dev "$archivo_yaml" "$valores_dev_file" "$herramienta"
    
    return 0
}

# Función para actualizar versión en YAML
actualizar_version_yaml() {
    local archivo_yaml="$1"
    local version="$2"
    
    if [[ "$version" != "latest" && -f "$archivo_yaml" ]]; then
        echo "   🔄 Actualizando versión en $archivo_yaml..."
        
        # Crear backup del archivo original
        cp "$archivo_yaml" "${archivo_yaml}.backup"
        
        # Actualizar targetRevision si existe
        if grep -q "targetRevision:" "$archivo_yaml"; then
            sed -i "s/targetRevision:.*/targetRevision: \"$version\"/" "$archivo_yaml"
            verificar_actualizacion_version "$archivo_yaml" "$version"
        else
            echo "   ℹ️  No se encontró targetRevision en el archivo"
        fi
    fi
}

# Función para verificar actualización de versión
verificar_actualizacion_version() {
    local archivo_yaml="$1"
    local version="$2"
    
    local version_actualizada=$(grep "targetRevision:" "$archivo_yaml" | sed 's/.*targetRevision:\s*//' | tr -d '"' | tr -d "'")
    if [[ "$version_actualizada" == "$version" ]]; then
        echo "   ✅ Versión verificada en archivo: $version_actualizada"
        rm -f "${archivo_yaml}.backup"
    else
        echo "   ⚠️  La actualización no se reflejó correctamente"
        mv "${archivo_yaml}.backup" "$archivo_yaml"
    fi
}

# Función para generar configuración optimizada por herramienta
generar_configuracion_optimizada() {
    local herramienta="$1"
    local valores_dev_file="$2"
    
    case "$herramienta" in
        *"ingress"*|*"nginx"*)
            generar_config_ingress_nginx "$valores_dev_file"
            ;;
        *"prometheus"*|*"kube-prometheus-stack"*)
            generar_config_prometheus "$valores_dev_file"
            ;;
        *"grafana"*)
            generar_config_grafana "$valores_dev_file"
            ;;
        *"cert-manager"*)
            generar_config_cert_manager "$valores_dev_file"
            ;;
        *)
            generar_config_generica "$valores_dev_file" "$herramienta"
            ;;
    esac
    
    echo "   💾 Configuración optimizada guardada en $valores_dev_file"
    echo "   🎯 Recursos mínimos aplicados para entorno de desarrollo"
}

# Función para generar configuración de Ingress NGINX
generar_config_ingress_nginx() {
    local valores_dev_file="$1"
    
    cat > "$valores_dev_file" << 'EOF'
# Configuración optimizada para desarrollo - Ingress NGINX
controller:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  service:
    type: NodePort
  admissionWebhooks:
    enabled: false
EOF
}

# Función para generar configuración de Prometheus
generar_config_prometheus() {
    local valores_dev_file="$1"
    
    cat > "$valores_dev_file" << 'EOF'
# Configuración optimizada para desarrollo - Prometheus Stack
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
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 2Gi
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
  testFramework:
    enabled: false
  adminPassword: admin123
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
EOF
}

# Función para generar configuración de Grafana
generar_config_grafana() {
    local valores_dev_file="$1"
    
    cat > "$valores_dev_file" << 'EOF'
# Configuración optimizada para desarrollo - Grafana
adminUser: admin
adminPassword: admin123
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
persistence:
  enabled: true
  size: 1Gi
testFramework:
  enabled: false
serviceMonitor:
  enabled: false
EOF
}

# Función para generar configuración de Cert Manager
generar_config_cert_manager() {
    local valores_dev_file="$1"
    
    cat > "$valores_dev_file" << 'EOF'
# Configuración optimizada para desarrollo - Cert-Manager
installCRDs: true
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
webhook:
  resources:
    requests:
      cpu: 20m
      memory: 32Mi
    limits:
      cpu: 50m
      memory: 64Mi
cainjector:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi
EOF
}

# Función para generar configuración genérica
generar_config_generica() {
    local valores_dev_file="$1"
    local herramienta="$2"
    
    cat > "$valores_dev_file" << EOF
# Configuración optimizada para desarrollo - $herramienta
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
replicaCount: 1
EOF
}

# Función para actualizar referencia a valores de desarrollo
actualizar_referencia_valores_dev() {
    local archivo_yaml="$1"
    local valores_dev_file="$2"
    local herramienta="$3"
    
    echo "   🔧 Actualizando referencia a valores de desarrollo..."
    
    # Crear backup
    cp "$archivo_yaml" "${archivo_yaml}.backup"
    
    # Verificar y agregar referencia si existe sección helm
    if grep -q "helm:" "$archivo_yaml"; then
        if ! grep -q "valueFiles:" "$archivo_yaml"; then
            sed -i '/helm:/a\      valueFiles:\n        - values-dev/'$herramienta'-dev-values.yaml' "$archivo_yaml"
            echo "   ✅ Agregada referencia a valores de desarrollo"
        fi
    else
        echo "   ℹ️  No se encontró sección helm en $archivo_yaml"
    fi
    
    # Verificar cambios
    if grep -q "values-dev/${herramienta}-dev-values.yaml" "$archivo_yaml"; then
        echo "   ✅ Referencia a valores de desarrollo confirmada"
        rm -f "${archivo_yaml}.backup"
    else
        echo "   ⚠️  No se pudo agregar la referencia automáticamente"
        mv "${archivo_yaml}.backup" "$archivo_yaml"
    fi
}
