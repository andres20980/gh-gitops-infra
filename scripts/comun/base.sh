#!/bin/bash

# ============================================================================
# GITOPS INFRA - Cargador Universal de Librerías DRY
# ============================================================================
# Responsabilidad: Cargar todas las librerías DRY consolidadas
# Principios: DRY perfecto, Single source of truth, Modular
# ============================================================================

set -euo pipefail

# ============================================================================
# RUTAS Y CONFIGURACIÓN
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="$SCRIPT_DIR/lib"
readonly CONFIG_FILE="$SCRIPT_DIR/config.sh"

# ============================================================================
# CARGA DE LIBRERÍAS DRY
# ============================================================================

# Cargar configuración
if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
fi

# Cargar librerías DRY en orden de dependencia
readonly DRY_LIBS=(
	"validation.sh"     # Logging y validación (base)
	"versions.sh"       # Detección de versiones y compatibilidad
	"sizing.sh"         # Estimación y límites de recursos del sistema
	"dependencies.sh"   # Dependencias del sistema
	"kubernetes.sh"     # Gestión de clusters
	"gitops.sh"         # Herramientas GitOps
)

_base_supports_emoji() {
	# Emojis solo si TTY y locale UTF-8; puede forzarse con LOG_EMOJI_MODE
	local mode="${LOG_EMOJI_MODE:-auto}"
	if [[ "$mode" == "never" ]]; then return 1; fi
	if [[ "$mode" == "always" ]]; then return 0; fi
	# auto
	[[ -t 1 ]] || return 1
	local locale_env="${LC_ALL:-${LANG:-}}"
	[[ "$locale_env" =~ [Uu][Tt][Ff]-?8 ]] || return 1
	return 0
}

_base_should_show_lib_load() {
	# Mostrar carga de librerías solo en TTY por defecto; configurable
	case "${LOG_SHOW_LIB_LOAD:-auto}" in
		always) return 0 ;;
		never) return 1 ;;
		*) [[ -t 1 ]] && return 0 || return 1 ;;
	esac
}

# Función para cargar librería de forma segura
load_lib() {
	local lib="$1"
	local lib_path="$LIB_DIR/$lib"
    
	if [[ -f "$lib_path" ]]; then
		# No usar funciones de log aún, pueden no estar cargadas; usar echo simple
		# Cargar primero, luego loguear condicionalmente
		source "$lib_path"
		if _base_should_show_lib_load; then
			if _base_supports_emoji; then
				echo "✅ Librería cargada: $lib"
			else
				echo "[OK] Librería cargada: $lib"
			fi
		fi
	else
		if _base_supports_emoji; then
			echo "❌ Error: Librería no encontrada: $lib_path" >&2
		else
			echo "[ERROR] Librería no encontrada: $lib_path" >&2
		fi
		exit 1
	fi
}

# Cargar todas las librerías DRY
for lib in "${DRY_LIBS[@]}"; do
	load_lib "$lib"
done

# Activar modo "pretty" por defecto en TTY (sin pisar overrides del usuario)
if [[ -t 1 ]] && [[ "${LOG_AUTO_PRETTY:-on}" != "off" ]]; then
	: "${LOG_COLOR_MODE:=always}"
	: "${LOG_EMOJI_MODE:=always}"
	: "${LOG_SHOW_WELCOME:=always}"
	: "${LOG_SHOW_BANNER:=always}"
fi

# ============================================================================
# FUNCIONES PRINCIPALES CONSOLIDADAS
# ============================================================================

# Inicialización completa del sistema
init_gitops_system() {
	log_section "🚀 Inicialización Sistema GitOps"
    
	# 1. Configurar logging
	setup_logging "${LOG_FILE:-}" "${VERBOSE:-false}" "${QUIET:-false}"
    
	# 2. Mostrar resumen del sistema
	show_system_summary
    
	# 3. Validar comandos básicos
	validate_commands "curl" "grep" "awk" "sed"
    
	# 4. Validar conectividad
	validate_network
    
	log_success "✅ Sistema GitOps inicializado"
}

# Instalación completa paso a paso
install_complete_gitops() {
	log_section "🎯 Instalación GitOps Completa"
    
	# Inicializar sistema
	init_gitops_system
    
	# Fases de instalación
	log_info "📋 Ejecutando fases de instalación..."
    
	# Fase 1: Dependencias
	if ! check_all_dependencies; then
		log_info "🔧 Instalando dependencias..."
		install_all_dependencies
	fi
    
	# Fase 2: Docker y permisos
	if ! check_docker_daemon; then
		log_info "🐳 Configurando Docker..."
		init_docker_wsl
		setup_docker_user
	fi
    
	# Fase 3: Cluster
	if ! check_cluster_available "gitops-dev"; then
		log_info "☸️ Creando cluster desarrollo..."
		create_dev_cluster
	fi
    
	# Fase 4: Stack GitOps
	log_info "🛠️ Instalando stack GitOps..."
	install_gitops_stack
    
	log_success "✅ Instalación GitOps completada"
	show_gitops_summary
}

# Mostrar ayuda
show_help() {
	log_section "💡 Sistema GitOps - Ayuda"
    
	echo "FUNCIONES DISPONIBLES:"
	echo "  init_gitops_system        - Inicializar sistema"
	echo "  install_complete_gitops   - Instalación completa"
	echo "  check_all_dependencies    - Verificar dependencias"
	echo "  install_all_dependencies  - Instalar dependencias"
	echo "  create_dev_cluster        - Crear cluster desarrollo"
	echo "  install_gitops_stack      - Instalar stack GitOps"
	echo "  show_gitops_summary       - Mostrar resumen"
	echo "  show_system_summary       - Mostrar sistema"
	echo ""
	echo "VARIABLES DE ENTORNO:"
	echo "  VERBOSE=true              - Modo verbose"
	echo "  QUIET=true                - Modo silencioso"
	echo "  LOG_FILE=/path/log        - Archivo de log"
	echo "  SOLO_DEV=true             - Solo cluster dev"
	echo "  LOG_COLOR_MODE=auto|always|never"
	echo "  LOG_EMOJI_MODE=auto|always|never"
	echo "  LOG_SHOW_WELCOME=auto|always|never"
	echo "  LOG_SHOW_LIB_LOAD=auto|always|never"
	echo "  LOG_SHOW_BANNER=auto|always|never"
	echo ""
	echo "EJEMPLO:"
	echo "  source scripts/comun/base.sh && use_pretty_logs && install_complete_gitops"
}

# Exportar funciones principales
export -f init_gitops_system
export -f install_complete_gitops
export -f show_help

# Mensaje de bienvenida (solo en TTY o si se fuerza)
case "${LOG_SHOW_WELCOME:-auto}" in
	always)
		# Banner opcional
		if [[ "${LOG_SHOW_BANNER:-auto}" != "never" ]]; then
			show_banner "GitOps Infra" "DRY · Modular · Automático"
		fi
		log_info "Sistema GitOps DRY cargado - usa 'show_help' para ver opciones"
		;;
	never)
		;;
	*)
		if [[ -t 1 ]]; then
			if [[ "${LOG_SHOW_BANNER:-auto}" != "never" ]]; then
				show_banner "GitOps Infra" "DRY · Modular · Automático"
			fi
			log_info "Sistema GitOps DRY cargado - usa 'show_help' para ver opciones"
		fi
		;;
esac
