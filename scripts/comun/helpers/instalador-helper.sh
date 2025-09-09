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


verificar_dependencias_criticas() {
    check_all_dependencies
}
