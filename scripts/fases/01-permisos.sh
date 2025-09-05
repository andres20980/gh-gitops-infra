#!/bin/bash

# ============================================================================
# FASE 1: CONFIGURACIÓN DE PERMISOS Y PRERREQUISITOS
# ============================================================================
# Configura permisos sudo y verifica prerrequisitos del sistema
# Usa librerías DRY consolidadas - Zero duplicación
# ============================================================================

set -euo pipefail

# ============================================================================
# CARGA DE LIBRERÍAS DRY
# ============================================================================

# Detectar directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cargar librerías DRY consolidadas
source "$SCRIPT_DIR/../comun/base.sh"

# ============================================================================
# FASE 1: PERMISOS
# ============================================================================

main() {
    log_section "🔐 FASE 1: Configuración de Permisos y Prerrequisitos"
    
    # 1. Verificar sistema
    log_info "💻 Verificando sistema..."
    show_system_summary
    validate_linux_distro
    validate_system_resources
    
    # 2. Configurar permisos sudo si es posible (no bloquear en entornos no interactivos)
    log_info "🔐 Verificando permisos sudo..."
    if sudo -n true 2>/dev/null; then
        log_success "✅ Permisos sudo ya disponibles"
    else
        if sudo -v >/dev/null 2>&1; then
            log_info "🔑 Configurando sudo sin contraseña para operaciones GitOps..."
            echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/gitops-$USER" > /dev/null || true
            sudo chmod 440 "/etc/sudoers.d/gitops-$USER" || true
            log_success "✅ Permisos sudo configurados"
        else
            log_warning "⚠️ No se ha podido obtener sudo de forma no interactiva; se continuará sin modificar sudoers"
        fi
    fi
    
    # 3. Verificar conectividad
    validate_network
    
    log_success "✅ Fase 1 completada exitosamente"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
