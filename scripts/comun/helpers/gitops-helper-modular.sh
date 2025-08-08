#!/bin/bash
# ============================================================================
# GITOPS HELPER MODULAR - v3.0.0
# ============================================================================
# Orquestador principal que carga módulos especializados
# Máximo: 100 líneas - Principio de Responsabilidad Única

set +u  # Desactivar verificación de variables no definidas

# Directorio base de módulos
MODULES_DIR="$(dirname "${BASH_SOURCE[0]}")/../modules"

# Cargar todos los módulos especializados
echo "🔄 Cargando módulos GitOps especializados..."

# Módulo de Autodescubrimiento (200-300 líneas)
source "$MODULES_DIR/autodiscovery.sh"
echo "   ✅ Módulo de autodescubrimiento cargado"

# Módulo de Gestión de Versiones (200-300 líneas)
source "$MODULES_DIR/version-manager.sh"
echo "   ✅ Módulo de gestión de versiones cargado"

# Módulo de Monitoreo y Verificación (300-400 líneas)
source "$MODULES_DIR/monitoring.sh"
echo "   ✅ Módulo de monitoreo cargado"

# Módulo de Reporting y Estado (200-300 líneas)
source "$MODULES_DIR/reporting.sh"
echo "   ✅ Módulo de reporting cargado"

# Módulo de Optimización y Desarrollo (200-300 líneas)
source "$MODULES_DIR/optimization.sh"
echo "   ✅ Módulo de optimización cargado"

echo "✅ Todos los módulos GitOps cargados exitosamente"

# Variable global para tiempo de inicio
INICIO_DESPLIEGUE=$(date '+%Y-%m-%d %H:%M:%S')

# Función principal de optimización GitOps dinámico
ejecutar_optimizacion_gitops() {
    echo "🚀 Iniciando optimización GitOps v3.0.0 - Sistema modular autodescubrible"
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
    optimizar_herramientas_descubiertas
    
    # Paso 4: Commit y push de cambios antes de desplegar
    hacer_commit_push_cambios
    
    # Paso 5: Aplicar App of Tools a ArgoCD
    aplicar_app_of_tools
    
    # Paso 6: Esperar a que todas las aplicaciones estén Synced y Healthy
    echo
    echo "⏳ Esperando a que todas las herramientas GitOps estén Synced y Healthy..."
    esperar_aplicaciones_completas
    
    # Paso 7: Generar reporte final
    generar_reporte_despliegue
    mostrar_metricas_rendimiento
}

# Función para optimizar herramientas descubiertas
optimizar_herramientas_descubiertas() {
    local contador=1
    local total_herramientas=${#GITOPS_TOOLS_DISCOVERED[@]}
    
    echo
    echo "🛠️  Optimizando ${total_herramientas} herramientas descubiertas..."
    
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
    echo "✅ Optimización de herramientas completada"
    echo "🔄 Sistema modular autodescubrible activo"
    echo "📊 Versiones actualizadas dinámicamente desde fuentes oficiales"
}
