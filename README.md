# 🚀 GitOps Infrastructure

A complete GitOps environment with ArgoCD, monitoring, and demo applications.

## 🏗️ Architecture

# 🚀 Enterprise GitOps Stack

Una infraestructura GitOps completa que simula un entorno empresarial multi-cluster con ArgoCD, observabilidad completa, y workflows de promoción automatizada entre entornos.

## 🏗️ Arquitectura Empresarial

```
Entorno Completo GitOps:
├── 🎯 Control Plane (gitops-dev)
│   ├── 🔄 ArgoCD (GitOps Controller)
│   ├── 🚀 Kargo (Promotional Pipelines)
│   ├── 🔄 Argo Workflows (CI/CD Pipelines)
│   └── 🎢 Argo Rollouts (Progressive Delivery)
├── 📊 Observability Stack
│   ├── 📈 Prometheus (Metrics)
│   ├── 📊 Grafana (Dashboards)
│   └── 📝 Loki (Centralized Logging)
├── 🌐 Infrastructure Services
│   ├── 🚪 Ingress NGINX (Traffic Management)
│   └── 🗄️ MinIO (Object Storage)
└── � Demo Project
    ├── Frontend (React-like)
    ├── Backend (Node.js API)
    └── Database (Redis)
```

## 🎯 Características Empresariales

- ✅ **GitOps Native**: Todo manejado como código
- ✅ **Multi-Environment**: Simulación de dev/uat/prod
- ✅ **Promoción Automatizada**: Kargo para promociones entre entornos
- ✅ **Observabilidad Completa**: Métricas, logs, y tracing
- ✅ **Progressive Delivery**: Canary deployments con Argo Rollouts
- ✅ **Secret Management**: External Secrets para seguridad
- ✅ **Auto-healing**: Recuperación automática de servicios
- ✅ **Monitoring Stack**: Prometheus + Grafana + Loki

## 🚀 Inicio Rápido

## ⚡ Instalación Ultra-Rápida (Un Solo Comando)

Para usuarios que quieren **todo automático** sin tocar nada:

```bash
# Solo con Git instalado en Ubuntu/WSL:
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra
./install-everything.sh
```

**✨ Qué hace automáticamente:**
- 📦 **Instala Docker** si no existe
- 📦 **Instala kubectl** última versión
- 📦 **Instala Minikube** última versión  
- 📦 **Instala Helm** última versión
- 🔧 **Configura permisos** Docker automáticamente
- 🚀 **Despliega 18 aplicaciones** GitOps
- ⏱️ **5-15 minutos** y listo

**🎯 Resultado:** Infraestructura GitOps empresarial completa funcionando.

---

## 🛠️ Instalación Manual (Control Total)

Si prefieres instalar prerrequisitos manualmente:

### Prerrequisitos

Asegúrate de tener instalado:
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) (v1.25+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.25+)
- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Git](https://git-scm.com/) (v2.30+)

### 1. Configuración Inteligente del Entorno

```bash
# Clonar el repositorio
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra

# Configuración inteligente (no destructiva)
./bootstrap-gitops.sh
```

**El script inteligente:**
- 🔍 **Detecta** si ya existe un cluster gitops-dev
- 🔄 **Reutiliza** el cluster existente si está saludable
- 🆕 **Crea** uno nuevo solo si es necesario
- ⚡ **Optimiza** recursos (4 CPUs, 8GB RAM, 50GB disk)
- 🛡️ **Verifica** estado de salud antes de proceder

### 2. Acceso a Servicios Empresariales

Después del bootstrap (espera 5-10 minutos para todos los servicios):

| Servicio | URL | Credenciales | Propósito |
|----------|-----|-------------|-----------|
| **ArgoCD** | http://localhost:8080 | admin / (mostrado en output) | Control GitOps |
| **Kargo** | http://localhost:3000 | admin / admin | Promociones |
| **Grafana** | http://localhost:3001 | admin / admin | Dashboards |
| **Prometheus** | http://localhost:9090 | - | Métricas |
| **Jaeger** | http://localhost:16686 | - | Tracing |
| **Gitea** | http://localhost:3002 | admin / admin123 | Git repos |

### 3. Verificación del Estado

```bash
# Estado completo del cluster
kubectl get applications -n argocd

# Verificar todos los pods
kubectl get pods --all-namespaces | grep -E "(Running|Ready)"

# Dashboard de Minikube
minikube dashboard --profile=gitops-dev
```

## 🎯 Workflows de Promoción Empresarial

### Scenario 1: Promoción Manual entre Entornos
```bash
# 1. Verificar estado actual en Kargo
kubectl port-forward -n kargo svc/kargo-api 3000:443

# 2. Acceder a Kargo UI: https://localhost:3000
# 3. Crear proyecto y stages (dev -> uat -> prod)
# 4. Ejecutar promoción controlada
```

### Scenario 2: Pipeline CI/CD Completo
```bash
# 1. Crear workflow en Argo Workflows
kubectl apply -f examples/ci-cd-pipeline.yaml

# 2. Monitorear en Argo Workflows UI
kubectl port-forward -n argo-workflows svc/argo-workflows-server 2746:2746
```

### Scenario 3: Progressive Delivery
```bash
# 1. Desplegar con canary usando Argo Rollouts
kubectl apply -f examples/canary-deployment.yaml

# 2. Monitorear rollout
kubectl argo rollouts get rollout demo-rollout --watch
```

## 🛠️ Comandos Empresariales

### Gestión de Entornos
```bash
# Ver todas las aplicaciones
kubectl get applications -n argocd -o wide

# Sincronizar todas las apps
kubectl patch application gitops-infra-apps -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Verificar estado de salud
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.sync.status}{"\t"}{.status.health.status}{"\n"}{end}'
```

### Observabilidad
```bash
# Password de ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Logs de aplicaciones
kubectl logs -n demo-project -l app=demo-backend --tail=100

# Métricas en tiempo real
kubectl top pods --all-namespaces
```

### Troubleshooting
```bash
# Reiniciar port-forwards
./scripts/setup-port-forwards.sh

# Estado del cluster
minikube status --profile=gitops-dev

# Verificar recursos
kubectl describe nodes
```

## 🗑️ Gestión del Entorno

### Parada Segura (Preserva Estado)
```bash
# Parar cluster pero mantener datos
minikube stop --profile=gitops-dev
```

### Limpieza Completa
```bash
# Eliminar completamente (solo si realmente necesario)
./cleanup-gitops.sh
```

### Reinicio Inteligente
```bash
# Reiniciar manteniendo configuración
minikube start --profile=gitops-dev
./scripts/setup-port-forwards.sh
```

## 📁 Estructura Empresarial

```
├── components/                 # Componentes de infraestructura
│   ├── argo-rollouts/         # Progressive delivery
│   ├── argo-workflows/        # Pipelines CI/CD  
│   ├── cert-manager/          # Gestión de certificados
│   ├── external-secrets/      # Gestión de secretos
│   ├── gitea/                 # Repositorio Git interno
│   ├── grafana/               # Dashboards de observabilidad
│   ├── ingress-nginx/         # Gestión de tráfico
│   ├── jaeger/                # Tracing distribuido
│   ├── kargo/                 # Promociones entre entornos
│   ├── loki/                  # Agregación de logs
│   ├── minio/                 # Almacenamiento de objetos
│   └── monitoring/            # Stack de Prometheus
├── projects/                  # Proyectos de aplicaciones
│   └── demo-project/          # Aplicación demo 3-tier
├── manifests/                 # Manifiestos de aplicaciones
├── scripts/                   # Scripts de utilidad
├── examples/                  # Ejemplos de uso
├── docs/                      # Documentación detallada
│   ├── QUICKSTART.md          # Guía de inicio rápido
│   ├── INFRASTRUCTURE_STATUS.md # Estado de infraestructura
│   └── VALIDATION_REPORT.md   # Reporte de validación
├── bootstrap-gitops.sh        # Setup inteligente
├── cleanup-gitops.sh          # Limpieza completa
└── gitops-infra-apps.yaml     # App-of-apps principal
```

## 🎓 Path de Aprendizaje Empresarial

### Nivel 1: Fundamentos GitOps
1. **Explorar ArgoCD**: Ver cómo funciona GitOps en la práctica
2. **Entender Sync**: Apps sincronizadas vs OutOfSync
3. **Observabilidad**: Grafana dashboards y métricas de Prometheus

### Nivel 2: Promociones y Workflows  
1. **Kargo**: Configurar promociones dev -> uat -> prod
2. **Argo Workflows**: Crear pipelines de CI/CD
3. **Argo Rollouts**: Implementar canary deployments

### Nivel 3: Operaciones Avanzadas
1. **Monitoring**: Configurar alertas y dashboards custom
2. **Tracing**: Usar Jaeger para troubleshooting
3. **Secrets**: Gestionar secrets con External Secrets

## 🔧 Configuración Multi-Cluster (NUEVO!)

### ⚡ Setup Multi-Cluster Completo (Un Solo Comando)

Para crear el **entorno empresarial completo** con 3 clusters:

```bash
# Crear DEV + PRE + PROD clusters con promociones
./bootstrap-multi-cluster.sh
```

**✨ Qué crea automáticamente:**
- 🚧 **Cluster DEV** (gitops-dev): 4 CPUs, 8GB RAM - Desarrollo completo
- 🧪 **Cluster PRE** (gitops-pre): 3 CPUs, 6GB RAM - Testing/UAT  
- 🏭 **Cluster PROD** (gitops-prod): 6 CPUs, 12GB RAM - Producción
- 🎯 **ArgoCD en cada cluster** con puertos separados
- 🔄 **Kargo para promociones** automáticas entre entornos
- ⏱️ **15-25 minutos** para entorno completo

**🎯 Resultado:** Simulación empresarial completa con promociones DEV → PRE → PROD

### 🌐 Acceso Multi-Cluster

Después del setup, tendrás acceso a:

| Cluster | ArgoCD URL | Propósito | Recursos |
|---------|------------|-----------|----------|
| **gitops-dev** | http://localhost:8080 | Desarrollo | 4 CPU, 8GB |
| **gitops-pre** | http://localhost:8081 | Testing/UAT | 3 CPU, 6GB |
| **gitops-prod** | http://localhost:8082 | Producción | 6 CPU, 12GB |

### 🎯 Configurar Promociones con Kargo

```bash
# Configurar pipeline de promociones DEV → PRE → PROD
./scripts/setup-kargo-promotions.sh

# Acceder a Kargo UI para gestionar promociones
# URL: https://localhost:3000 (admin/admin)
```

### 🛠️ Gestión Multi-Cluster

```bash
# Ver estado de todos los clusters
./scripts/cluster-status.sh

# Cambiar entre clusters
kubectl config use-context gitops-dev   # Desarrollo
kubectl config use-context gitops-pre   # Testing
kubectl config use-context gitops-prod  # Producción

# Parar todos los clusters (preservando datos)
./cleanup-multi-cluster.sh soft

# Eliminar cluster específico
./cleanup-multi-cluster.sh partial
```

### 🔄 Workflows de Promoción Empresarial

#### Scenario 1: Promoción Automática DEV
```bash
# 1. Push a main branch → Auto-deploy a DEV
git push origin main

# 2. Ver despliegue en ArgoCD DEV
open http://localhost:8080
```

#### Scenario 2: Promoción Manual DEV → PRE  
```bash
# 1. Acceder a Kargo UI
open https://localhost:3000

# 2. Seleccionar proyecto demo-project-multicluster
# 3. Ejecutar promoción DEV → PRE
# 4. Verificar en ArgoCD PRE
open http://localhost:8081
```

#### Scenario 3: Promoción Controlada PRE → PROD
```bash
# 1. En Kargo UI, verificar tests en PRE
# 2. Ejecutar promoción PRE → PROD con aprobación
# 3. Monitorear despliegue en PROD
open http://localhost:8082

# 4. Verificar estado de la promoción
kubectl get stages -n kargo
```

## 🐛 Troubleshooting Empresarial

### Problema: Servicios no accesibles
```bash
# Verificar estado del cluster
minikube status --profile=gitops-dev

# Reiniciar port-forwards
./scripts/setup-port-forwards.sh

# Verificar pods problemáticos
kubectl get pods --all-namespaces | grep -v Running
```

### Problema: Aplicaciones OutOfSync
```bash
# Forzar sincronización
kubectl patch application <APP_NAME> -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Ver detalles del error
kubectl describe application <APP_NAME> -n argocd
```

### Problema: Recursos insuficientes
```bash
# Ver consumo de recursos
kubectl top nodes
kubectl top pods --all-namespaces

# Ajustar recursos de Minikube
minikube stop --profile=gitops-dev
minikube config set memory 10240 --profile=gitops-dev
minikube config set cpus 6 --profile=gitops-dev
minikube start --profile=gitops-dev
```

## 🤝 Contribuciones

Este es un entorno de aprendizaje empresarial. Siéntete libre de:
- ✨ Agregar nuevas aplicaciones en `projects/`
- 🔧 Modificar componentes de infraestructura en `components/`
- 🧪 Experimentar con diferentes configuraciones
- 📚 Agregar ejemplos en `examples/`

## 📚 Documentación Adicional

- 📖 **[Guía de Inicio Rápido](docs/QUICKSTART.md)** - Configuración paso a paso
- 🏗️ **[Estado de Infraestructura](docs/INFRASTRUCTURE_STATUS.md)** - Detalles de todos los componentes
- ✅ **[Reporte de Validación](docs/VALIDATION_REPORT.md)** - Certificación completa del entorno

## 📊 Estado Actual

**18 Aplicaciones Desplegadas:**
- ✅ Control GitOps: ArgoCD, Kargo, Gitea
- ✅ Observabilidad: Prometheus, Grafana, Loki, Jaeger  
- ✅ CI/CD: Argo Workflows, Argo Rollouts
- ✅ Infraestructura: Ingress, Cert Manager, External Secrets, MinIO
- ✅ Demo: Aplicación 3-tier completa

**Estado Perfecto:** Todas las 18 aplicaciones están completamente sincronizadas (Synced + Healthy), incluyendo la resolución exitosa del issue de sincronización de Gitea mediante configuración optimizada de PersistentVolumeClaim.

¡Happy Enterprise GitOps! 🎉🚀

## 🚀 Quick Start

### Prerequisites

Make sure you have installed:
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/)

### 1. Bootstrap Environment

```bash
# Clone this repository
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra

# Start the complete GitOps environment
./bootstrap-gitops.sh
```

This will:
- ✅ Clean any existing environment
- ✅ Start Minikube with optimized resources (4 CPUs, 8GB RAM)
- ✅ Install ArgoCD
- ✅ Deploy the complete GitOps stack
- ✅ Set up port-forwards for easy access

### 2. Access Services

After bootstrap (wait 5-10 minutes for all services):

| Service | URL | Credentials |
|---------|-----|-------------|
| **ArgoCD** | http://localhost:8080 | admin / (shown in bootstrap output) |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **Loki** | http://localhost:9080 | - |

### 3. View Demo Applications

```bash
# Port-forward demo applications
kubectl port-forward -n demo-project svc/demo-frontend 8082:80
kubectl port-forward -n demo-project svc/demo-backend 3001:3000

# Access demo apps
# Frontend: http://localhost:8082
# Backend API: http://localhost:3001
```

## 🛠️ Useful Commands

```bash
# Check all applications
kubectl get applications -n argocd

# Check all pods
kubectl get pods --all-namespaces

# Minikube dashboard
minikube dashboard --profile=gitops-dev

# View ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Sync all applications
kubectl patch application gitops-infra-apps -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## 🗑️ Cleanup

```bash
# Complete cleanup (removes everything)
./cleanup-gitops.sh
```

## 📁 Repository Structure

```
├── components/                 # Infrastructure components
│   ├── argo-rollouts/         # Progressive delivery
│   ├── argo-workflows/        # CI/CD pipelines
│   ├── grafana/               # Observability UI
│   ├── ingress-nginx/         # Traffic management
│   ├── kargo/                 # Promotional pipelines
│   ├── loki/                  # Log aggregation
│   ├── minio/                 # Object storage
│   └── monitoring/            # Prometheus stack
├── projects/                  # Application projects
│   └── demo-project/          # Demo 3-tier application
├── scripts/                   # Utility scripts
├── examples/                  # Usage examples
├── docs/                      # Detailed documentation
│   ├── QUICKSTART.md          # Quick start guide
│   ├── INFRASTRUCTURE_STATUS.md # Infrastructure status
│   └── VALIDATION_REPORT.md   # Validation report
├── bootstrap-gitops.sh        # Environment setup script
├── cleanup-gitops.sh          # Cleanup script
└── gitops-infra-apps.yaml     # Main app-of-apps
```

## 🎓 Learning Path

1. **Start Here**: Explore ArgoCD UI and see how GitOps works
2. **Monitoring**: Check Grafana dashboards and Prometheus metrics
3. **Logs**: Use Loki to view application logs
4. **Progressive Delivery**: Experiment with Argo Rollouts
5. **Pipelines**: Create workflows with Argo Workflows
6. **Promotions**: Set up promotional flows with Kargo

## 🐛 Troubleshooting

### Services not accessible
```bash
# Restart port-forwards
pkill -f "kubectl port-forward"
kubectl port-forward -n argocd svc/argocd-server 8080:80 &
kubectl port-forward -n monitoring svc/grafana 3000:80 &
```

### Applications stuck syncing
```bash
# Force refresh
kubectl patch application gitops-infra-apps -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Minikube issues
```bash
# Restart minikube
minikube stop --profile=gitops-dev
minikube start --profile=gitops-dev
```

## 🤝 Contributing

This is a learning environment. Feel free to:
- Add new applications to `projects/`
- Modify infrastructure components in `components/`
- Experiment with different configurations

Happy GitOps-ing! 🎉
