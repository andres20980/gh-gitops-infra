# 🚀 Infraestructura GitOps Empresarial

> **Plataforma GitOps completa** con ArgoCD, Kargo, observabilidad integral y workflows de promoción automatizada. **Totalmente portable** con instalación desatendida desde Ubuntu limpio.

## ✨ **CARACTERÍSTICAS DESTACADAS**

- 🧠 **Instalación desatendida completa** desde Ubuntu limpio
- 🎯 **Puertos correlativos** 8080-8091 para todas las UIs
- 📊 **Stack completo**: ArgoCD + Kargo + Observabilidad
- 🔄 **Super portable** - funciona en cualquier máquina automáticamente
- 🏢 **Enterprise-ready** con componentes CNCF certificados

## 🎯 **INSTALACIÓN CON UN SOLO COMANDO**

### Desde Ubuntu Limpio:
```bash
# 1. Clonar el repositorio
git clone https://github.com/asanchez75/gh-gitops-infra.git
cd gh-gitops-infra

# 2. Instalación completa desatendida
./instalar-todo.sh
```

**¡Eso es todo!** ✨ Este único comando es **verdaderamente desatendido**:
- ✅ **Actualiza sistema**: apt update/upgrade automático
- ✅ **Instala prerrequisitos**: Docker, kubectl, minikube, helm
- ✅ **Configura Docker**: Manejo automático de permisos y servicios
- ✅ **Crea cluster**: Minikube optimizado para desarrollo
- ✅ **Despliega ArgoCD**: Control plane GitOps con auto-configuración
- ✅ **Provisiona stack completo**: 15+ componentes listos para usar
- ✅ **Configura acceso UIs**: Port-forwarding automático

### Acceso a las Interfaces:
```bash
# Después de la instalación, ejecutar port-forwards:
./scripts/setup-port-forwards.sh
```

---

## 🏗️ **Arquitectura del Sistema**

```
🏢 Plataforma GitOps Multi-Cluster Portable (Auto Scaling)
┌─────────────────────────────────────────────────────────────────┐
│            🎯 CLUSTER DEV (Master 50% recursos)                │
│             ArgoCD Master + Stack Infraestructura              │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────────────┐   │
│  │   ArgoCD    │ │    Kargo     │ │   Observabilidad Stack  │   │
│  │  (Master)   │ │ (Promoción)  │ │ Grafana|Prometheus|Loki │   │
│  └─────────────┘ └──────────────┘ └─────────────────────────┘   │
│  ┌─────────────┐ ┌──────────────┐ ┌─────────────────────────┐   │
│  │    Gitea    │ │   MinIO      │ │    Desarrollo Stack     │   │
│  │ (Git Repo)  │ │ (Storage)    │ │  Workflows|Dashboard    │   │
│  └─────────────┘ └──────────────┘ └─────────────────────────┘   │
│             📊 Auto-detectado basado en sistema real           │
└─────────────────────────────────────────────────────────────────┘
           │                              │
           ▼                              ▼
┌─────────────────────┐        ┌─────────────────────┐
│  🧪 CLUSTER PRE     │        │  🏭 CLUSTER PROD    │
│  (Target 25%)       │        │  (Target 25%)       │
│                     │        │                     │
│  • Apps Demo        │        │  • Apps Demo        │
│  • Validación       │        │  • Producción       │
│  • Testing          │        │  • Monitoreo        │
│ (25% recursos auto) │        │ (25% recursos auto) │
└─────────────────────┘        └─────────────────────┘
```

**Distribución Inteligente**: Auto-detecta CPU/RAM → Usa 60% sistema → 50% DEV + 25% PRE + 25% PROD
**Flujo GitOps**: DEV (ArgoCD Master) → controla → PRE & PROD (Targets)

---

## 🌐 **INTERFACES WEB DISPONIBLES (11 UIs)**

Todas las UIs usan **puertos correlativos (8080-8091)** para fácil memorización:

### 🎯 GitOps Core
| UI | Puerto | URL | Credenciales | Descripción |
|---|--------|-----|--------------|-------------|
| **ArgoCD** | 8080 | http://localhost:8080 | admin/[auto] | Control center GitOps |
| **Kargo** | 8081 | https://localhost:8081 | admin/admin | Promociones multi-entorno |

### 👁️ Observabilidad  
| UI | Puerto | URL | Credenciales | Descripción |
|---|--------|-----|--------------|-------------|
| **Grafana** | 8082 | http://localhost:8082 | admin/admin | Dashboards y métricas |
| **Prometheus** | 8083 | http://localhost:8083 | - | Métricas y alertas |
| **AlertManager** | 8084 | http://localhost:8084 | - | Gestión de alertas |
| **Jaeger** | 8085 | http://localhost:8085 | - | Tracing distribuido |
| **Loki** | 8086 | http://localhost:8086 | - | Logs centralizados |

### 🛠️ Desarrollo
| UI | Puerto | URL | Credenciales | Descripción |
|---|--------|-----|--------------|-------------|
| **Gitea** | 8087 | http://localhost:8087 | admin/admin123 | Git server interno |
| **Argo Workflows** | 8088 | http://localhost:8088 | - | Workflow automation |

### 💾 Storage & Kubernetes
| UI | Puerto | URL | Credenciales | Descripción |
|---|--------|-----|--------------|-------------|
| **MinIO Console** | 8090 | http://localhost:8090 | minioadmin/minioadmin | Storage management |
| **K8s Dashboard** | 8091 | http://localhost:8091 | token | Kubernetes native UI |

### 🔗 Esquema de Puertos Correlativos
- **8080-8091**: Rango único para todas las UIs
- **Ventajas**: Fácil memorización, sin conflictos, organización lógica
- **Escalable**: Nuevas UIs en 8092, 8093, etc.

---

## 🛠️ **Comandos de Gestión**

### Scripts Principales
```bash
# Instalación completa desde cero
./instalar-todo.sh

# Configurar port forwards para UIs
./scripts/setup-port-forwards.sh

# Diagnóstico completo del sistema
./scripts/diagnostico-gitops.sh
```

### Comandos Útiles
```bash
# Detener port forwards
pkill -f 'kubectl.*port-forward'

# Ver procesos activos
ps aux | grep port-forward

# Estado de aplicaciones ArgoCD
kubectl get applications -n argocd

# Forzar sync de aplicación
kubectl patch application APP_NAME -n argocd --type='merge' -p='{"operation":{"sync":{"prune":true}}}'

# Ver logs de Kargo
kubectl logs -n kargo deployment/kargo-api

# Estado del cluster
kubectl get nodes,pods -A
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

## 🎯 **Ejemplo de Uso**

### Flujo de Trabajo Típico
```bash
# 1. Instalación completa
./instalar-todo.sh

# 2. Configurar port-forwards
./scripts/setup-port-forwards.sh

# 3. Acceder a las UIs principales
# - ArgoCD: http://localhost:8080 (GitOps dashboard)
# - Kargo: https://localhost:8081 (promociones)
# - Grafana: http://localhost:8082 (observabilidad)
```

### Desarrollo Diario
- **ArgoCD (8080)**: Ver estado de deployments y aplicaciones
- **Kargo (8081)**: Gestionar promociones entre entornos
- **Grafana (8082)**: Monitorizar métricas y dashboards
- **Prometheus (8083)**: Consultar métricas detalladas

---

## ⚠️ **Troubleshooting**

### Problemas Comunes
```bash
# Port forwards no funcionan
pkill -f port-forward
./scripts/setup-port-forwards.sh

# ArgoCD no sincroniza
kubectl patch application APP_NAME -n argocd --type='merge' -p='{"operation":{"sync":{"prune":true}}}'

# Kargo no carga
kubectl logs -n kargo deployment/kargo-api

# Estado general del sistema
./scripts/diagnostico-gitops.sh
```

### Logs Útiles
```bash
# Logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Logs de Kargo
kubectl logs -n kargo -l app.kubernetes.io/name=kargo

# Estado del cluster
kubectl get nodes,pods -A
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
