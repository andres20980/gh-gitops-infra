# 🚀 GitOps Multi-Cluster Infrastructure

> **Plataforma GitOps empresarial completa** con ArgoCD, Kargo, stack de observabilidad y promociones automáticas. **100% desatendida** desde Ubuntu limpio.

## 📦 **Stack de Componentes (15+ Herramientas)**

### 🎯 GitOps Core
- **ArgoCD v3.0.12**: Control center para GitOps y continuous delivery
- **Kargo v1.6.2**: Promociones automáticas entre entornos (dev → pre → pro)

### 📊 Observabilidad Stack  
- **Prometheus v57.2.0**: Metrics collection y time-series database
- **Grafana v9.3.0**: Dashboards, visualización y alerting
- **Loki v6.34.0**: Log aggregation y queries 
- **Jaeger v3.4.1**: Distributed tracing y performance monitoring

### 🚀 Progressive Delivery
- **Argo Events v2.4.16**: Event-driven workflow automation
- **Argo Workflows v0.45.21**: Workflow orchestration y batch processing
- **Argo Rollouts v2.40.2**: Canary deployments y blue-green strategies

### 🔧 Infraestructura & Storage
- **MinIO v5.4.0**: Object storage S3-compatible con console UI
- **Gitea v12.1.2**: Git server interno para repositorios privados
- **NGINX Ingress v4.13.0**: Load balancer y reverse proxy
- **Cert-Manager v1.18.2**: Automatic TLS certificate management
- **External Secrets v0.18.2**: Secure secrets management integrado

### 🎯 Ventajas del Stack
- **100% CNCF certified**: Componentes de la cloud native landscape
- **Enterprise-grade**: Probado en entornos de producción
- **Auto-integrado**: Todas las herramientas se comunican entre sí
- **Observabilidad completa**: Métricas, logs, traces y alertas

---

## 📁 **Estructura del Proyecto (App of Apps Pattern)**

```
gh-gitops-infra/
├── 🚀 instalar-todo.sh                # Script principal desatendido
├── 📋 app-of-apps-gitops.yaml         # App of Apps principal de ArgoCD
├── 📂 componentes/                    # 15 aplicaciones GitOps (patrón App of Apps)
│   ├── argo-events.yaml              # Event-driven automation
│   ├── argo-rollouts.yaml            # Progressive delivery
│   ├── argo-workflows.yaml           # Workflow orchestration  
│   ├── cert-manager.yaml             # Certificate management
│   ├── external-secrets.yaml         # Secrets management
│   ├── gitea.yaml                    # Git server interno
│   ├── grafana.yaml                  # Dashboards y visualización
│   ├── ingress-nginx.yaml            # Load balancer
│   ├── jaeger.yaml                   # Distributed tracing
│   ├── kargo.yaml                    # Promociones automáticas
│   ├── loki.yaml                     # Log aggregation
│   ├── minio.yaml                    # Object storage S3
│   └── prometheus-stack.yaml         # Monitoring completo
├── 📂 aplicaciones/                   # Aplicaciones de negocio (demo)
│   ├── demo-project/                 # Proyecto de ejemplo multi-tier
│   └── simple-app/                   # App simple para testing
├── 📂 scripts/                       # Scripts de gestión y utilidades
│   ├── setup-port-forwards.sh       # Port-forwarding automático para UIs
│   ├── diagnostico-gitops.sh        # Diagnóstico completo del sistema
│   ├── sync-all-apps.sh             # Sincronización manual de aplicaciones
│   └── fix-chart-versions.sh        # Corrección automática de versiones
└── 📚 README.md                      # Documentación principal
```

### 🎯 Arquitectura App of Apps
- **App of Apps Principal**: `app-of-apps-gitops.yaml` gestiona todas las herramientas
- **`componentes/`**: 15 aplicaciones ArgoCD auto-detectadas por patrón App of Apps
- **Auto-discovery**: El App of Apps detecta automáticamente nuevos .yaml en `/componentes/`
- **Gestión centralizada**: Una sola aplicación ArgoCD controla todo el stack

---

## 🎉 **CARACTERÍSTICAS DESTACADAS**

- 🏗️ **Patrón App of Apps**: Gestión centralizada de 15+ herramientas GitOps
- 🤖 **Instalación completamente desatendida** - solo ejecuta un comando
- 🌐 **15 interfaces web** organizadas por puertos (8080-8094)  
- 📊 **Stack de observabilidad completo** (Prometheus + Grafana + Loki + Jaeger)
- 🚢 **Progressive delivery** con Kargo para promociones automáticas dev → pre → pro
- � **100% portable** - funciona en cualquier máquina Linux automáticamente
- � **Enterprise-ready** con componentes CNCF certificados
- ✅ **Auto-detección de versiones** - siempre usa las últimas versiones estables
- 🔧 **Scripts de gestión** para diagnóstico, sync manual y corrección automática

## 🚀 **INSTALACIÓN CON UN SOLO COMANDO**

### Desde Ubuntu/Debian limpio:
```bash
# 1. Clonar el repositorio
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra

# 2. Instalación completa desatendida (~5 minutos)
./instalar-todo.sh
```

**¡Eso es todo!** ✨ Este único comando es **verdaderamente desatendido**:
- ✅ **Verifica dependencias**: Auto-instala curl, jq, yq, helm si faltan
- ✅ **Detecta versiones**: Auto-obtiene las últimas versiones estables de todo
- ✅ **Crea cluster**: DEV (8GB) optimizado para desarrollo
- ✅ **Instala ArgoCD**: Con acceso sin autenticación para desarrollo  
- ✅ **Despliega App of Apps**: 15+ herramientas GitOps con un solo manifiesto
- ✅ **Configuración automática**: Todo pre-configurado e integrado
- ✅ **Port-forwarding automático**: 15 UIs inmediatamente accesibles
- ✅ **Validación completa**: Verifica que todo esté operativo

### � Extensión Multi-Cluster (Opcional):
```bash
# Crear clusters adicionales PRE y PRO después de validar DEV
CREAR_CLUSTERS_ADICIONALES=true ./instalar-todo.sh
```

---

---

## 🌐 **15 INTERFACES WEB DISPONIBLES**

Tras la instalación, todas las interfaces están **inmediatamente accesibles** en tu navegador:

### GitOps & CI/CD
| Servicio | Puerto | URL | Credenciales |
|----------|---------|-----|--------------|
| **ArgoCD** | 8080 | http://localhost:8080 | `admin` / `password` |
| **Kargo** | 8081 | http://localhost:8081 | `admin` / `admin123` |
| **Argo Workflows** | 8082 | http://localhost:8082 | N/A |

### Observabilidad
| Servicio | Puerto | URL | Credenciales |
|----------|---------|-----|--------------|
| **Grafana** | 8084 | http://localhost:8084 | `admin` / `admin` |
| **Prometheus** | 8085 | http://localhost:8085 | N/A |
| **AlertManager** | 8086 | http://localhost:8086 | N/A |
| **Jaeger** | 8087 | http://localhost:8087 | N/A |

### Storage & Git
| Servicio | Puerto | URL | Credenciales |
|----------|---------|-----|--------------|
| **MinIO Console** | 8088 | http://localhost:8088 | `gitops` / `gitops2025` |
| **Gitea** | 8089 | http://localhost:8089 | Sign up available |

### Infraestructura
| Servicio | Puerto | URL | Credenciales |
|----------|---------|-----|--------------|
| **NGINX Ingress** | 8090 | http://localhost:8090 | N/A |

### � **Port-Forward Automático**
```bash
# Los port-forwards se configuran automáticamente tras la instalación
# Para reconfigurarlos manualmente:
./scripts/setup-port-forwards.sh

# Verificar puertos activos:
netstat -tlnp | grep kubectl
```

---

---

## 🛠️ **Comandos de Gestión**

### Scripts Principales
```bash
# 🚀 Instalación completa desde cero
./instalar-todo.sh

# 🌐 Configurar port-forwards para acceso a UIs
./instalar-todo.sh port-forwards  # o usar:
./scripts/setup-port-forwards.sh

# 📊 Diagnóstico completo del sistema
./scripts/diagnostico-gitops.sh
```

### Comandos Modulares del Instalador
```bash
# Crear solo los clusters multi-entorno
./instalar-todo.sh clusters

# Instalar solo ArgoCD en DEV
./instalar-todo.sh argocd

# Aplicar solo la infraestructura GitOps
./instalar-todo.sh infra

# Ver estado actual del sistema
./instalar-todo.sh estado

# Mostrar URLs de todas las interfaces
./instalar-todo.sh urls

# Limpiar todo el entorno
./instalar-todo.sh limpiar

# Mostrar ayuda completa
./instalar-todo.sh help
```

### Comandos Kubernetes Útiles
```bash
# Ver aplicaciones ArgoCD
kubectl get applications -n argocd

# Forzar sincronización de aplicación
kubectl patch application APP_NAME -n argocd --type='merge' -p='{"operation":{"sync":{"prune":true}}}'

# Estado de todos los pods
kubectl get pods -A

# Logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Ver clusters conectados
kubectl config get-contexts

# Cambiar entre clusters
kubectl config use-context gitops-dev    # Cluster principal
kubectl config use-context gitops-pre    # Cluster preproducción  
kubectl config use-context gitops-pro    # Cluster producción
```

### Gestión de Port-Forwards
```bash
# Ver port-forwards activos
netstat -tuln | grep -E ':(808[0-9]|809[0-2])'

# Detener todos los port-forwards
pkill -f 'kubectl.*port-forward'

# Reiniciar port-forwards
./scripts/setup-port-forwards.sh
```

---

## � **Stack de Componentes**

### 🎯 GitOps Core
- **ArgoCD**: Control center para GitOps
- **Kargo**: Gestión de promociones multi-entorno

### 👁️ Observabilidad Stack
- **Prometheus**: Métricas y alertas
- **Grafana**: Dashboards y visualización
- **Loki**: Logs centralizados
- **Jaeger**: Tracing distribuido

### 🔧 Infraestructura
- **MinIO**: Object storage S3-compatible
- **Argo Workflows**: Automatización de workflows
- **External Secrets**: Gestión segura de secretos
- **Cert Manager**: Certificados TLS automáticos
- **Ingress NGINX**: Load balancer y proxy

---

## 🎯 **Flujo de Trabajo Típico**

### 1. Instalación y Acceso
```bash
# Instalación completa (~5 minutos)
./instalar-todo.sh

# Las UIs se abren automáticamente en:
# - ArgoCD: http://localhost:8080 (GitOps dashboard)
# - Kargo: http://localhost:8081 (promociones)  
# - Grafana: http://localhost:8084 (observabilidad)
```

### 2. Desarrollo Diario
- **ArgoCD (8080)**: Monitorear estado de deployments y aplicaciones
- **Kargo (8081)**: Gestionar promociones automáticas dev → pre → pro
- **Grafana (8084)**: Observar métricas, dashboards y alertas
- **Prometheus (8085)**: Consultar métricas detalladas y targets
- **Gitea (8091)**: Gestionar repositorios Git internos

### 3. Gestión de Aplicaciones
```bash
# Desplegar nueva aplicación
kubectl apply -f proyectos/mi-app/

# Ver estado en ArgoCD
kubectl get applications -n argocd

# Promover entre entornos con Kargo UI
# (Automático basado en políticas configuradas)

# Monitorear en Grafana
# Dashboards automáticos disponibles
```

### 4. Troubleshooting
```bash
# Diagnóstico completo
./scripts/diagnostico-gitops.sh

# Ver logs centralizados  
# Loki UI: http://localhost:8088

# Distributed tracing
# Jaeger UI: http://localhost:8087
```

---

## ⚠️ **Troubleshooting**

### Comandos de Diagnóstico Rápido
```bash
# Diagnóstico completo automatizado
./scripts/diagnostico-gitops.sh

# Verificar estado de todas las aplicaciones ArgoCD
kubectl get applications -n argocd

# Verificar estado del App of Apps principal
kubectl get application gitops-infra-app-of-apps -n argocd

# Ver todos los pods del sistema
kubectl get pods -A | grep -v Running
```

### Problemas Comunes y Soluciones

#### � Port-forwards no funcionan
```bash
# Matar port-forwards existentes y reiniciar
pkill -f 'kubectl.*port-forward'
./scripts/setup-port-forwards.sh
```

#### � ArgoCD no sincroniza aplicaciones
```bash
# Forzar refresh del App of Apps principal
kubectl annotate application gitops-infra-app-of-apps -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Sincronizar todas las aplicaciones
./scripts/sync-all-apps.sh
```

#### 🚢 Kargo no carga (problema DNS)
```bash
# Verificar que está usando la URL OCI correcta
kubectl get application kargo -n argocd -o yaml | grep repoURL

# Debe ser: oci://ghcr.io/akuity/kargo-charts
```

#### 📊 Aplicaciones en estado Unknown
```bash
# Forzar corrección de versiones
./scripts/fix-chart-versions.sh

# Verificar logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

---
