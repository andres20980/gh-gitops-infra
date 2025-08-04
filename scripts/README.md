# 🔧 Scripts Hipermodulares GitOps

> **Sistema de scripts modular organizados jerárquicamente** para la gestión completa de infraestructura GitOps en español.

## 📂 **Organización Modular**

```
📁 scripts/
├── 📚 bibliotecas/                     # Librerías fundamentales (6)
├── 🧠 nucleo/                          # Orquestador principal (1)
├── ⚙️ instaladores/                    # Instaladores especializados (1)
├── 🎯 argocd/                          # Bootstrap GitOps (3)
└── 🔨 utilidades/                      # Utilidades de gestión (3)
```

## 📚 **Bibliotecas Fundamentales**

### **base.sh**
Configuración global y variables del proyecto
```bash
source scripts/bibliotecas/base.sh

# Funciones disponibles:
configurar_entorno_base()              # Setup inicial
obtener_ruta_proyecto()                # Ruta del proyecto
configurar_variables_globales()        # Variables del sistema
```

### **logging.sh**
Sistema de logging avanzado multi-nivel
```bash
source scripts/bibliotecas/logging.sh

# Uso básico:
log_info "Mensaje informativo"
log_warn "Advertencia del sistema"
log_error "Error crítico"
log_debug "Información de debugging"
```

### **validacion.sh**
Validación de prerequisitos del sistema
```bash
source scripts/bibliotecas/validacion.sh

# Validaciones principales:
validar_sistema()                      # Validación completa
validar_recursos()                     # RAM, CPU, disco
validar_permisos()                     # sudo, docker group
validar_conectividad()                 # Red e internet
```

### **versiones.sh**
Gestión automática de versiones compatibles
```bash
source scripts/bibliotecas/versiones.sh

# Gestión de versiones:
obtener_version_kubernetes_estable()   # K8s compatible con minikube
obtener_version_helm_compatible()      # Helm v3 estable
verificar_compatibilidad_versiones()   # Cross-validation
```

### **comun.sh**
Funciones compartidas entre módulos
```bash
source scripts/bibliotecas/comun.sh

# Utilidades comunes:
mostrar_banner()                       # Banner del proyecto
confirmar_accion()                     # Confirmación interactiva
verificar_comando()                    # Verificar si comando existe
```

### **registro.sh**
Sistema de registro de operaciones
```bash
source scripts/bibliotecas/registro.sh

# Registro de operaciones:
registrar_inicio_operacion()          # Log inicio
registrar_fin_operacion()             # Log finalización
obtener_resumen_operaciones()         # Resumen del proceso
```

## 🧠 **Núcleo Orquestador**

### **orchestrador.sh**
Motor de 7 fases para instalación completa
```bash
# Ejecución desde instalador.sh:
source scripts/nucleo/orchestrador.sh
ejecutar_orquestacion_completa

# Fases ejecutadas:
# FASE 1: Validación del sistema
# FASE 2: Instalación de dependencias
# FASE 3: Creación del cluster
# FASE 4: Instalación GitOps
# FASE 5: Despliegue de componentes
# FASE 6: Clusters adicionales
# FASE 7: Verificación final
```

## ⚙️ **Instaladores Especializados**

### **dependencias.sh**
Instalador de dependencias del sistema
```bash
# Uso directo:
scripts/instaladores/dependencias.sh

# Dependencias gestionadas:
- Docker Engine
- Minikube
- kubectl (compatible)
- Helm v3
- ArgoCD CLI

# Funciones disponibles:
instalar_docker()
instalar_minikube()
instalar_kubectl()
instalar_helm()
instalar_argocd_cli()
```

## 🛠️ **Herramientas GitOps**

### **argocd.sh**
Instalador y configurador de ArgoCD
```bash
# Ejecución:
scripts/herramientas-gitops/argocd.sh

# Funcionalidades:
- Instalación de ArgoCD core
- Configuración de CLI
- Setup de port-forwarding
- Configuración de App-of-Apps
```

### **kargo.sh**
Instalador de Kargo para promoción de entornos
```bash
# Ejecución:
scripts/herramientas-gitops/kargo.sh

# Funcionalidades:
- Instalación de Kargo
- Configuración de pipelines
- Setup de promoción automática
```

## 🔧 **Módulos Funcionales**

### **cluster.sh**
Gestión completa de clusters Kubernetes
```bash
# Uso directo:
scripts/modulos/cluster.sh crear_cluster "gitops-dev"

# Funciones principales:
crear_cluster()                        # Crear cluster minikube
configurar_cluster()                   # Post-configuración
habilitar_addons()                     # metrics-server, dashboard
crear_clusters_adicionales()           # Pre/Pro clusters
```

### **argocd-modular.sh**
ArgoCD modular con App-of-Apps
```bash
# Uso desde orquestador:
scripts/modulos/argocd-modular.sh

# Funcionalidades:
- Setup de App-of-Apps jerárquico
- Configuración de ApplicationSets
- Gestión de sincronización automática
```

## 🔨 **Utilidades de Gestión**

### **configuracion.sh**
Configuración inicial y personalización
```bash
# Uso directo:
./scripts/utilidades/configuracion.sh

# Opciones disponibles:
--inicial                              # Configuración completa inicial
--dashboard                            # Solo configuración de dashboards
--port-forwarding                      # Solo port-forwarding
--backup                               # Backup de configuraciones
--restaurar [archivo]                  # Restaurar desde backup
```

### **diagnosticos.sh**
Sistema de diagnósticos y verificación
```bash
# Uso directo:
./scripts/utilidades/diagnosticos.sh

# Opciones de diagnóstico:
--rapido                               # Verificación básica (2-3 min)
--completo                             # Análisis exhaustivo (5-10 min)
--recursos                             # Solo uso de recursos
--conectividad                         # Solo conectividad de servicios
--logs [servicio]                      # Logs específicos
--reporte                              # Generar reporte completo
```

### **mantenimiento.sh**
Mantenimiento automático del sistema
```bash
# Uso directo:
./scripts/utilidades/mantenimiento.sh

# Tareas de mantenimiento:
--limpiar                              # Limpieza general del sistema
--actualizar                           # Actualización de componentes
--optimizar                            # Optimización de recursos
--rotar-logs                           # Rotación de logs
--backup-automatico                    # Backup automático
--verificar-salud                      # Verificación de salud
```

## 🔄 **Flujo de Ejecución Típico**

### **1. Instalación Completa**
```bash
# Desde el instalador principal:
sudo ./instalador.sh

# Esto ejecuta internamente:
source scripts/bibliotecas/*.sh       # Carga bibliotecas
scripts/nucleo/orchestrador.sh        # Ejecuta 7 fases
```

### **2. Uso Individual de Módulos**
```bash
# Crear solo un cluster:
scripts/modulos/cluster.sh crear_cluster "mi-cluster"

# Solo diagnósticos:
scripts/utilidades/diagnosticos.sh --completo

# Solo mantenimiento:
scripts/utilidades/mantenimiento.sh --limpiar
```

### **3. Personalización Avanzada**
```bash
# Configuración personalizada:
scripts/utilidades/configuracion.sh --inicial

# Instalación de dependencias específicas:
scripts/instaladores/dependencias.sh instalar_helm

# ArgoCD standalone:
scripts/herramientas-gitops/argocd.sh
```

## 📋 **Convenciones de Código**

### **Nomenclatura en Español**
```bash
# Variables
CLUSTER_PRINCIPAL="gitops-dev"
RUTA_CONFIGURACION="/tmp/gitops-config"
ARCHIVO_LOG="instalacion.log"

# Funciones
configurar_entorno()
validar_prerequisitos()
instalar_dependencia()
```

### **Estructura de Funciones**
```bash
function nombre_funcion() {
    # Descripción de la función
    local parametro_local="$1"
    
    log_info "Iniciando ${FUNCNAME[0]}"
    
    # Validación de parámetros
    [ -z "$parametro_local" ] && {
        log_error "Parámetro requerido no proporcionado"
        return 1
    }
    
    # Lógica principal
    # ...
    
    log_info "Completado ${FUNCNAME[0]}"
    return 0
}
```

### **Gestión de Errores**
```bash
# Cada función debe manejar errores:
comando_critico || {
    log_error "Fallo en comando crítico"
    return 1
}

# Verificación de prerequisitos:
command -v docker >/dev/null 2>&1 || {
    log_warn "Docker no encontrado, instalando..."
    instalar_docker
}
```

## 🧪 **Testing de Módulos**

### **Validación Individual**
```bash
# Test de un módulo específico:
scripts/modulos/cluster.sh --test

# Test de biblioteca:
source scripts/bibliotecas/validacion.sh
validar_sistema --dry-run
```

### **Testing Completo**
```bash
# Desde el directorio principal:
./instalador.sh --test-modules

# Esto valida todos los módulos sin ejecutar
```

## 📞 **Soporte y Debugging**

### **Logs Detallados**
```bash
# Habilitar debugging:
export GITOPS_DEBUG=true
./instalador.sh

# Logs se guardan en:
logs/instalacion-$(date +%Y%m%d).log
```

### **Debugging de Módulos**
```bash
# Debug de módulo específico:
bash -x scripts/modulos/cluster.sh crear_cluster "test"

# Verificar bibliotecas cargadas:
scripts/utilidades/diagnosticos.sh --modulos
```

---

> **Estos scripts representan la base de la arquitectura hipermodular GitOps, diseñados para máxima flexibilidad, mantenibilidad y facilidad de uso en español.**
