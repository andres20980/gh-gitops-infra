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
        if ! create_dev_cluster; then
            log_error "No se pudo crear el cluster gitops-dev"
            return 1
        fi
        # Verificar disponibilidad tras la creación
        if ! check_cluster_available "gitops-dev"; then
            log_error "Cluster gitops-dev no está disponible tras la creación"
            return 1
        fi
        ensure_metrics_server "gitops-dev"
    else
        log_success "Cluster gitops-dev ya está disponible"
        ensure_metrics_server "gitops-dev"
    fi

    # 3. Crear clusters mínimos de pre/pro (por defecto activado)
    #    Requisito del proyecto: disponer de gitops-pre y gitops-pro siempre
    log_info "Creando clusters mínimos pre/pro..."
    if ! create_promotion_clusters; then
        log_warning "Algunas creaciones de pre/pro fallaron"
    fi

    # 4. Mitigación DNS: si el host usa DNS privados, forzar CoreDNS a 1.1.1.1/8.8.8.8 en los tres clusters
    log_info "Asegurando DNS funcional en clusters..."
    ensure_cluster_dns "gitops-dev" || true
    ensure_cluster_dns "gitops-pre" || true
    ensure_cluster_dns "gitops-pro" || true

    # 5. Resumen
    show_clusters_summary
    # Validación final: el cluster dev debe existir sí o sí
    if kind get clusters 2>/dev/null | grep -q "^gitops-dev$"; then
        log_success "Fase 3 completada exitosamente"
        return 0
    else
        log_error "Fase 3 incompleta: no hay cluster gitops-dev disponible"
        return 1
    fi
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
