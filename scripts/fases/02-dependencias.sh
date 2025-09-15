#!/bin/bash

# ============================================================================
# FASE 2: VERIFICACIÓN Y ACTUALIZACIÓN DE DEPENDENCIAS
# ============================================================================
# Verifica e instala todas las dependencias necesarias del sistema
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail


# ============================================================================
# FASE 2: DEPENDENCIAS
# ============================================================================

main() {
    log_section "📦 FASE 2: Verificación y Actualización de Dependencias"
    
    # Verificar dependencias actuales
    if check_all_dependencies; then
        log_success "✅ Todas las dependencias están instaladas"
        show_dependencies_summary
    else
        log_info "🔧 Instalando dependencias faltantes..."
        if ! install_all_dependencies; then
            log_error "❌ No fue posible instalar todas las dependencias"
            return 1
        fi
        # Asegurar kind instalado (post-reset puede faltar)
        if ! command -v kind >/dev/null 2>&1; then
            log_info "🧩 Instalando kind explícitamente..."
            if ! install_kind; then
                log_error "❌ No se pudo instalar kind"
                return 1
            fi
        fi
        # Verificación final
        if ! check_all_dependencies; then
            log_error "❌ Dependencias aún incompletas tras la instalación"
            return 1
        fi
        show_dependencies_summary
    fi
        # Limpieza de logs y marcas obsoletas
        log_info "🧹 Limpiando logs obsoletos..."
        rm -f "${PROJECT_ROOT:-.}/logs"/*.tmp || true
        rm -f "${PROJECT_ROOT:-.}/logs/.fase-"* || true

        # Comprobación de dependencia externa: Gitea (instalación en WSL)
        # Variables esperadas: GITEA_PROTOCOL, GITEA_HOST, GITEA_PORT, GITEA_ADMIN_USER, GITEA_ADMIN_PASS
        if [[ -n "${GITEA_HOST:-}" ]]; then
            GITEA_PROTOCOL=${GITEA_PROTOCOL:-http}
            GITEA_PORT=${GITEA_PORT:-3000}
            GITEA_ADMIN_USER=${GITEA_ADMIN_USER:-admin}
            GITEA_ADMIN_PASS=${GITEA_ADMIN_PASS:-admin1234}
            GITEA_URL="${GITEA_PROTOCOL}://${GITEA_HOST}:${GITEA_PORT}"
            log_info "🔎 Comprobando Gitea en ${GITEA_URL} ..."
            if curl -sS --max-time 5 "${GITEA_URL}" >/dev/null 2>&1; then
                log_success "✅ Gitea responde en ${GITEA_URL}"
                # Intentar crear repo 'admin/gitops-infra' si no existe
                API_CREATE="${GITEA_URL}/api/v1/orgs/admin/repos"
                API_GET="${GITEA_URL}/api/v1/repos/admin/gitops-infra"
                if curl -sS -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" "${API_GET}" >/dev/null 2>&1; then
                    log_info "ℹ️ Repositorio 'admin/gitops-infra' ya existe"
                else
                    log_info "✨ Creando repositorio 'admin/gitops-infra' en Gitea..."
                    create_payload='{"name":"gitops-infra","description":"Infra repo for gitops POC","private":false}'
                    if curl -sS -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" -H "Content-Type: application/json" -d "${create_payload}" "${API_CREATE}" >/dev/null 2>&1; then
                        log_success "✅ Repositorio creado"
                        # Empujar el repo actual (si git está disponible)
                        if command -v git >/dev/null 2>&1; then
                            if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                                remote_url="${GITEA_URL}/admin/gitops-infra.git"
                                log_info "⤴️ Push inicial del repo actual a ${remote_url}"
                                git push --mirror "${remote_url}" || log_error "Falló git push --mirror; empujar manualmente"
                            fi
                        fi
                    else
                        log_error "❌ No fue posible crear el repo en Gitea via API"
                    fi
                fi
            else
                log_warn "⚠️ Gitea no responde en ${GITEA_URL}. Instale Gitea en WSL Linux (minimal) y configure las variables GITEA_HOST/GITEA_PORT."
                log_info "Sugerencia: en WSL instale con Docker o paquete, cree repo 'admin/gitops-infra' y copie el repo actual"
            fi
        else
            log_warn "⚠️ Gitea no configurado. Trate Gitea como dependencia externa y siga las instrucciones en README.md"
        fi

        log_success "✅ Fase 2 completada exitosamente"
}


# ============================================================================
# EJECUCIÓN DIRECTA
# ============================================================================

# Solo ejecutar si se llama directamente (no sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
