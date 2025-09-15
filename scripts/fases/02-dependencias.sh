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

        # Comprobación/instalación autónoma de Gitea
        # Prioridad: si usuario exportó GITEA_HOST lo usamos; si no, intentar instalar en WSL; si no hay WSL, desplegar fallback in-cluster minimal
        GITEA_PROTOCOL=${GITEA_PROTOCOL:-http}
        GITEA_PORT=${GITEA_PORT:-3000}
        GITEA_ADMIN_USER=${GITEA_ADMIN_USER:-admin}
        GITEA_ADMIN_PASS=${GITEA_ADMIN_PASS:-admin1234}

        if [[ -n "${GITEA_HOST:-}" ]]; then
            GITEA_URL="${GITEA_PROTOCOL}://${GITEA_HOST}:${GITEA_PORT}"
            log_info "🔎 Usando Gitea configurado por usuario en ${GITEA_URL}"
        else
            # Detectar WSL (preferido para instalación local minimal fuera del cluster)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                log_info "🖥️ Entorno WSL detectado: intentar desplegar Gitea en WSL con Docker"
                # Lanzar Gitea con docker (si no existe)
                if ! docker ps --filter "name=gitea-wsl" --format '{{.Names}}' | grep -q .; then
                    log_info "🚀 Iniciando contenedor Gitea minimal (gitea/gitea:1.24.3-rootless)"
                    docker run -d --name gitea-wsl -p ${GITEA_PORT}:3000 -e USER_UID=1000 -e USER_GID=1000 gitea/gitea:1.24.3-rootless || true
                    sleep 4
                else
                    log_info "ℹ️ Contenedor gitea-wsl ya está corriendo"
                fi
                GITEA_HOST="localhost"
                GITEA_URL="${GITEA_PROTOCOL}://${GITEA_HOST}:${GITEA_PORT}"
            else
                # Fallback: desplegar manifiesto minimal in-cluster (solo para pruebas locales)
                log_info "⚠️ No se detectó GITEA_HOST ni WSL. Aplicando fallback in-cluster minimal para pruebas."
                kubectl apply -f "${PROJECT_ROOT}/pruebas-manifests/gitea-minimal.yaml" || true
                GITEA_HOST="gitea-http-stable.gitea.svc.cluster.local"
                GITEA_URL="http://${GITEA_HOST}:3000"
            fi
        fi

        # Esperar a que Gitea responda (timeout razonable)
        log_info "⏳ Esperando a que Gitea responda en ${GITEA_URL}..."
        local tries=0; local max_tries=30; local ok=false
        while (( tries < max_tries )); do
            if curl -sS --max-time 5 "${GITEA_URL}" >/dev/null 2>&1; then
                ok=true; break
            fi
            sleep 2; tries=$((tries+1))
        done

        if [[ "$ok" != true ]]; then
            log_warn "⚠️ Gitea no respondió en ${GITEA_URL} tras ${max_tries} intentos. Continuando sin crear repo automático."
        else
            log_success "✅ Gitea responde en ${GITEA_URL}"
            API_CREATE="${GITEA_URL}/api/v1/orgs/admin/repos"
            API_GET="${GITEA_URL}/api/v1/repos/admin/gitops-infra"
            if curl -sS -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" "${API_GET}" >/dev/null 2>&1; then
                log_info "ℹ️ Repositorio 'admin/gitops-infra' ya existe"
            else
                log_info "✨ Creando repositorio 'admin/gitops-infra' en Gitea..."
                create_payload='{"name":"gitops-infra","description":"Infra repo for gitops POC","private":false}'
                if curl -sS -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASS}" -H "Content-Type: application/json" -d "${create_payload}" "${API_CREATE}" >/dev/null 2>&1; then
                    log_success "✅ Repositorio creado"
                    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                        remote_url="${GITEA_URL}/admin/gitops-infra.git"
                        log_info "⤴️ Push inicial del repo actual a ${remote_url}"
                        git push --mirror "${remote_url}" || log_warn "Falló git push --mirror; empujar manualmente"
                    fi
                else
                    log_error "❌ No fue posible crear el repo en Gitea via API"
                fi
            fi
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
