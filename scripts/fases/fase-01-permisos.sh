#!/bin/bash

# ============================================================================
# FASE 1: GESTIÓN INTELIGENTE DE PERMISOS
# ============================================================================

# Gestión inteligente de permisos para proceso totalmente desatendido
gestionar_permisos_inteligente() {
    local fase_actual="$1"
    
    # Si estamos ejecutándose como root y necesitamos usuario normal
    if [[ "$EUID" -eq 0 ]] && [[ "$fase_actual" == "clusters" ]]; then
        log_warning "⚠️ Detectado: Ejecutándose como root pero clusters necesitan usuario normal"
        log_info "🔄 SOLUCIÓN AUTOMÁTICA: Re-ejecutando como usuario normal para proceso desatendido..."
        
        # Obtener el usuario real (no root)
        local usuario_real="${SUDO_USER:-$(logname 2>/dev/null || who am i | awk '{print $1}' || echo "asanchez")}"
        local home_real=$(eval echo "~$usuario_real" 2>/dev/null || echo "/home/$usuario_real")
        
        log_info "👤 Continuando como usuario: $usuario_real"
        log_info "🏠 Home directory: $home_real"
        
        # Cambiar ownership del repositorio al usuario correcto si es necesario
        if [[ "$(stat -c '%U' "$PROJECT_ROOT")" == "root" ]]; then
            log_info "🔧 Ajustando permisos del repositorio..."
            chown -R "$usuario_real:$usuario_real" "$PROJECT_ROOT" 2>/dev/null || true
        fi
        
        # Preservar todas las variables de entorno importantes
        local env_vars=""
        [[ "$VERBOSE" == "true" ]] && env_vars+=" VERBOSE=true"
        [[ "$DEBUG" == "true" ]] && env_vars+=" DEBUG=true"
        [[ "$DRY_RUN" == "true" ]] && env_vars+=" DRY_RUN=true"
        [[ -n "$LOG_FILE" ]] && env_vars+=" LOG_FILE='$LOG_FILE'"
        
        # Re-ejecutar como usuario normal con --skip-deps y variables preservadas
        log_info "🚀 Re-ejecutando: sudo -u $usuario_real bash -c 'cd $PROJECT_ROOT &&$env_vars ./instalar.sh --verbose --skip-deps'"
        
        exec sudo -u "$usuario_real" -H bash -c "cd '$PROJECT_ROOT' &&$env_vars ./instalar.sh --verbose --skip-deps"
        
        # Esta línea nunca se ejecutará porque exec reemplaza el proceso
        exit 0
    fi
    
    # Si necesitamos sudo para dependencias pero no somos root
    if [[ "$EUID" -ne 0 ]] && [[ "$fase_actual" == "dependencias" ]]; then
        log_info "🔐 Detectado: Dependencias necesitan privilegios sudo"
        log_info "🚀 SOLUCIÓN AUTOMÁTICA: Auto-escalando para instalación de dependencias..."
        log_info "📋 Después continuará automáticamente como usuario normal"
        
        # Preservar argumentos originales
        local args_originales=""
        [[ "$VERBOSE" == "true" ]] && args_originales+=" --verbose"
        [[ "$DEBUG" == "true" ]] && args_originales+=" --debug"
        [[ "$DRY_RUN" == "true" ]] && args_originales+=" --dry-run"
        [[ "$SOLO_DEV" == "true" ]] && args_originales+=" --solo-dev"
        [[ -n "$LOG_FILE" ]] && args_originales+=" --log-file '$LOG_FILE'"
        
        log_info "🔄 Re-ejecutando: sudo $0$args_originales"
        
        # Re-ejecutar con sudo manteniendo argumentos
        exec sudo "$0" $args_originales
        
        # Esta línea nunca se ejecutará
        exit 0
    fi
    
    return 0
}

# Verificar contexto de permisos
verificar_contexto_permisos() {
    local fase="$1"
    
    case "$fase" in
        "dependencias")
            if [[ "$EUID" -ne 0 ]]; then
                log_info "🔐 Fase dependencias requiere privilegios sudo"
                return 1
            fi
            ;;
        "clusters"|"argocd"|"apps")
            if [[ "$EUID" -eq 0 ]]; then
                log_warning "⚠️ Fase $fase no debe ejecutarse como root"
                return 1
            fi
            ;;
    esac
    
    return 0
}
