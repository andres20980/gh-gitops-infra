# 🚀 GitOps Multi-Cluster Infrastructure

> **Plataforma GitOps empresarial completa** con ArgoCD, Kargo, stack de observabilidad y promociones automáticas. **100% desatendida** desde Ubuntu limpio.
---

## 📦 **Stack de Componentes (14+ Herramientas)**

### 🎯 GitOps Core
- **ArgoCD v3.0.11**: Control center para GitOps y continuous delivery
- **Kargo v1.6.1**: Promociones automáticas e---

## 📁 **Estructura del Proyecto**

```
gh-gitops-infra---

## 🎉 **¿Qué Obtienes?**

### ✅ **Plataforma Completa Enterprise-Ready**
- **🏗️ Arquitectura multi-cluster** con 3 entornos (DEV/PRE/PRO)
- **🤖 Instalación 100% desatendida** en ~5 minutos desde Ubuntu limpio
- **📦 14+ herramientas GitOps** integradas y configuradas automáticamente
- **🌐 12 interfaces web** organizadas por puertos (8080-8092)
- **📊 Stack de observabilidad completo** (Prometheus + Grafana + Loki + Jaeger)

### ✅ **GitOps y Progressive Delivery**
- **🔄 ArgoCD v3.0.11** para continuous delivery multi-cluster
- **🚢 Kargo v1.6.1** para promociones automáticas dev → pre → pro
- **⚡ Argo Workflows/Rollouts** para progressive delivery avanzado
- **🔐 Gestión de secretos** con External Secrets integrado

### ✅ **Desarrollo y Operaciones**
- **🐙 Git server interno** con Gitea pre-configurado
- **🏪 Storage S3-compatible** con MinIO + console UI
- **🔒 TLS automático** con Cert-Manager
- **🌐 Load balancing** con NGINX Ingress

### ✅ **Monitoreo y Observabilidad**
- **📈 Métricas centralizadas** con Prometheus + Grafana
- **📝 Logs agregados** con Loki + queries avanzados
- **🔍 Distributed tracing** con Jaeger
- **🚨 Alerting inteligente** con AlertManager

### ✅ **Facilidad de Uso**
- **📋 Scripts modulares** para gestión granular
- **🔧 Comandos de diagnóstico** automatizados  
- **📚 Documentación completa** con ejemplos funcionales
- **🎯 Zero-configuration** - todo funciona inmediatamente

---

## 🚀 **¡Empieza Ahora!**

```bash
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra
./instalar-todo.sh
```

**En 5 minutos tendrás una plataforma GitOps empresarial completa funcionando! 🎉**

---

*Plataforma GitOps Multi-Cluster portable, enterprise-ready y fácil de usar*odo.sh              # Script principal de instalación modular
├── 📋 aplicaciones-gitops-infra.yaml # App-of-apps principal de ArgoCD
├── 📂 componentes/                   # Configuraciones de 14+ herramientas GitOps
│   ├── argo-rollouts/               # Progressive delivery
│   ├── argo-workflows/              # Workflow orchestration  
│   ├── cert-manager/                # Certificate management
│   ├── external-secrets/            # Secrets management
│   ├── gitea/                       # Git server interno
│   ├── grafana/                     # Dashboards y visualización
│   ├── ingress-nginx/               # Load balancer
│   ├── jaeger/                      # Distributed tracing
│   ├── k8s-dashboard/               # Kubernetes UI
│   ├── kargo/                       # Promociones automáticas
│   ├── loki/                        # Log aggregation
│   ├── minio/                       # Object storage S3
│   └── monitoring/                  # Prometheus stack
├── 📂 proyectos/                    # Aplicaciones de negocio y demos
│   └── demo-project/                # Proyecto de ejemplo multi-tier
│       ├── app-of-apps.yaml         # ArgoCD app-of-apps del proyecto
│       └── apps/                    # Definiciones de aplicaciones
├── 📂 manifiestos/                  # Manifiestos Kubernetes de aplicaciones
│   └── demo-project/                # Deployments, services, etc.
│       ├── backend/
│       ├── database/
│       └── frontend/
└── 📂 scripts/                      # Scripts de gestión y utilidades
    ├── setup-port-forwards.sh      # Port-forwarding automático para UIs
    └── diagnostico-gitops.sh       # Diagnóstico completo del sistema
```

### 🎯 Explicación de la Estructura

- **`componentes/`**: Configuraciones Helm/ArgoCD de todas las herramientas
- **`proyectos/`**: Apps ArgoCD que referencian manifiestos de aplicaciones
- **`manifiestos/`**: Manifiestos Kubernetes reales de las aplicaciones
- **`scripts/`**: Utilidades para gestión y diagnóstico
- **Raíz**: Script principal y configuración app-of-apps de ArgoCDev → pre → pro)

### 📊 Observabilidad Stack  
- **Prometheus v75.13.0**: Metrics collection y time-series database
- **Grafana v8.17.4**: Dashboards, visualización y alerting
- **Loki v6.33.0**: Log aggregation y queries 
- **Jaeger v3.4.1**: Distributed tracing y performance monitoring

### 🚀 Progressive Delivery
- **Argo Workflows v3.7.0**: Workflow orchestration y batch processing
- **Argo Rollouts v1.8.3**: Canary deployments y blue-green strategies

### 🔧 Infraestructura & Storage
- **MinIO**: Object storage S3-compatible con console UI
- **Gitea**: Git server interno para repositorios privados
- **NGINX Ingress v4.13.0**: Load balancer y reverse proxy
- **Cert-Manager v1.18.2**: Automatic TLS certificate management
- **External Secrets v0.18.2**: Secure secrets management integrado

### 🔍 Gestión & Monitoreo
- **Kubernetes Dashboard**: Native K8s cluster management interface
- **AlertManager**: Intelligent alert routing y notification management

### 🎯 Ventajas del Stack
- **100% CNCF certified**: Componentes de la cloud native landscape
- **Enterprise-grade**: Probado en entornos de producción
- **Auto-integrado**: Todas las herramientas se comunican entre sí
- **Observabilidad completa**: Métricas, logs, traces y alertasCAS DESTACADAS**

- 🏗️ **Arquitectura multi-cluster** (DEV/PRE/PRO) con ArgoCD centralizado
- � **Instalación completamente desatendida** - solo ejecuta un comando
- � **12 interfaces web** organizadas por puertos (8080-8092)  
- 📊 **Stack de observabilidad completo** (Prometheus + Grafana + Loki + Jaeger)
- 🚢 **Progressive delivery** con Kargo para promociones automáticas
- 🔄 **100% portable** - funciona en cualquier máquina Linux automáticamente
- 🏢 **Enterprise-ready** con componentes CNCF certificados

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
- ✅ **Verifica dependencias**: Auto-instala curl, jq, yq si faltan
- ✅ **Crea 3 clusters**: DEV (8GB), PRE (2GB), PRO (2GB) optimizados
- ✅ **Instala ArgoCD**: Con acceso sin autenticación para desarrollo  
- ✅ **Despliega 14+ herramientas**: Stack GitOps completo
- ✅ **Configura multi-cluster**: ArgoCD controla todos los entornos
- ✅ **Port-forwarding automático**: 12 UIs inmediatamente accesibles
- ✅ **Validación completa**: Verifica que todo esté operativo

---

## 🏗️ **Arquitectura Multi-Cluster**

```
🏢 GitOps Multi-Cluster Infrastructure (Auto-Scaling por recursos)
┌─────────────────────────────────────────────────────────────────┐
│               🎯 CLUSTER DEV (gitops-dev)                      │
│                 8GB RAM, 4 CPU, 50GB Disk                      │
│              ★ Control Plane + Herramientas ★                  │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────────────┐   │
│  │   ArgoCD    │ │    Kargo     │ │    Observabilidad       │   │
│  │  v3.0.11    │ │   v1.6.1     │ │ Grafana|Prometheus|Loki │   │
│  └─────────────┘ └──────────────┘ └─────────────────────────┘   │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────────────┐   │
│  │    Gitea    │ │   MinIO      │ │   Progressive Delivery  │   │
│  │ (Git Repo)  │ │ (Storage)    │ │  Workflows|Rollouts     │   │
│  └─────────────┘ └──────────────┘ └─────────────────────────┘   │
│             🎮 Controla y gestiona todos los clusters          │
└─────────────────────────────────────────────────────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────┐        ┌─────────────────────┐
│  🧪 CLUSTER PRE     │        │  🏭 CLUSTER PRO     │
│   (gitops-pre)      │        │   (gitops-pro)      │
│ 2GB RAM, 2CPU, 20GB│        │ 2GB RAM, 2CPU, 20GB │
│                     │        │                     │
│  • Apps Testing     │        │  • Apps Producción  │
│  • Validación QA    │        │  • Demos Live       │
│  • Pre-prod Env     │        │  • Monitoring       │
│ (Managed by DEV)    │        │ (Managed by DEV)    │
└─────────────────────┘        └─────────────────────┘
```

**🔄 Flujo GitOps**: 
1. **Git Push** → Repositorio
2. **ArgoCD (DEV)** detecta cambios 
3. **Deploy automático** en DEV
4. **Kargo** promueve DEV → PRE → PRO
5. **Observabilidad centralizada** desde DEV

---

---

## 🌐 **INTERFACES WEB (12 UIs - Puertos 8080-8092)**

Todas las UIs usan **puertos correlativos organizados por tipo** para fácil acceso:

### 🎯 GitOps Core (8080-8082)
| UI | Puerto | URL | Acceso | Descripción |
|---|--------|-----|--------|-------------|
| **ArgoCD** | 8080 | http://localhost:8080 | 🔓 Sin login | GitOps control center |
| **Kargo** | 8081 | http://localhost:8081 | admin/admin | Promociones automáticas |
| **ArgoCD Dex** | 8082 | http://localhost:8082 | 🔓 Directo | Authentication service |

### 🚀 Progressive Delivery (8083)
| UI | Puerto | URL | Acceso | Descripción |
|---|--------|-----|--------|-------------|
| **Argo Workflows** | 8083 | http://localhost:8083 | 🔓 Sin login | Workflow orchestration |

### � Observabilidad (8084-8087)
| UI | Puerto | URL | Acceso | Descripción |
|---|--------|-----|--------|-------------|
| **Grafana** | 8084 | http://localhost:8084 | 🔓 Sin login | Dashboards y métricas |
| **Prometheus** | 8085 | http://localhost:8085 | 🔓 Directo | Time-series database |
| **AlertManager** | 8086 | http://localhost:8086 | 🔓 Directo | Alert management |
| **Jaeger** | 8087 | http://localhost:8087 | 🔓 Directo | Distributed tracing |

### � Logs & Storage (8088-8090)
| UI | Puerto | URL | Acceso | Descripción |
|---|--------|-----|--------|-------------|
| **Loki** | 8088 | http://localhost:8088 | 🔓 Directo | Log aggregation |
| **MinIO API** | 8089 | http://localhost:8089 | admin/admin123 | S3-compatible storage |
| **MinIO Console** | 8090 | http://localhost:8090 | admin/admin123 | Storage management UI |

### � Desarrollo & Gestión (8091-8092)
| UI | Puerto | URL | Acceso | Descripción |
|---|--------|-----|--------|-------------|
| **Gitea** | 8091 | http://localhost:8091 | 🔓 Sin login | Git server interno |
| **K8s Dashboard** | 8092 | http://localhost:8092 | 🔓 Sin login | Kubernetes native UI |

### 🎯 Ventajas del Esquema de Puertos
- **8080-8092**: Rango único organizado por funciones
- **Memorización fácil**: GitOps (80-82), Observabilidad (84-87), etc.
- **Sin conflictos**: Puertos no utilizados por otros servicios
- **Escalable**: Nuevas UIs en 8093+

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

### Problemas Comunes y Soluciones

#### 🔌 Port-forwards no funcionan
```bash
# Matar port-forwards existentes y reiniciar
pkill -f 'kubectl.*port-forward'
./scripts/setup-port-forwards.sh

# O usar el comando integrado
./instalar-todo.sh port-forwards
```

#### 🔄 ArgoCD no sincroniza aplicaciones
```bash
# Forzar sincronización manual
kubectl patch application APP_NAME -n argocd --type='merge' -p='{"operation":{"sync":{"prune":true}}}'

# Ver logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

#### 🚢 Kargo no carga o no promueve
```bash
# Ver logs de Kargo
kubectl logs -n kargo -l app.kubernetes.io/name=kargo-api

# Verificar estado del servicio
kubectl get pods -n kargo
```

#### ⚡ Clusters no responden
```bash
# Verificar estado de todos los clusters
minikube status -p gitops-dev
minikube status -p gitops-pre  
minikube status -p gitops-pro

# Reiniciar cluster específico si es necesario
minikube stop -p CLUSTER_NAME
minikube start -p CLUSTER_NAME
```

#### 📊 Grafana/Prometheus sin datos
```bash
# Verificar pods de monitoring
kubectl get pods -n monitoring

# Verificar servicios
kubectl get svc -n monitoring

# Reiniciar port-forward específico
kubectl port-forward -n monitoring svc/grafana 8084:80
```

### 🔍 Comandos de Diagnóstico
```bash
# Diagnóstico completo automatizado
./scripts/diagnostico-gitops.sh

# Estado general del sistema
./instalar-todo.sh estado

# Ver todos los pods del sistema
kubectl get pods -A | grep -v Running

# Verificar recursos del sistema
kubectl top nodes
kubectl top pods -A
```

### 📋 Logs Útiles para Debug
```bash
# Logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Logs de Kargo
kubectl logs -n kargo -l app.kubernetes.io/name=kargo-api

# Logs de Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Logs de aplicaciones específicas
kubectl logs -n NAMESPACE -l app=APP_NAME
```

---

## � **Estructura del Proyecto**

```
gh-gitops-infra/
├── instalar-todo.sh           # 🚀 Script principal de instalación
├── gitops-infra-apps.yaml     # 📋 App-of-apps de ArgoCD
├── scripts/                   # 🔧 Scripts de gestión
│   ├── setup-port-forwards.sh # Port forwards para UIs
│   └── diagnostico-gitops.sh  # Diagnóstico del sistema
├── components/                # 📦 Configuraciones de componentes
├── projects/                  # 🏗️ Aplicaciones de negocio
├── manifests/                 # 📄 Manifiestos de demo
└── docs/                      # 📚 Documentación
```

---

## � **¿Qué Obtienes?**

✅ **Plataforma GitOps completa** lista en minutos  
✅ **15+ servicios integrados** con una sola instalación  
✅ **11 interfaces web** con puertos correlativos (8080-8091)  
✅ **Observabilidad enterprise** (Prometheus + Grafana + Loki + Jaeger)  
✅ **Gestión de promociones** con Kargo  
✅ **Instalación desatendida** desde Ubuntu limpio  
✅ **Scripts optimizados** para gestión  
✅ **Documentación completa** y ejemplos  
✅ **Stack CNCF certificado** con mejores prácticas  

**🚀 Todo funciona desde el primer comando!**

---

*Plataforma GitOps empresarial portable y fácil de usar*
