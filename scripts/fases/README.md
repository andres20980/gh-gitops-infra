# Arquitectura Modular del Instalador GitOps

## 🏗️ Nueva Estructura (Versión 3.0.0)

El instalador ha sido completamente refactorizado en una arquitectura modular por fases para mejorar la mantenibilidad, claridad y escalabilidad.

### 📁 Estructura de Directorios

```
scripts/
├── fases/                          # ← NUEVA: Módulos por fases
│   ├── fase-01-permisos.sh         # Gestión inteligente de permisos
│   ├── fase-02-dependencias.sh     # Dependencias del sistema
│   ├── fase-03-clusters.sh         # Docker y clusters Kubernetes
│   ├── fase-04-argocd.sh          # Instalación de ArgoCD
│   ├── fase-05-herramientas.sh    # Herramientas GitOps
│   ├── fase-06-aplicaciones.sh    # Aplicaciones custom
│   └── fase-07-finalizacion.sh    # Información final y accesos
├── comun/                          # Módulos comunes (existente)
│   ├── base.sh
│   ├── generar-apps-gitops-completas.sh
│   ├── helm-updater.sh
│   ├── optimizar-dev.sh
│   └── validacion.sh
├── cluster/                        # Gestión de clusters (existente)
├── instalacion/                    # Instalación de dependencias (existente)
└── orquestador.sh                 # Orquestador general (existente)
```

### 🚀 Instaladores Disponibles

#### 1. **Instalador Modular** (RECOMENDADO)
```bash
./instalar-modular.sh               # Nueva arquitectura modular v3.0.0
```

#### 2. **Instalador Clásico** (Mantenido por compatibilidad)
```bash
./instalar.sh                       # Arquitectura monolítica v2.4.0
```

## 📋 Fases del Proceso

### **FASE 1: Gestión Inteligente de Permisos**
- **Archivo:** `scripts/fases/fase-01-permisos.sh`
- **Funciones:**
  - `gestionar_permisos_inteligente()` - Auto-escalation/de-escalation de permisos
  - `verificar_contexto_permisos()` - Verificación de contexto por fase
- **Responsabilidad:** Manejo automático de sudo para dependencias y usuario normal para clusters

### **FASE 2: Dependencias del Sistema**
- **Archivo:** `scripts/fases/fase-02-dependencias.sh`
- **Funciones:**
  - `ejecutar_instalacion_dependencias()` - Instalación completa de dependencias
  - `verificar_dependencias_criticas()` - Verificación rápida (modo --skip-deps)
- **Responsabilidad:** Docker, kubectl, minikube, helm, git

### **FASE 3: Clusters Kubernetes**
- **Archivo:** `scripts/fases/fase-03-clusters.sh`
- **Funciones:**
  - `configurar_docker_automatico()` - Configuración automática de Docker
  - `crear_cluster_gitops_dev()` - Cluster principal de desarrollo
  - `crear_clusters_promocion()` - Clusters de preproducción y producción
- **Responsabilidad:** Infraestructura Kubernetes completa

### **FASE 4: ArgoCD**
- **Archivo:** `scripts/fases/fase-04-argocd.sh`
- **Funciones:**
  - `instalar_argocd_maestro()` - Instalación de ArgoCD última versión
  - `verificar_argocd_healthy()` - Verificación de estado
- **Responsabilidad:** GitOps controller principal

### **FASE 5: Herramientas GitOps**
- **Archivo:** `scripts/fases/fase-05-herramientas.sh`
- **Funciones:**
  - `actualizar_y_desplegar_herramientas()` - Despliegue completo
  - `verificar_sistema_gitops_healthy()` - Verificación de 13 herramientas críticas
- **Responsabilidad:** Argo*, Prometheus, Grafana, Jaeger, Loki, etc.

### **FASE 6: Aplicaciones Custom**
- **Archivo:** `scripts/fases/fase-06-aplicaciones.sh`
- **Funciones:**
  - `desplegar_aplicaciones_custom()` - Aplicaciones con integración GitOps completa
  - `generar_commit_aplicaciones_custom()` - Commit automático
  - `verificar_aplicaciones_custom_synced()` - Verificación de estado
- **Responsabilidad:** demo-project, simple-app con integración completa

### **FASE 7: Finalización**
- **Archivo:** `scripts/fases/fase-07-finalizacion.sh`
- **Funciones:**
  - `mostrar_accesos_sistema()` - URLs y credenciales
  - `mostrar_urls_servicios()` - Servicios disponibles
  - `mostrar_resumen_final()` - Resumen completo
- **Responsabilidad:** Información final y accesos

## ✅ Ventajas de la Arquitectura Modular

### **1. Mantenibilidad**
- ✅ Cada fase es independiente y fácil de mantener
- ✅ Funciones especializadas por responsabilidad
- ✅ Archivos más pequeños y manejables (~200 líneas vs 1200)

### **2. Claridad**
- ✅ Flujo de ejecución más claro
- ✅ Separación clara de responsabilidades
- ✅ Fácil navegación y comprensión

### **3. Escalabilidad**
- ✅ Fácil agregar nuevas fases
- ✅ Modificación independiente de cada fase
- ✅ Reutilización de módulos

### **4. Testing**
- ✅ Testing independiente por fase
- ✅ Mocking más sencillo
- ✅ Debug específico por componente

### **5. Flexibilidad**
- ✅ Ejecución parcial de fases
- ✅ Customización por entorno
- ✅ Configuración modular

## 🔧 Uso Avanzado

### **Ejecución por Fases Individuales**
```bash
# Cargar módulos base
source scripts/comun/base.sh

# Cargar fase específica
source scripts/fases/fase-03-clusters.sh

# Ejecutar función específica
crear_cluster_gitops_dev
```

### **Testing de Fases**
```bash
# Test completo en dry-run
./instalar-modular.sh --dry-run

# Test solo cluster dev
./instalar-modular.sh --solo-dev --verbose

# Debug específico
./instalar-modular.sh --debug --log-file debug-modular.log
```

### **Customización**
```bash
# Crear nueva fase
cp scripts/fases/fase-06-aplicaciones.sh scripts/fases/fase-08-monitoreo.sh

# Agregar a lista de fases en instalar-modular.sh
readonly FASES=(
    # ... fases existentes
    "fase-08-monitoreo.sh"
)
```

## 🔄 Migración

### **Para Usuarios Existentes**
- El instalador clásico (`instalar.sh`) sigue funcionando
- Se recomienda migrar al instalador modular para nuevas instalaciones
- Misma funcionalidad, mejor arquitectura

### **Para Desarrolladores**
- Nuevas características deben implementarse en la arquitectura modular
- El instalador clásico se mantiene para compatibilidad
- Tests y documentación deben actualizarse para arquitectura modular

## 📊 Comparación

| Aspecto | Instalador Clásico | Instalador Modular |
|---------|-------------------|-------------------|
| **Tamaño** | ~1200 líneas | ~400 líneas + 7 módulos |
| **Mantenibilidad** | Difícil | Fácil |
| **Testing** | Complejo | Simple |
| **Flexibilidad** | Limitada | Alta |
| **Escalabilidad** | Difícil | Excelente |
| **Compatibilidad** | ✅ | ✅ |
| **Funcionalidad** | Completa | Completa + Mejorada |

## 🎯 Recomendación

**Para nuevas instalaciones:** Usar `./instalar-modular.sh`
**Para instalaciones existentes:** Migrar gradualmente al instalador modular
**Para desarrollo:** Toda nueva funcionalidad en arquitectura modular
