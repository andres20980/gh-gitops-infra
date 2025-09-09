# 🤝 Guía de Contribución - Infraestructura GitOps

¡Gracias por tu interés en contribuir a **Infraestructura GitOps Hipermodular**! Este proyecto está diseñado específicamente para la **comunidad hispanohablante** y valoramos todas las contribuciones que mantengan esta filosofía.

## 🌍 **Filosofía del Proyecto**

- **100% en Español**: Código, comentarios, documentación y comunicación
- **Arquitectura Hipermodular**: Separación radical de responsabilidades
- **Calidad Enterprise**: Estándares profesionales de desarrollo
- **Comunidad Inclusiva**: Entorno acogedor para todos los niveles

## 🚀 **Cómo Contribuir**

### **1. Fork y Clone**
```bash
# Fork el repositorio desde GitHub
# Luego clona tu fork:
git clone https://github.com/TU-USUARIO/gh-gitops-infra.git
cd gh-gitops-infra

# Añade el upstream:
git remote add upstream https://github.com/asanchez-dev/gh-gitops-infra.git
```

### **2. Configuración del Entorno**
```bash
# Instala dependencias de desarrollo:
sudo ./instalador.sh --dev-mode

# Configura pre-commit hooks (opcional):
./scripts/utilidades/configuracion.sh --dev-setup
```

### **3. Crear Branch de Trabajo**
```bash
# Nomenclatura en español:
git checkout -b funcionalidad/nueva-herramienta-gitops
git checkout -b correccion/bug-validacion-recursos
git checkout -b documentacion/guia-instalacion-avanzada
git checkout -b mejora/optimizacion-rendimiento
```

## 📝 **Estándares de Código**

### **Nomenclatura en Español**
```bash
# ✅ CORRECTO - Nombres en español
function configurar_cluster_principal() {
    local nombre_cluster="$1"
    local recursos_memoria="8192"
    
    log_info "Configurando cluster: ${nombre_cluster}"
    # ...
}

# ❌ INCORRECTO - Nombres en inglés
function setup_main_cluster() {
    local cluster_name="$1"
    # ...
}
```

### **Comentarios y Documentación**
```bash
# ✅ CORRECTO - Comentarios en español
# Función para validar que el sistema tenga recursos suficientes
# Parámetros:
#   $1: Memoria mínima requerida en MB
#   $2: CPU cores mínimos requeridos
function validar_recursos_sistema() {
    # Implementación...
}

# ❌ INCORRECTO - Comentarios en inglés
# Function to validate system resources
function validar_recursos_sistema() {
    # Implementation...
}
```

### **Variables y Constantes**
```bash
# ✅ CORRECTO - Variables descriptivas en español
readonly CLUSTER_PRINCIPAL="gitops-dev"
readonly RUTA_CONFIGURACION="/etc/gitops"
readonly TIMEOUT_INSTALACION="300"

# Uso de arrays asociativos:
declare -A COMPONENTES_GITOPS=(
    ["argocd"]="Gestor de despliegues GitOps"
    ["prometheus"]="Sistema de monitorización"
    ["grafana"]="Dashboard de métricas"
)
```

### **Gestión de Errores**
```bash
# ✅ CORRECTO - Manejo robusto de errores
function instalar_dependencia() {
    local nombre_dependencia="$1"
    
    # Validación de parámetros
    if [[ -z "$nombre_dependencia" ]]; then
        log_error "Nombre de dependencia requerido"
        return 1
    fi
    
    # Ejecución con manejo de errores
    if ! comando_instalacion "$nombre_dependencia"; then
        log_error "Fallo al instalar: ${nombre_dependencia}"
        return 1
    fi
    
    log_info "Dependencia instalada exitosamente: ${nombre_dependencia}"
    return 0
}
```

---

> **¡Tu contribución puede hacer la diferencia!** La comunidad GitOps hispanohablante está creciendo y tu aporte puede ayudar a muchos desarrolladores y DevOps engineers a implementar GitOps de manera profesional.

**¡Gracias por contribuir a hacer del GitOps en español una realidad! 🚀**
