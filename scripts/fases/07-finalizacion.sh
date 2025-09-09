#!/bin/bash

# ============================================================================
# FASE 7: FINALIZACIÓN Y REPORTE
# ============================================================================
# Genera reporte final y muestra información de acceso
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


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
    
    # 3. Exponer UIs de herramientas (port-forwards locales) y mostrar accesos
    log_section "🌐 Accesos a UIs de Herramientas"
    if [[ -f "$PROJECT_ROOT/scripts/accesos-herramientas.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/accesos-herramientas.sh" start || true
        bash "$PROJECT_ROOT/scripts/accesos-herramientas.sh" status || true
    else
        log_warning "No se encontró scripts/accesos-herramientas.sh"
    fi
    # ArgoCD
    show_argocd_access

    # Pausa breve para que los port-forward queden estables
    sleep 5

    # 4. Validación de herramientas: estado ArgoCD (Synced+Healthy) y acceso UI
    log_section "✅ Validación de Herramientas (Estado + UI)"
    validar_herramientas_y_uis || true
    
    # 4. Mensaje final con próximos pasos
    log_section "🎉 Instalación GitOps Completada"
    
    log_info "📝 PRÓXIMOS PASOS:"
    log_info "   1. Acceder a ArgoCD (ver URL arriba)"
    log_info "   2. UIs locales expuestas (http://localhost:8081..8091)."
    log_info "   3. Revisar apps en argo-apps/ y aplicaciones/"
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

# ==============================================
# Funciones auxiliares de validación de la fase
# ==============================================

validar_herramientas_y_uis() {
    local -a tools_apps
    local herramientas_dir="$PROJECT_ROOT/herramientas-gitops/activas"
    local f base app ok_apps=true ok_ui=true

    # Construir lista de aplicaciones esperadas en base a los ficheros activos
    while IFS= read -r -d '' f; do
        base="$(basename "$f")"; app="${base%.yaml}"
        tools_apps+=("$app")
    done < <(find "$herramientas_dir" -maxdepth 1 -name "*.yaml" -print0 | sort -z)

    log_info "Comprobando estado en ArgoCD (Synced + Healthy)..."
    for app in "${tools_apps[@]}"; do
        local hs ss
        hs=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        ss=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        if [[ "$hs" == "Healthy" && "$ss" == "Synced" ]]; then
            log_success "  ${app}: Synced + Healthy"
        else
            log_warning "  ${app}: sync=$ss health=$hs"
            ok_apps=false
        fi
    done

    # Comprobar accesibilidad de UIs por puerto local (port-forward ya iniciado)
    log_info "Comprobando accesibilidad de UIs locales..."
    _check_ui https argocd 8080 true || ok_ui=false
    _check_ui http grafana 8081 false || ok_ui=false
    _check_ui http prometheus 8082 false || ok_ui=false
    _check_ui http alertmanager 8083 false || ok_ui=false
    _check_ui http jaeger 8084 false || ok_ui=false
    _check_ui http kargo 8085 false || ok_ui=false
    _check_ui http loki 8086 false || ok_ui=false
    _check_ui http minio 8087 false || ok_ui=false
    _check_ui http gitea 8088 false || ok_ui=false
    _check_ui http argo-workflows 8089 false || ok_ui=false
    _check_ui http argo-rollouts 8091 false || ok_ui=false

    log_section "📋 Accesos Unificados (Resumen)"
    echo "- ArgoCD: https://127.0.0.1:8080 — login: admin / <secreto inicial>"
    echo "- Gitea:  http://localhost:8088 — login: admin / admin1234"
    echo "- Grafana: http://localhost:8081 — login: admin / admin123"
    echo "- Prometheus:     http://localhost:8082 — sin login"
    echo "- Alertmanager:   http://localhost:8083 — sin login"
    echo "- Jaeger:         http://localhost:8084 — sin login"
    echo "- Kargo:          http://localhost:8085 — sin login"
    echo "- Loki API:       http://localhost:8086 — sin login (vía Grafana)"
    echo "- MinIO:          http://localhost:8087 — según chart (podemos fijarlo)"
    echo "- Argo Workflows: http://localhost:8089 — sin login"
    echo "- Argo Rollouts:  http://localhost:8091 — sin login"

    if $ok_apps && $ok_ui; then
        log_success "✅ Instalación validada: todas las herramientas Synced+Healthy y UIs accesibles"
        return 0
    else
        log_warning "⚠️ Validación incompleta: revisa los elementos anteriores"
        return 1
    fi
}

_check_ui() {
    local scheme="$1" name="$2" port="$3" insecure_tls="${4:-false}"
    local url
    local tries=15; local i=0
    if [[ "$scheme" == https* ]]; then
        url="https://127.0.0.1:${port}/"
        while (( i < tries )); do
            if curl -k -sS --max-time 5 -o /dev/null "$url"; then
                log_success "  UI ${name}: $url (OK)"
                return 0
            fi
            sleep 1; ((i++))
        done
        log_warning "  UI ${name}: $url (sin respuesta)"
        return 1
    else
        url="http://127.0.0.1:${port}/"
        while (( i < tries )); do
            if curl -L -sS --max-time 5 -o /dev/null "$url" || curl -L -sS --max-time 5 -o /dev/null "${url}login"; then
                log_success "  UI ${name}: $url (OK)"
                return 0
            fi
            sleep 1; ((i++))
        done
        log_warning "  UI ${name}: $url (sin respuesta)"
        return 1
    fi
}
