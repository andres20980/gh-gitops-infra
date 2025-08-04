#!/bin/bash

# ============================================================================
# INSTALADOR DE DEPENDENCIAS - Sistema Ubuntu desde cero
# ============================================================================
# Instalador modular y optimizado para dependencias del sistema Ubuntu
# Preparación completa del entorno para infraestructura GitOps
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="GitOps Dependencies Installer"

# Directorios
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BIBLIOTECAS_DIR="$(dirname "$SCRIPT_DIR")/bibliotecas"

# Cargar librerías base si existen
for lib in "base" "logging" "validacion" "versiones"; do
    lib_path="$BIBLIOTECAS_DIR/${lib}.sh"
    if [[ -f "$lib_path" ]]; then
        # shellcheck source=/dev/null
        source "$lib_path" 2>/dev/null || true
    fi
done

# Fallback para funciones básicas si las librerías no están disponibles
if ! command -v log_info >/dev/null 2>&1; then
    log_info() { echo "[INFO] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_success() { echo "[SUCCESS] $*"; }
    log_warning() { echo "[WARNING] $*"; }
    log_section() { echo; echo "=== $* ==="; }
    log_subsection() { echo "--- $* ---"; }
    es_dry_run() { [[ "${DRY_RUN:-false}" == "true" ]]; }
    comando_existe() { command -v "$1" >/dev/null 2>&1; }
fi

# ============================================================================
# CONFIGURACIÓN DE VARIABLES
# ============================================================================

# Control de flujo
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
FORCE="${FORCE:-false}"
SKIP_UPDATES="${SKIP_UPDATES:-false}"
ONLY_VERIFY="${ONLY_VERIFY:-false}"

# Configuración de instalación
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
INSTALL_KUBECTL="${INSTALL_KUBECTL:-true}"
INSTALL_HELM="${INSTALL_HELM:-true}"
INSTALL_MINIKUBE="${INSTALL_MINIKUBE:-true}"
INSTALL_ARGOCD_CLI="${INSTALL_ARGOCD_CLI:-true}"
INSTALL_EXTRAS="${INSTALL_EXTRAS:-true}"

# ============================================================================
# LISTAS DE DEPENDENCIAS
# ============================================================================

# Dependencias básicas del sistema
readonly SYSTEM_PACKAGES=(
    "curl"
    "wget"
    "jq"
    "git"
    "unzip"
    "tar"
    "gzip"
    "apt-transport-https"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "software-properties-common"
    "build-essential"
)

# Herramientas adicionales útiles
readonly EXTRA_PACKAGES=(
    "vim"
    "htop"
    "tree"
    "ncdu"
    "tmux"
    "bash-completion"
)

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

# Validar que estamos en Ubuntu
validar_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log_error "Este script está diseñado para Ubuntu"
        log_info "Sistema detectado: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"' 2>/dev/null || echo 'Desconocido')"
        return 1
    fi
    
    log_info "Sistema Ubuntu detectado correctamente"
    return 0
}

# Validar permisos de sudo
validar_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_error "Se requieren permisos sudo para continuar"
        log_info "Ejecuta: sudo -v"
        return 1
    fi
    
    log_info "Permisos sudo verificados"
    return 0
}

# Validar conectividad a internet
validar_conectividad() {
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "No hay conectividad a internet"
        return 1
    fi
    
    log_info "Conectividad a internet verificada"
    return 0
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN DE PAQUETES
# ============================================================================

# Actualizar sistema
actualizar_sistema() {
    log_subsection "Actualizando Sistema"
    
    if [[ "$SKIP_UPDATES" == "true" ]]; then
        log_info "Omitiendo actualización del sistema"
        return 0
    fi
    
    if es_dry_run; then
        log_info "[DRY-RUN] apt update && apt upgrade -y"
        return 0
    fi
    
    log_info "Actualizando lista de paquetes..."
    if ! sudo apt update; then
        log_error "Error actualizando lista de paquetes"
        return 1
    fi
    
    log_info "Actualizando paquetes del sistema..."
    if ! sudo apt upgrade -y; then
        log_error "Error actualizando paquetes del sistema"
        return 1
    fi
    
    log_success "Sistema actualizado correctamente"
    return 0
}

# Instalar paquetes básicos
instalar_paquetes_basicos() {
    log_subsection "Instalando Paquetes Básicos"
    
    local paquetes_faltantes=()
    
    # Verificar qué paquetes faltan
    for paquete in "${SYSTEM_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$paquete "; then
            paquetes_faltantes+=("$paquete")
        fi
    done
    
    if [[ ${#paquetes_faltantes[@]} -eq 0 ]]; then
        log_success "Todos los paquetes básicos ya están instalados"
        return 0
    fi
    
    log_info "Instalando ${#paquetes_faltantes[@]} paquetes faltantes: ${paquetes_faltantes[*]}"
    
    if es_dry_run; then
        log_info "[DRY-RUN] apt install -y ${paquetes_faltantes[*]}"
        return 0
    fi
    
    if ! sudo apt install -y "${paquetes_faltantes[@]}"; then
        log_error "Error instalando paquetes básicos"
        return 1
    fi
    
    log_success "Paquetes básicos instalados correctamente"
    return 0
}

# Instalar paquetes adicionales
instalar_paquetes_extras() {
    if [[ "$INSTALL_EXTRAS" != "true" ]]; then
        log_info "Omitiendo instalación de paquetes adicionales"
        return 0
    fi
    
    log_subsection "Instalando Paquetes Adicionales"
    
    if es_dry_run; then
        log_info "[DRY-RUN] apt install -y ${EXTRA_PACKAGES[*]}"
        return 0
    fi
    
    log_info "Instalando herramientas adicionales: ${EXTRA_PACKAGES[*]}"
    
    if ! sudo apt install -y "${EXTRA_PACKAGES[@]}"; then
        log_warning "Algunos paquetes adicionales no se pudieron instalar"
    else
        log_success "Paquetes adicionales instalados correctamente"
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN DE DOCKER
# ============================================================================

# Instalar Docker
instalar_docker() {
    if [[ "$INSTALL_DOCKER" != "true" ]]; then
        log_info "Omitiendo instalación de Docker"
        return 0
    fi
    
    log_subsection "Instalando Docker"
    
    # Verificar si Docker ya está instalado
    if comando_existe docker && ! [[ "$FORCE" == "true" ]]; then
        local version_actual
        version_actual=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "desconocida")
        log_info "Docker ya está instalado (versión: $version_actual)"
        return 0
    fi
    
    if es_dry_run; then
        log_info "[DRY-RUN] Instalaría Docker desde el repositorio oficial"
        return 0
    fi
    
    # Eliminar versiones anteriores
    log_info "Eliminando versiones anteriores de Docker..."
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Añadir clave GPG de Docker
    log_info "Añadiendo clave GPG de Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Añadir repositorio de Docker
    log_info "Añadiendo repositorio de Docker..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Actualizar lista de paquetes
    sudo apt update
    
    # Instalar Docker
    log_info "Instalando Docker Engine..."
    if ! sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        log_error "Error instalando Docker"
        return 1
    fi
    
    # Configurar Docker para usuario no root
    log_info "Configurando Docker para usuario no root..."
    sudo usermod -aG docker "$USER"
    
    # Habilitar y iniciar servicio Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Verificar instalación
    if docker version >/dev/null 2>&1; then
        local version
        version=$(docker version --format '{{.Server.Version}}')
        log_success "Docker $version instalado correctamente"
    else
        log_warning "Docker instalado pero requiere reinicio de sesión para permisos"
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN DE KUBECTL
# ============================================================================

# Instalar kubectl
instalar_kubectl() {
    if [[ "$INSTALL_KUBECTL" != "true" ]]; then
        log_info "Omitiendo instalación de kubectl"
        return 0
    fi
    
    log_subsection "Instalando kubectl"
    
    # Verificar si kubectl ya está instalado
    if comando_existe kubectl && ! [[ "$FORCE" == "true" ]]; then
        local version_actual
        version_actual=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/v//' || echo "desconocida")
        log_info "kubectl ya está instalado (versión: $version_actual)"
        return 0
    fi
    
    if es_dry_run; then
        log_info "[DRY-RUN] Instalaría kubectl desde el repositorio oficial"
        return 0
    fi
    
    # Obtener versión estable
    local version_estable
    version_estable=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    
    log_info "Instalando kubectl $version_estable..."
    
    # Descargar kubectl
    curl -LO "https://dl.k8s.io/release/$version_estable/bin/linux/amd64/kubectl"
    
    # Verificar checksum
    curl -LO "https://dl.k8s.io/release/$version_estable/bin/linux/amd64/kubectl.sha256"
    if ! echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check; then
        log_error "Checksum de kubectl no válido"
        rm -f kubectl kubectl.sha256
        return 1
    fi
    
    # Instalar kubectl
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    rm -f kubectl.sha256
    
    # Configurar autocompletado
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    
    # Verificar instalación
    if comando_existe kubectl; then
        local version
        version=$(kubectl version --client --output=json | jq -r '.clientVersion.gitVersion')
        log_success "kubectl $version instalado correctamente"
    else
        log_error "Error verificando instalación de kubectl"
        return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN DE HELM
# ============================================================================

# Instalar Helm
instalar_helm() {
    if [[ "$INSTALL_HELM" != "true" ]]; then
        log_info "Omitiendo instalación de Helm"
        return 0
    fi
    
    log_subsection "Instalando Helm"
    
    # Verificar si Helm ya está instalado
    if comando_existe helm && ! [[ "$FORCE" == "true" ]]; then
        local version_actual
        version_actual=$(helm version --template='{{.Version}}' 2>/dev/null | sed 's/v//' || echo "desconocida")
        log_info "Helm ya está instalado (versión: $version_actual)"
        return 0
    fi
    
    if es_dry_run; then
        log_info "[DRY-RUN] Instalaría Helm usando script oficial"
        return 0
    fi
    
    # Instalar Helm usando script oficial
    log_info "Descargando e instalando Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Configurar autocompletado
    helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null
    
    # Verificar instalación
    if comando_existe helm; then
        local version
        version=$(helm version --template='{{.Version}}')
        log_success "Helm $version instalado correctamente"
    else
        log_error "Error verificando instalación de Helm"
        return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN DE MINIKUBE
# ============================================================================

# Instalar Minikube
instalar_minikube() {
    if [[ "$INSTALL_MINIKUBE" != "true" ]]; then
        log_info "Omitiendo instalación de Minikube"
        return 0
    fi
    
    log_subsection "Instalando Minikube"
    
    # Verificar si Minikube ya está instalado
    if comando_existe minikube && ! [[ "$FORCE" == "true" ]]; then
        local version_actual
        version_actual=$(minikube version --output=json 2>/dev/null | jq -r '.minikubeVersion' | sed 's/v//' || echo "desconocida")
        log_info "Minikube ya está instalado (versión: $version_actual)"
        return 0
    fi
    
    if es_dry_run; then
        log_info "[DRY-RUN] Instalaría Minikube desde GitHub releases"
        return 0
    fi
    
    # Detectar arquitectura
    local arch
    arch=$(uname -m)
    case "$arch" in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
        *) 
            log_error "Arquitectura no soportada: $arch"
            return 1
            ;;
    esac
    
    # Descargar Minikube
    log_info "Descargando Minikube para $arch..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${arch}
    
    # Instalar Minikube
    chmod +x minikube-linux-${arch}
    sudo mv minikube-linux-${arch} /usr/local/bin/minikube
    
    # Configurar autocompletado
    minikube completion bash | sudo tee /etc/bash_completion.d/minikube > /dev/null
    
    # Verificar instalación
    if comando_existe minikube; then
        local version
        version=$(minikube version --output=json | jq -r '.minikubeVersion')
        log_success "Minikube $version instalado correctamente"
    else
        log_error "Error verificando instalación de Minikube"
        return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE INSTALACIÓN DE ARGOCD CLI
# ============================================================================

# Instalar ArgoCD CLI
instalar_argocd_cli() {
    if [[ "$INSTALL_ARGOCD_CLI" != "true" ]]; then
        log_info "Omitiendo instalación de ArgoCD CLI"
        return 0
    fi
    
    log_subsection "Instalando ArgoCD CLI"
    
    # Verificar si ArgoCD CLI ya está instalado
    if comando_existe argocd && ! [[ "$FORCE" == "true" ]]; then
        local version_actual
        version_actual=$(argocd version --client --output json 2>/dev/null | jq -r '.client.Version' | sed 's/v//' || echo "desconocida")
        log_info "ArgoCD CLI ya está instalado (versión: $version_actual)"
        return 0
    fi
    
    if es_dry_run; then
        log_info "[DRY-RUN] Instalaría ArgoCD CLI desde GitHub releases"
        return 0
    fi
    
    # Obtener última versión
    local version_latest
    version_latest=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r '.tag_name')
    
    # Detectar arquitectura
    local arch
    arch=$(uname -m)
    case "$arch" in
        "x86_64") arch="amd64" ;;
        "aarch64") arch="arm64" ;;
        *) 
            log_error "Arquitectura no soportada: $arch"
            return 1
            ;;
    esac
    
    # Descargar ArgoCD CLI
    log_info "Descargando ArgoCD CLI $version_latest para $arch..."
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$version_latest/argocd-linux-${arch}
    
    # Instalar ArgoCD CLI
    chmod +x argocd
    sudo mv argocd /usr/local/bin/
    
    # Configurar autocompletado
    argocd completion bash | sudo tee /etc/bash_completion.d/argocd > /dev/null
    
    # Verificar instalación
    if comando_existe argocd; then
        local version
        version=$(argocd version --client --output json | jq -r '.client.Version')
        log_success "ArgoCD CLI $version instalado correctamente"
    else
        log_error "Error verificando instalación de ArgoCD CLI"
        return 1
    fi
    
    return 0
}

# ============================================================================
# FUNCIONES DE VERIFICACIÓN
# ============================================================================

# Verificar todas las instalaciones
verificar_instalaciones() {
    log_section "🔍 Verificando Instalaciones"
    
    local herramientas=(
        "docker:Docker"
        "kubectl:kubectl"
        "helm:Helm"
        "minikube:Minikube"
        "argocd:ArgoCD CLI"
    )
    
    local instaladas=0
    local total=0
    
    for herramienta in "${herramientas[@]}"; do
        local cmd="${herramienta%:*}"
        local nombre="${herramienta#*:}"
        
        # Solo verificar si se pidió instalar
        local var_install="INSTALL_$(echo "$cmd" | tr '[:lower:]' '[:upper:]')"
        if [[ "$cmd" == "argocd" ]]; then
            var_install="INSTALL_ARGOCD_CLI"
        fi
        
        if [[ "${!var_install:-true}" == "true" ]]; then
            ((total++))
            
            if comando_existe "$cmd"; then
                local version=""
                case "$cmd" in
                    "docker")
                        version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "error")
                        ;;
                    "kubectl")
                        version=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo "error")
                        ;;
                    "helm")
                        version=$(helm version --template='{{.Version}}' 2>/dev/null || echo "error")
                        ;;
                    "minikube")
                        version=$(minikube version --output=json 2>/dev/null | jq -r '.minikubeVersion' || echo "error")
                        ;;
                    "argocd")
                        version=$(argocd version --client --output json 2>/dev/null | jq -r '.client.Version' || echo "error")
                        ;;
                esac
                
                if [[ "$version" != "error" ]]; then
                    log_success "$nombre: $version ✓"
                    ((instaladas++))
                else
                    log_warning "$nombre: instalado pero con errores"
                fi
            else
                log_error "$nombre: no encontrado ✗"
            fi
        fi
    done
    
    echo
    log_info "Resumen: $instaladas/$total herramientas instaladas correctamente"
    
    if [[ $instaladas -eq $total ]]; then
        log_success "¡Todas las herramientas están listas!"
        return 0
    else
        log_warning "Algunas herramientas no están disponibles"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE AYUDA
# ============================================================================

# Mostrar ayuda
mostrar_ayuda() {
    cat << 'EOF'
Instalador de Dependencias GitOps para Ubuntu

SINTAXIS:
  ./instalar-dependencias.sh [OPCIONES]

OPCIONES:
  --dry-run                 Mostrar qué se haría sin ejecutar comandos
  --verbose                 Salida detallada
  --force                   Forzar reinstalación incluso si ya existe
  --skip-updates            Omitir actualización del sistema
  --only-verify             Solo verificar instalaciones existentes

COMPONENTES:
  --sin-docker              No instalar Docker
  --sin-kubectl             No instalar kubectl
  --sin-helm                No instalar Helm
  --sin-minikube            No instalar Minikube
  --sin-argocd-cli          No instalar ArgoCD CLI
  --sin-extras              No instalar paquetes adicionales

EJEMPLOS:
  ./instalar-dependencias.sh                    # Instalación completa
  ./instalar-dependencias.sh --dry-run          # Ver qué se instalaría
  ./instalar-dependencias.sh --sin-minikube     # Sin Minikube
  ./instalar-dependencias.sh --only-verify      # Solo verificación

VARIABLES DE ENTORNO:
  DRY_RUN                   Modo dry-run (true/false)
  VERBOSE                   Salida detallada (true/false)
  FORCE                     Forzar reinstalación (true/false)
  SKIP_UPDATES              Omitir actualizaciones (true/false)
EOF
}

# ============================================================================
# PROCESAMIENTO DE ARGUMENTOS
# ============================================================================

# Procesar argumentos
procesar_argumentos() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --skip-updates)
                SKIP_UPDATES="true"
                shift
                ;;
            --only-verify)
                ONLY_VERIFY="true"
                shift
                ;;
            --sin-docker)
                INSTALL_DOCKER="false"
                shift
                ;;
            --sin-kubectl)
                INSTALL_KUBECTL="false"
                shift
                ;;
            --sin-helm)
                INSTALL_HELM="false"
                shift
                ;;
            --sin-minikube)
                INSTALL_MINIKUBE="false"
                shift
                ;;
            --sin-argocd-cli)
                INSTALL_ARGOCD_CLI="false"
                shift
                ;;
            --sin-extras)
                INSTALL_EXTRAS="false"
                shift
                ;;
            --ayuda|--help|-h)
                mostrar_ayuda
                exit 0
                ;;
            *)
                log_error "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# AUTO-INSTALACIÓN DESATENDIDA COMPLETA
# ============================================================================

# Función de auto-instalación completa desatendida
auto_instalar_dependencias_completas() {
    log_info "🔍 Detectando dependencias del sistema..."
    
    # Actualizar repositorios primero
    log_info "Actualizando repositorios del sistema..."
    if ! sudo apt-get update -qq; then
        log_warning "Error actualizando repositorios, continuando..."
    fi
    
    # Auto-instalar Docker si no existe
    if ! command -v docker >/dev/null 2>&1; then
        log_info "🐳 Auto-instalando Docker (última versión)..."
        if ! instalar_docker; then
            log_error "Error auto-instalando Docker"
            return 1
        fi
    else
        log_success "✅ Docker ya disponible"
    fi
    
    # Auto-instalar kubectl con versión compatible con minikube
    if ! command -v kubectl >/dev/null 2>&1; then
        log_info "☸️ Auto-instalando kubectl (compatible con minikube)..."
        if ! instalar_kubectl; then
            log_error "Error auto-instalando kubectl"
            return 1
        fi
    else
        log_success "✅ kubectl ya disponible"
    fi
    
    # Auto-instalar Helm última versión
    if ! command -v helm >/dev/null 2>&1; then
        log_info "⚓ Auto-instalando Helm (última versión)..."
        if ! instalar_helm; then
            log_error "Error auto-instalando Helm"
            return 1
        fi
    else
        log_success "✅ Helm ya disponible"
    fi
    
    # Auto-instalar minikube última versión
    if ! command -v minikube >/dev/null 2>&1; then
        log_info "🎯 Auto-instalando minikube (última versión)..."
        if ! instalar_minikube; then
            log_error "Error auto-instalando minikube"
            return 1
        fi
    else
        log_success "✅ minikube ya disponible"
    fi
    
    # Auto-instalar ArgoCD CLI última versión
    if ! command -v argocd >/dev/null 2>&1; then
        log_info "🔄 Auto-instalando ArgoCD CLI (última versión)..."
        if ! instalar_argocd_cli; then
            log_error "Error auto-instalando ArgoCD CLI"
            return 1
        fi
    else
        log_success "✅ ArgoCD CLI ya disponible"
    fi
    
    # Configurar permisos Docker automáticamente
    if groups "$USER" | grep -q docker; then
        log_success "✅ Usuario ya en grupo docker"
    else
        log_info "🔧 Configurando permisos Docker..."
        sudo usermod -aG docker "$USER"
        # Aplicar cambios en la sesión actual
        newgrp docker
        log_success "✅ Permisos Docker configurados"
    fi
    
    log_success "✅ Auto-instalación completa finalizada"
    return 0
}

# Función para uso externo desde el orquestador
instalar_dependencias_completas() {
    auto_instalar_dependencias_completas
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

# Función principal
main() {
    # Procesar argumentos
    procesar_argumentos "$@"
    
    # Mostrar banner
    log_section "📦 $SCRIPT_NAME v$SCRIPT_VERSION"
    
    # Solo verificar si se pidió
    if [[ "$ONLY_VERIFY" == "true" ]]; then
        verificar_instalaciones
        exit $?
    fi
    
    # Validaciones iniciales
    log_section "🔍 Validaciones Iniciales"
    
    if ! validar_ubuntu; then
        exit 1
    fi
    
    if ! validar_sudo; then
        exit 1
    fi
    
    if ! validar_conectividad; then
        exit 1
    fi
    
    # 🚀 AUTO-INSTALACIÓN DESATENDIDA COMPLETA
    log_section "🚀 Auto-Instalación Desatendida Completa"
    log_info "Detectando y auto-instalando últimas versiones disponibles..."
    
    # Auto-detectar y configurar todas las dependencias
    if ! auto_instalar_dependencias_completas; then
        log_error "Error en auto-instalación de dependencias"
        exit 1
    fi
    
    # Intentar auto-instalación si la función está disponible
    if declare -f auto_instalar_dependencias_faltantes >/dev/null 2>&1; then
        auto_instalar_dependencias_faltantes
    else
        log_warning "⚠️ Función de auto-instalación no disponible, continuando con instalación manual"
    fi
    
    # Mostrar configuración
    log_section "⚙️ Configuración"
    log_info "Docker: $INSTALL_DOCKER"
    log_info "kubectl: $INSTALL_KUBECTL"
    log_info "Helm: $INSTALL_HELM"
    log_info "Minikube: $INSTALL_MINIKUBE"
    log_info "ArgoCD CLI: $INSTALL_ARGOCD_CLI"
    log_info "Extras: $INSTALL_EXTRAS"
    log_info "Dry-run: $DRY_RUN"
    log_info "Force: $FORCE"
    echo
    
    # Marcar tiempo de inicio
    local inicio
    inicio=$(date +%s)
    
    # Ejecutar instalaciones
    log_section "🚀 Iniciando Instalación de Dependencias"
    
    # Actualizar sistema
    if ! actualizar_sistema; then
        log_error "Error actualizando sistema"
        exit 1
    fi
    
    # Instalar paquetes básicos
    if ! instalar_paquetes_basicos; then
        log_error "Error instalando paquetes básicos"
        exit 1
    fi
    
    # Instalar paquetes adicionales
    instalar_paquetes_extras
    
    # Instalar Docker
    if ! instalar_docker; then
        log_error "Error instalando Docker"
        exit 1
    fi
    
    # Instalar kubectl
    if ! instalar_kubectl; then
        log_error "Error instalando kubectl"
        exit 1
    fi
    
    # Instalar Helm
    if ! instalar_helm; then
        log_error "Error instalando Helm"
        exit 1
    fi
    
    # Instalar Minikube
    if ! instalar_minikube; then
        log_error "Error instalando Minikube"
        exit 1
    fi
    
    # Instalar ArgoCD CLI
    if ! instalar_argocd_cli; then
        log_error "Error instalando ArgoCD CLI"
        exit 1
    fi
    
    # Calcular tiempo total
    local fin
    fin=$(date +%s)
    local duracion=$((fin - inicio))
    
    # Verificación final
    verificar_instalaciones
    
    # Mensaje final
    log_section "🎉 Instalación Completada"
    log_success "Todas las dependencias instaladas en ${duracion} segundos"
    
    if [[ "$INSTALL_DOCKER" == "true" ]]; then
        log_info "IMPORTANTE: Reinicia tu sesión para usar Docker sin sudo"
        log_info "O ejecuta: newgrp docker"
    fi
    
    return 0
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Ejecutar función principal
main "$@"
