#!/bin/bash

# ============================================================================
# FASE 3: CONFIGURACIÓN DOCKER Y CLUSTERS
# ============================================================================
# Configura Docker automáticamente y crea el cluster gitops-dev
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


# ============================================================================
# FASE 3: CLUSTERS
# ============================================================================

main() {
    log_section "FASE 3: Configuración Docker y Clusters"

    # 1. Configurar Docker
    log_info "Configurando Docker..."
    if ! check_docker_daemon; then
        init_docker_wsl
        setup_docker_user
    else
        log_success "Docker ya está configurado"
    fi

    # 2. Crear cluster de desarrollo (con dimensionado dinámico opcional)
    log_info "Configurando cluster Kubernetes..."
    if ! check_cluster_available "gitops-dev"; then
        create_dev_cluster
        ensure_metrics_server "gitops-dev"
    else
        log_success "Cluster gitops-dev ya está disponible"
        ensure_metrics_server "gitops-dev"
    fi

    # 3. Opcional: crear clusters mínimos de pre/pro si se solicita
    if [[ "${CREAR_PREPRO:-false}" == "true" ]]; then
        log_info "Creando clusters mínimos pre/pro..."
        create_promotion_clusters || log_warning "Algunas creaciones de pre/pro fallaron"
    fi

    # 4. Resumen
    show_clusters_summary
    log_success "Fase 3 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
