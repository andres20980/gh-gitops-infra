#!/bin/bash

# Muestra ayuda detallada del instalador principal
mostrar_ayuda_completa() {
    echo "GitOps en Español Infrastructure"
    echo "Uso: ./instalar.sh [comando] [opciones]"
    echo ""
    echo "Comandos:" 
    echo "  completo                 Ejecuta todas las fases en orden"
    echo "  fase-01                  Permisos y prerrequisitos"
    echo "  fase-02                  Dependencias"
    echo "  fase-03                  Clusters (dev, pre, pro)"
    echo "  fase-04                  ArgoCD"
    echo "  fase-05                  Bootstrap Gitea + Argo Apps"
    echo "  fase-06                  Aplicaciones de ejemplo"
    echo "  fase-07                  Finalización"
    echo ""
    echo "Opciones comunes:"
    echo "  --log-file <ruta>        Archivo de log"
    echo "  --timeout <seg>          Timeout operaciones (si aplica)"
    echo "  --log-level <nivel>      Nivel de log (DEBUG/INFO/...)"
}

ejecutar_proceso_completo_impl() {
    # Definir el directorio de las fases
    local fases_dir="$SCRIPTS_DIR/fases"

    # Comprobar si el directorio de fases existe
    if [[ ! -d "$fases_dir" ]]; then
        log_error "El directorio de fases '$fases_dir' no existe."
        return 1
    fi

    # Crear un array con las fases ordenadas
    local fases=()
    while IFS= read -r -d '' file; do
        fases+=("$file")
    done < <(find "$fases_dir" -maxdepth 1 -name "??-*.sh" -print0 | sort -z)

    # Comprobar si se encontraron fases
    if [[ ${#fases[@]} -eq 0 ]]; then
        log_warning "No se encontraron fases de instalación en '$fases_dir'."
        return 0
    fi

    # Ejecutar cada fase
    for fase_script in "${fases[@]}"; do
        log_section "Ejecutando fase: $(basename "$fase_script")"

        # Usar 'source' para que la fase se ejecute en el mismo contexto de shell
        if ! source "$fase_script"; then
            log_error "La fase '$(basename "$fase_script")' falló."
            # Preguntar al usuario si desea continuar
            if ! confirmar "Se ha producido un error. ¿Desea intentar continuar con la siguiente fase?"; then
                log_error "Instalación abortada por el usuario."
                return 1
            fi
        fi

        # Convención: cada fase define función main(); ejecutarla tras el source
        if declare -F main >/dev/null 2>&1; then
            if ! main; then
                log_error "La fase '$(basename "$fase_script")' retornó error."
                if ! confirmar "¿Continuar con la siguiente fase?"; then
                    log_error "Instalación abortada por el usuario."
                    return 1
                fi
            fi
        else
            log_warning "La fase '$(basename "$fase_script")' no define función main(); se continúa."
        fi
    done

    log_success "Todas las fases de instalación se han ejecutado."
}


verificar_dependencias_criticas() {
    check_all_dependencies
}

# Confirmación interactiva segura (auto-continúa en entornos no interactivos)
confirmar() {
    local prompt="${1:-¿Desea continuar? [S/n]}"
    if [[ -t 0 ]]; then
        read -r -p "$prompt " resp || true
        case "${resp:-S}" in
            s|S|si|SI|y|Y|yes|YES) return 0 ;;
            *) return 1 ;;
        esac
    else
        # No TTY: continuar por defecto
        log_info "Entorno no interactivo: continuar por defecto"
        return 0
    fi
}

# Ejecutar una fase individual por número (ej: "01", "02", "05", etc.)
ejecutar_fase_individual_impl() {
    local fase_id="$1"; shift || true
    local fases_dir="$SCRIPTS_DIR/fases"

    if [[ -z "$fase_id" ]]; then
        log_error "Debe indicar el número de fase (ej: 01, 02, 03)"
        return 1
    fi

    if [[ ! -d "$fases_dir" ]]; then
        log_error "El directorio de fases '$fases_dir' no existe."
        return 1
    fi

    # Buscar scripts que coincidan con el número de fase
    local matches=()
    while IFS= read -r -d '' f; do
        matches+=("$f")
    done < <(find "$fases_dir" -maxdepth 1 -name "${fase_id}-*.sh" -print0 | sort -z)

    if [[ ${#matches[@]} -eq 0 ]]; then
        log_error "No se encontró ninguna fase con ID '${fase_id}'"
        return 1
    fi

    # Ejecutar todas las coincidencias (p.ej., 05 tiene varias subfases)
    local fase_script
    for fase_script in "${matches[@]}"; do
        log_section "Ejecutando fase: $(basename "$fase_script")"

        if ! source "$fase_script"; then
            log_error "La fase '$(basename "$fase_script")' no pudo cargarse."
            return 1
        fi

        if declare -F main >/dev/null 2>&1; then
            if ! main "$@"; then
                log_error "La fase '$(basename "$fase_script")' retornó error."
                if ! confirmar "¿Continuar con la siguiente fase encontrada?"; then
                    log_error "Instalación abortada por el usuario."
                    return 1
                fi
            fi
        else
            log_warning "La fase '$(basename "$fase_script")' no define función main(); se continúa."
        fi
    done

    log_success "Fase(s) '${fase_id}' ejecutada(s) correctamente."
}
