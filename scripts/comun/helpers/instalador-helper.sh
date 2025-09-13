#!/bin/bash

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
    done

    log_success "Todas las fases de instalación se han ejecutado."
}

ejecutar_fase_individual_impl() {
    local fase_num="$1"
    shift
    local args=("$@")

    # Validar que el número de fase es un número
    if ! [[ "$fase_num" =~ ^[0-9]+$ ]]; then
        log_error "El número de fase debe ser un entero. Se recibió: '$fase_num'"
        return 1
    fi

    # Formatear el número de fase con cero a la izquierda si es necesario (e.g., 1 -> 01)
    printf -v fase_num_padded "%02d" "$fase_num"

    local fase_script_pattern="$SCRIPTS_DIR/fases/$fase_num_padded-"*.sh
    local fase_scripts_found=($fase_script_pattern)

    # Verificar si se encontró exactamente un script de fase
    if [[ ${#fase_scripts_found[@]} -eq 0 ]] || [[ ! -f "${fase_scripts_found[0]}" ]]; then
        log_error "No se encontró un script para la fase '$fase_num_padded'."
        log_info "Verifique que exista un archivo como '$fase_num_padded-nombre.sh' en el directorio $SCRIPTS_DIR/fases/"
        return 1
    elif [[ ${#fase_scripts_found[@]} -gt 1 ]]; then
        log_error "Se encontraron múltiples scripts para la fase '$fase_num_padded':"
        for script in "${fase_scripts_found[@]}"; do
            log_error "  - $(basename "$script")"
        done
        return 1
    fi

    local fase_script="${fase_scripts_found[0]}"
    log_section "Ejecutando fase individual: $(basename "$fase_script")"

    # 'source' carga el script en el shell actual, haciendo que sus funciones (como 'main')
    # estén disponibles. Luego, llamamos a 'main' explícitamente.
    if source "$fase_script"; then
        if command -v main >/dev/null 2>&1; then
            if main "${args[@]}"; then
                log_success "Fase '$(basename "$fase_script")' completada exitosamente."
            else
                log_error "La ejecución de la fase '$(basename "$fase_script")' falló (la función 'main' devolvió un error)."
                return 1
            fi
        else
            log_warning "El script de fase '$(basename "$fase_script")' fue cargado pero no contiene una función 'main'. Se considera completado."
        fi
    else
        log_error "Falló la carga del script de fase '$(basename "$fase_script")'."
        return 1
    fi
}


verificar_dependencias_criticas() {
    check_all_dependencies
}
