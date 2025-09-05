#!/bin/bash

# ============================================================================
# FASE 7: FINALIZACIÓN Y REPORTE
# ============================================================================
# Genera reporte final y muestra información de acceso
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail

# ============================================================================
# CARGA DE LIBRERÍAS DRY
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar librerías DRY consolidadas
source "$SCRIPT_DIR/../comun/base.sh"

# ============================================================================
# FASE 7: FINALIZACIÓN
# ============================================================================

main() {
    log_section "🏁 FASE 7: Finalización y Reporte"
    
    # 1. Generar reporte del sistema
    log_info "📊 Generando reporte final..."
    generate_validation_report "/tmp/gitops-final-report.txt"
    
    # 2. Mostrar resumen de todas las herramientas
    show_system_summary
    show_clusters_summary
    show_gitops_summary
    
    # 3. Mostrar información de acceso
    show_argocd_access
    
    # 4. Mensaje final con próximos pasos
    log_section "🎉 Instalación GitOps Completada"
    
    log_info "📝 PRÓXIMOS PASOS:"
    log_info "   1. Acceder a ArgoCD para gestionar aplicaciones"
    log_info "   2. Usar: ./scripts/accesos-herramientas.sh start"
    log_info "   3. Generar apps: ./scripts/herramientas/generador-aplicaciones.sh"
    log_info "   4. Ver reporte: cat /tmp/gitops-final-report.txt"
    log_info ""
    log_info "📚 DOCUMENTACIÓN:"
    log_info "   - Arquitectura: documentacion/ARQUITECTURA_DETALLADA.md"
    log_info "   - Troubleshooting: documentacion/TROUBLESHOOTING.md"
    log_info "   - Contribuir: documentacion/CONTRIBUCION.md"
    log_info ""
    log_success "✅ Sistema GitOps listo para usar!"
    
    log_success "✅ Fase 7 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
