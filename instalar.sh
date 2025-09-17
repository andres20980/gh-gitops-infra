#!/bin/bash

# ============================================================================
# INSTALADOR PRINCIPAL MODULAR - GitOps en Español Infrastructure v3.0.0
# ============================================================================
# Orquestador mínimo y modular para infraestructura GitOps
# Principios: DRY, Single Responsibility, Separación de responsabilidades
# ============================================================================

set -euo pipefail

# ============================================================================
# AUTOCONTENCIÓN - Carga automática de dependencias
# ============================================================================

# Detectar PROJECT_ROOT automáticamente
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT

# Cargar sistema de autocontención
if [[ -f "$PROJECT_ROOT/scripts/comun/arranque.sh" ]]; then
    # shellcheck source=scripts/comun/arranque.sh
    source "$PROJECT_ROOT/scripts/comun/arranque.sh"
else
    echo "❌ Error: Sistema de autocontención no encontrado" >&2
    echo "   Archivo requerido: scripts/comun/arranque.sh" >&2
    exit 1
fi

# ============================================================================
# FUNCIONES MÍNIMAS DEL ORQUESTADOR
# ============================================================================

# Mostrar ayuda (delegada a helper)
mostrar_ayuda() {
    if [[ -f "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh" ]]; then
        source "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh"
        mostrar_ayuda_completa
    else
        echo "GitOps en Español Infrastructure v3.0.0"
        echo "Uso: ./instalar.sh [OPCIONES]"
        echo "Ver documentación completa en README.md"
    fi
}

# Función principal (solo orquestación)
main() {
    # Forzar modo no-interactivo por defecto (installer debe ser cero-interacción)
    export ASSUME_YES="true"

    # Extraer comando (primer argumento que no sea una opción)
    local comando=""
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*)
                # Es una opción, añadir a args
                if [[ "$1" == "--log-file" || "$1" == "--timeout" || "$1" == "--log-level" ]]; then
                    args+=("$1" "$2")
                    shift 2
                else
                    args+=("$1")
                    shift
                fi
                ;;
            *)
                # Es el comando si aún no lo hemos encontrado
                if [[ -z "$comando" ]]; then
                    comando="$1"
                    shift
                else
                    # Resto de argumentos
                    args+=("$1")
                    shift
                fi
                ;;
        esac
    done
    
    # Si no hay comando, usar "completo" por defecto
    [[ -z "$comando" ]] && comando="completo"
    
    case "$comando" in
        --ayuda|--help|-h)
            mostrar_ayuda
            exit 0
            ;;
        --version)
            echo "GitOps en Español Infrastructure v$GITOPS_VERSION"
            exit 0
            ;;
        from-scratch)
            # Reset total (limpieza profunda) y ejecución fase por fase para aislar fallos
            local prev_fail_fast="${FAIL_FAST_ON_PHASE_ERROR:-__unset__}"
            export FAIL_FAST_ON_PHASE_ERROR="true"
            restore_fail_fast() {
                if [[ "$prev_fail_fast" == "__unset__" ]]; then
                    unset FAIL_FAST_ON_PHASE_ERROR
                else
                    export FAIL_FAST_ON_PHASE_ERROR="$prev_fail_fast"
                fi
            }
            echo "[FROM-SCRATCH] 🧹 Reset total profundo (fase-00 --deep-nuke)"
            if ! ejecutar_fase_individual 00 --deep-nuke --yes; then
                log_error "Reset falló"
                restore_fail_fast
                exit 1
            fi

            echo "[FROM-SCRATCH] 🔍 Ejecutando fases de instalación una a una"
            local fases_dir="${FASES_DIR:-$PROJECT_ROOT/scripts/fases}"
            if [[ ! -d "$fases_dir" ]]; then
                echo "[FROM-SCRATCH] ❌ Directorio de fases no encontrado: $fases_dir" >&2
                exit 1
            fi

            local -a fases_a_ejecutar=()
            declare -A fases_vistas=()
            while IFS= read -r -d '' fase_path; do
                local fase_basename
                fase_basename="$(basename "$fase_path")"
                local fase_id="${fase_basename%%-*}"
                # Ya ejecutamos la fase 00 manualmente; la 06 se maneja en la validación final
                if [[ "$fase_id" == "00" || "$fase_id" == "06" ]]; then
                    continue
                fi
                if [[ -z "${fases_vistas[$fase_id]:-}" ]]; then
                    fases_vistas[$fase_id]=1
                    fases_a_ejecutar+=("$fase_id")
                fi
            done < <(find "$fases_dir" -maxdepth 1 -type f -name "??-*.sh" -print0 | sort -z)

            if [[ ${#fases_a_ejecutar[@]} -eq 0 ]]; then
                echo "[FROM-SCRATCH] ⚠️ No se encontraron fases posteriores a 00 para ejecutar." >&2
            fi

            local fase_id
            for fase_id in "${fases_a_ejecutar[@]}"; do
                echo "[FROM-SCRATCH] ▶️ Ejecutando fase-${fase_id}"
                if ! ejecutar_fase_individual "$fase_id"; then
                    echo "[FROM-SCRATCH] ❌ Falló la fase-${fase_id}. Revisa el log anterior para más detalles." >&2
                    restore_fail_fast
                    exit 1
                fi
                echo "[FROM-SCRATCH] ✅ fase-${fase_id} completada"
            done

            # Reintentos de validación final (fase-06)
            local intentos=0
            local max_intentos=3
            while (( intentos < max_intentos )); do
                intentos=$((intentos+1))
                echo "[FROM-SCRATCH] Intento de validación ${intentos}/${max_intentos}: fase-06"
                if ejecutar_fase_individual 06; then
                    echo "[FROM-SCRATCH] ✅ Instalación validada (Synced+Healthy + UIs accesibles)"
                    restore_fail_fast
                    exit 0
                fi
                echo "[FROM-SCRATCH] Reintentando en 15s..."; sleep 15
            done
            echo "[FROM-SCRATCH] ❌ No se logró validar la instalación tras ${max_intentos} intentos" >&2
            restore_fail_fast
            exit 1
            ;;
        fase-*)
            # Extraer número de fase
            local fase_num="${comando#fase-}"
            if [[ ${#args[@]} -gt 0 ]]; then
                ejecutar_fase_individual "$fase_num" "${args[@]}"
            else
                ejecutar_fase_individual "$fase_num"
            fi
            ;;
        completo|"")
            # Instalación EXCELENTE por defecto (desatendida):
            # - Ejecuta TODAS las fases disponibles en orden (incluida 00-reset si existe)
            # - Ejecuta validación final (fase-06) con reintentos para asegurar Synced+Healthy + UIs accesibles
            if [[ ${#args[@]} -gt 0 ]]; then
                ejecutar_proceso_completo "${args[@]}"
            else
                ejecutar_proceso_completo
            fi

            # Reintentos de validación final (fase-06)
            local intentos=0
            local max_intentos=3
            while (( intentos < max_intentos )); do
                intentos=$((intentos+1))
                echo "[COMPLETO] Intento de validación ${intentos}/${max_intentos}: fase-06"
                if ejecutar_fase_individual 06; then
                    echo "[COMPLETO] ✅ Instalación validada (Synced+Healthy + UIs accesibles)"
                    exit 0
                fi
                echo "[COMPLETO] Reintentando en 15s..."; sleep 15
            done
            echo "[COMPLETO] ❌ No se logró validar la instalación tras ${max_intentos} intentos" >&2
            exit 1
            ;;
        *)
            log_error "Comando desconocido: $comando"
            mostrar_ayuda
            exit 1
            ;;
    esac
}

# Ejecutar fase individual (delegada a helper)
ejecutar_fase_individual() {
    local fase="$1"
    shift || true
    
    # Cargar helper de instalación
    source "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh"
    
    # Delegar ejecución
    ejecutar_fase_individual_impl "$fase" "$@"
}

# Ejecutar proceso completo (delegada a helper)
ejecutar_proceso_completo() {
    # Cargar helper de instalación
    source "$PROJECT_ROOT/scripts/comun/helpers/instalador-helper.sh"
    
    # Delegar ejecución
    ejecutar_proceso_completo_impl "$@"
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Ejecutar función principal con manejo de errores
if ! main "$@"; then
    log_error "Instalación falló"
    exit 1
fi
