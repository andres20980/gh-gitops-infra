# 🏢 Arquitectura Multi-Cluster para Promociones GitOps

## 🎯 Objetivo Empresarial

Simular un entorno empresarial completo con **promociones automáticas** entre diferentes etapas del ciclo de vida de aplicaciones usando **Kargo** y **ArgoCD**.

## 🏗️ Diseño de Clusters

```
🌐 Ecosistema GitOps Multi-Cluster:

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   🚧 DEV        │    │   🧪 PRE/UAT    │    │   🏭 PROD       │
│  gitops-dev     │    │  gitops-pre     │    │  gitops-prod    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Desarrollo    │───▶│ • Testing       │───▶│ • Producción    │
│ • Experimental  │    │ • Validación    │    │ • Estable       │
│ • Inestable     │    │ • QA            │    │ • Crítico       │
│ • Cambios rapidos│    │ • Performance   │    │ • Alta disponib.│
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │    🎯 KARGO CENTRAL       │
                    │   Promociones Automáticas │
                    │                           │
                    │  DEV → PRE → PROD         │
                    │  • Validaciones           │
                    │  • Rollbacks              │
                    │  • Aprobaciones           │
                    └───────────────────────────┘
```

## 📊 Especificaciones por Cluster

### 🚧 **DEV (gitops-dev)**
```yaml
Propósito: Desarrollo y experimentación
Recursos: 4 CPUs, 8GB RAM, 50GB disk
Aplicaciones:
  - ArgoCD (gestor principal)
  - Kargo (controlador de promociones)
  - Stack completo de observabilidad
  - Demo applications (versiones inestables)
Características:
  - Despliegues automáticos desde main
  - Testing continuo
  - Logs detallados para debugging
```

### 🧪 **PRE/UAT (gitops-pre)**
```yaml
Propósito: Testing y validación
Recursos: 3 CPUs, 6GB RAM, 30GB disk
Aplicaciones:
  - ArgoCD (conectado a DEV)
  - Subset de observabilidad
  - Demo applications (versiones candidatas)
  - Testing automatizado
Características:
  - Promociones desde DEV
  - Tests de integración
  - Performance testing
  - Validación de releases
```

### 🏭 **PROD (gitops-prod)**
```yaml
Propósito: Producción estable
Recursos: 6 CPUs, 12GB RAM, 100GB disk
Aplicaciones:
  - ArgoCD (solo lectura desde PRE)
  - Observabilidad completa + alertas
  - Demo applications (versiones estables)
  - Backup y recovery
Características:
  - Promociones solo desde PRE
  - Alta disponibilidad
  - Monitoreo crítico
  - Rollback automático
```

## 🔄 Flujo de Promociones con Kargo

### Pipeline Automático
```
┌──────────┐    ┌──────────┐    ┌──────────┐
│   DEV    │    │   PRE    │    │   PROD   │
│          │    │          │    │          │
│ git push │───▶│ promote  │───▶│ promote  │
│   main   │    │ if tests │    │if stable │
│          │    │   pass   │    │          │
└──────────┘    └──────────┘    └──────────┘
     │               │               │
     ▼               ▼               ▼
   Auto             Manual        Manual
 Deployment      with Gates    with Approval
```

### Criterios de Promoción
- **DEV → PRE**: Tests unitarios + build exitoso
- **PRE → PROD**: Tests de integración + validación manual + performance OK

## 🛠️ Scripts de Implementación

### Creación Multi-Cluster
```bash
# Crear los 3 clusters
./scripts/create-multi-cluster.sh

# Configurar Kargo para promociones
./scripts/setup-kargo-promotions.sh

# Desplegar aplicaciones en todos los entornos
./scripts/deploy-to-all-clusters.sh
```

### Gestión de Promociones
```bash
# Ver estado de todos los clusters
./scripts/cluster-status.sh

# Promover aplicación de DEV a PRE
kargo promote --from dev --to pre --app demo-app

# Promover aplicación de PRE a PROD
kargo promote --from pre --to prod --app demo-app --approve
```

## 📱 Demo Applications Multi-Cluster

### Aplicación 3-Tier por Entorno
```
Frontend v1.0.0 (DEV) → v0.9.5 (PRE) → v0.9.0 (PROD)
Backend  v2.1.0 (DEV) → v2.0.8 (PRE) → v2.0.5 (PROD)
Database v1.5.0 (DEV) → v1.4.9 (PRE) → v1.4.7 (PROD)
```

### Simulación Realista
- **DEV**: Versiones cutting-edge con features experimentales
- **PRE**: Release candidates estabilizados
- **PROD**: Versiones probadas y estables

## 🎯 Casos de Uso Empresariales

### 1. **Feature Development**
```
Developer → commit to feature branch
         → DEV auto-deployment
         → feature testing
         → merge to main
         → promote to PRE
         → QA validation
         → promote to PROD
```

### 2. **Hotfix Pipeline**
```
Critical bug → hotfix branch
            → DEV testing
            → fast-track to PRE
            → minimal validation
            → emergency PROD deployment
```

### 3. **Rollback Scenarios**
```
PROD issue detected → automatic rollback to previous version
                   → investigate in DEV
                   → fix in DEV
                   → promote through pipeline
```

## 🔧 Comandos de Administración

### Cluster Management
```bash
# Start all clusters
minikube start --profile=gitops-dev
minikube start --profile=gitops-pre  
minikube start --profile=gitops-prod

# Switch between clusters  
kubectl config use-context gitops-dev
kubectl config use-context gitops-pre
kubectl config use-context gitops-prod

# View all cluster status
kubectl config get-contexts
```

### Kargo Operations
```bash
# View promotion pipeline
kargo get stages --all-namespaces

# Manual promotion
kargo promote stage dev-to-pre

# Rollback
kargo rollback stage pre --to-revision previous
```

## 📊 Observabilidad Multi-Cluster

### Grafana Dashboards
- **Cluster Overview**: Estado de los 3 clusters
- **Promotion Pipeline**: Estado de promociones
- **Application Health**: Salud por entorno
- **Performance Comparison**: Métricas DEV vs PRE vs PROD

### Alerting Rules
- **DEV**: Avisos informativos
- **PRE**: Alertas de warning  
- **PROD**: Alertas críticas + paging

## 🎓 Learning Objectives

Al completar este setup, tendrás experiencia con:
- ✅ **Multi-cluster GitOps** management
- ✅ **Progressive delivery** con Kargo
- ✅ **Environment promotion** strategies
- ✅ **Production-grade** monitoring
- ✅ **Enterprise workflows** simulation

---

**🚀 ¡Lista para simular entornos empresariales reales!**
