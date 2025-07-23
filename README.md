# 🚀 Infraestructura GitOps Multi-Cluster Empresarial

> **Plataforma GitOps completa** con ArgoCD, orquestación multi-cluster, observabilidad integral y workflows de promoción automatizada siguiendo las mejores prácticas de CNCF.

## � **PASO 1: Hacer Fork del Repositorio**

**⚠️ IMPORTANTE**: Antes de instalar, debes hacer fork de este repositorio:

1. **Hacer Fork**: Haz clic en "Fork" en la esquina superior derecha de GitHub
2. **Clonar tu Fork**: 
   ```bash
   git clone https://github.com/TU_USUARIO/gh-gitops-infra.git
   cd gh-gitops-infra
   ```

¿Por qué hacer fork? El sistema GitOps necesita apuntar a **tu repositorio** para:
- ✅ Configuración automática de ArgoCD con tu repo
- ✅ Gestión de secrets y configuraciones personalizadas  
- ✅ Workflows de promoción DEV → PRE → PROD desde tu fork

## �🎯 **PASO 2: Instalación con Un Solo Comando**

```bash
# Instalación completa desde cero (instala TODO automáticamente)
./instalar-todo.sh
```

**¡Eso es todo!** ✨ Este único comando:
- ✅ **Instala prerrequisitos**: Docker, kubectl, minikube, helm (si no están instalados)
- ✅ **Auto-detecta tu fork**: Configura GitOps con tu repositorio automáticamente
- ✅ **Crea 3 clusters**: Minikube DEV/PRE/PROD optimizados para tu máquina
- ✅ **Despliega ArgoCD**: Control plane GitOps con sincronización automática
- ✅ **Provisiona infraestructura**: 18+ componentes listos para usar
- ✅ **Configura acceso**: Port-forwarding automático para todas las UIs

---

## 🏗️ **Arquitectura del Sistema**

```
🏢 Plataforma GitOps Multi-Cluster Empresarial
┌─────────────────────────────────────────────────────────────────┐
│  🎯 Control (DEV)          🧪 Staging (PRE)     🏭 Producción    │
│  ┌─────────────────────┐   ┌─────────────────┐  ┌──────────────┐  │
│  │ 🔄 ArgoCD (Master)  │──▶│   Aplicaciones   │─▶│ Aplicaciones │  │
│  │ 🚀 Kargo Promociones│   │   (GitOps Sync)  │  │(GitOps Sync) │  │
│  │ 📊 Observabilidad   │   └─────────────────┘  └──────────────┘  │
│  │ 🎢 Apps Demo        │                                          │
│  └─────────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘

📦 Un solo ArgoCD gestiona todos los clusters (Mejor Práctica GitOps)
🔄 Promociones automatizadas: DEV → PRE → PROD
📊 Observabilidad centralizada y monitorización
```

## ✨ **Características Principales**

| Característica | Descripción | Estado |
|----------------|-------------|---------|
| **🔄 GitOps Nativo** | Todo como código, infraestructura declarativa | ✅ Listo |
| **🌐 Multi-Cluster** | Simulación DEV/PRE/PROD en máquina local | ✅ Listo |
| **🚀 Auto-Promociones** | Promociones de entorno con Kargo | ✅ Listo |
| **📊 Observabilidad Total** | Prometheus + Grafana + Loki + Jaeger | ✅ Listo |
| **🎢 Entrega Progresiva** | Despliegues canary con Argo Rollouts | ✅ Listo |
| **🔐 Seguridad Primero** | External Secrets, RBAC, políticas de red | ✅ Listo |
| **🏥 Auto-Recuperación** | Recuperación automática y health checks | ✅ Listo |

---

## 🚀 **Guía de Inicio Rápido**

### Prerrequisitos del Sistema
- **SO**: Ubuntu 20.04+, WSL2, o macOS
- **Recursos Mínimos**: 8GB+ RAM, 4+ núcleos CPU, 50GB+ espacio en disco
- **Red**: Conexión a internet para descargas
- **Permisos**: Usuario con permisos sudo (para instalar Docker si es necesario)

**💡 Nota**: Docker, kubectl, minikube y helm se instalan automáticamente si no están presentes.

### Instalación Paso a Paso

```bash
# 1. Fork del repositorio en GitHub (¡OBLIGATORIO!)
# Hacer clic en "Fork" en: https://github.com/andres20980/gh-gitops-infra

# 2. Clonar TU fork (cambia TU_USUARIO)
git clone https://github.com/TU_USUARIO/gh-gitops-infra.git
cd gh-gitops-infra

# 3. Ejecutar instalación completa
./instalar-todo.sh
```

**Lo que sucede automáticamente:**
1. ✅ **Verificación**: Comprueba recursos del sistema
2. ✅ **Prerrequisitos**: Instala Docker, kubectl, minikube, helm automáticamente  
3. ✅ **Auto-configuración**: Detecta tu fork y genera configuración optimizada
4. ✅ **Clusters**: Crea 3 clusters Minikube con recursos optimizados
5. ✅ **ArgoCD**: Despliega control plane GitOps conectado a tu repositorio
6. ✅ **Infraestructura**: ArgoCD despliega automáticamente todos los componentes
7. ✅ **Acceso**: Configura port-forwarding para todas las UIs

### Salida Esperada
```
🏆================================================
   🎉 ¡INSTALACIÓN COMPLETA TERMINADA!
   📊 ¡Plataforma GitOps Multi-Cluster Lista!
================================================

🎯 URLs de Acceso Completas:

🔄 CORE GITOPS:
   ArgoCD UI:       http://localhost:8080 (admin/PASSWORD)
   Kargo UI:        http://localhost:8082 (admin/admin123)

📊 OBSERVABILIDAD:
   Grafana:         http://localhost:8081 (admin/admin)
   Prometheus:      http://localhost:8084 (métricas)
   Jaeger Tracing:  http://localhost:8086 (interfaz web)

🛠️ INFRAESTRUCTURA:
   Gitea:           http://localhost:8083 (admin/admin123)
   Argo Workflows:  http://localhost:8085 (interfaz web)
   MinIO Console:   http://localhost:8087 (admin/admin123)
   MinIO API:       http://localhost:8088 (S3 compatible)
   
📱 APLICACIONES DEMO:
   Frontend:        http://localhost:8089 (React App)
   Backend API:     http://localhost:8090 (Node.js API)
```

---

## 🎯 **Infraestructura Completa Disponible**

### 🔄 **Core GitOps (3 componentes)**
| Componente | Propósito | Puerto UI | Credenciales |
|------------|-----------|-----------|--------------|
| **ArgoCD** | Control GitOps & CD/CD | `:8080` | `admin/PASSWORD` |
| **Kargo** | Promociones multi-entorno | `:8082` | `admin/admin123` |
| **Argo Rollouts** | Despliegues canary/blue-green | - | Dashboard en ArgoCD |

### 📊 **Observabilidad Completa (4 componentes)**
| Componente | Propósito | Puerto UI | Credenciales |
|------------|-----------|-----------|--------------|
| **Grafana** | Dashboards & visualización | `:8081` | `admin/admin` |
| **Prometheus** | Métricas & alertas | `:8084` | Sin autenticación |
| **Loki** | Agregación de logs | - | Integrado con Grafana |
| **Jaeger** | Tracing distribuido | `:8086` | Sin autenticación |

### 🛠️ **Infraestructura & Servicios (6 componentes)**
| Componente | Propósito | Puerto UI | Credenciales |
|------------|-----------|-----------|--------------|
| **Gitea** | Git repositories local | `:8083` | `admin/admin123` |
| **MinIO Console** | Almacenamiento S3 UI | `:8087` | `admin/admin123` |
| **MinIO API** | API S3 compatible | `:8088` | `admin/admin123` |
| **Argo Workflows** | CI/CD & pipelines | `:8085` | Sin autenticación |
| **Cert-Manager** | Gestión certificados TLS | - | Automático |
| **External Secrets** | Gestión secrets externos | - | Automático |
| **Ingress NGINX** | Controlador de ingress | - | Automático |

### 🧪 **Aplicaciones Demo (3 aplicaciones)**
| Aplicación | Tecnología | Puerto UI | Descripción |
|------------|-----------|-----------|-------------|
| **Frontend** | React.js | `:8089` | UI moderna con PWA |
| **Backend API** | Node.js/Express | `:8090` | API REST con OpenAPI |
| **Database** | PostgreSQL | `:5432` | Base de datos relacional |

### 🔄 **Workflows & Automatización (1 componente)**
| Componente | Propósito | Puerto UI | Credenciales |
|------------|-----------|-----------|--------------|
| **Event-driven Workflows** | Triggers automáticos | - | Integrado con Argo Workflows |

---

## 🎮 **Comandos Esenciales**

### Gestión de Clusters
```bash
# Ver estado de todos los clusters
kubectl config get-contexts

# Cambiar entre clusters
kubectl config use-context gitops-dev    # Cluster de desarrollo
kubectl config use-context gitops-pre    # Cluster de staging  
kubectl config use-context gitops-prod   # Cluster de producción

# Ver todos los pods en ArgoCD
kubectl get pods -n argocd

# Ver aplicaciones de ArgoCD
kubectl get applications -n argocd
```

### Port-Forwarding Manual
```bash
# Si necesitas reconfigurar acceso a las UIs (puertos correlativos)
kubectl port-forward -n argocd svc/argocd-server 8080:443 &
kubectl port-forward -n grafana svc/grafana 8081:80 &
kubectl port-forward -n kargo svc/kargo-ui 8082:8080 &
kubectl port-forward -n gitea svc/gitea-http 8083:3000 &
kubectl port-forward -n monitoring svc/prometheus-server 8084:80 &
kubectl port-forward -n argo-workflows svc/argo-workflows-server 8085:2746 &
kubectl port-forward -n jaeger svc/jaeger-query 8086:16686 &
kubectl port-forward -n minio svc/minio-console 8087:9001 &
kubectl port-forward -n minio svc/minio 8088:9000 &
kubectl port-forward -n demo-project svc/frontend 8089:80 &
kubectl port-forward -n demo-project svc/backend 8090:3000 &
```

### Verificación de Estado
```bash
# ★ Script principal de verificación
./scripts/estado-clusters.sh

# ★ Reconfigurar port-forwards si fallan
./scripts/configurar-puertos.sh

# Ver logs de instalación (si hubo problemas)
journalctl -u docker --no-pager -l
```

### Gestión Avanzada
```bash
# Ver configuración generada automáticamente
cat config/environment.conf

# Limpiar entorno completo (mantiene Docker/kubectl/minikube)
./scripts/limpiar-multi-cluster.sh

# Reinstalar desde cero
./scripts/limpiar-multi-cluster.sh && ./instalar-todo.sh
```

---

## 🔍 **Casos de Uso Empresariales**

### 1. **Despliegue Multi-Entorno**
```bash
# Usar Kargo para promoción automática DEV → PRE → PROD
# 1. Abrir Kargo UI: http://localhost:8082
# 2. Crear stage para promoción
# 3. Configurar pipeline: DEV → PRE → PROD
# 4. Ejecutar promoción automática
```

### 2. **Despliegue Canary con Argo Rollouts**
```bash
# Ver rollout en tiempo real
kubectl argo rollouts get rollout demo-app -n demo-project

# Promover manualmente un canary
kubectl argo rollouts promote demo-app -n demo-project

# Hacer rollback automático
kubectl argo rollouts abort demo-app -n demo-project
```

### 3. **Monitorización y Alertas**
```bash
# Acceder a métricas en tiempo real
open http://localhost:8084  # Prometheus métricas
open http://localhost:8081  # Grafana dashboards
open http://localhost:8086  # Jaeger tracing

# Ver logs centralizados en Grafana con Loki
# Dashboard: "Logs" en Grafana UI
```

### 4. **Gestión de Secretos**
```bash
# Usar External Secrets para gestión segura
kubectl get externalsecrets -A

# Ver secretos sincronizados
kubectl get secrets -n demo-project
```

---

## 🏗️ **Arquitectura Técnica Detallada**

### Topología de Red
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   gitops-dev    │    │   gitops-pre    │    │   gitops-prod   │
│   Control Plane │    │   Staging Env   │    │  Production Env │
│                 │    │                 │    │                 │
│ ArgoCD Master   │────│ ArgoCD Agent    │────│ ArgoCD Agent    │
│ Observability   │    │ Apps + Infra    │    │ Apps + Infra    │
│ Demo Apps       │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                        ┌───────────────┐
                        │   Host OS     │
                        │  Port Forward │
                        │ 8080-8090     │
                        │ (Correlativos)│
                        └───────────────┘
```

### Flujo de Datos GitOps
```
1. 📝 Code Push → Git Repository (Gitea local)
2. 🔄 ArgoCD detecta cambios → Sync automático
3. 🚀 Kargo ejecuta promoción → DEV → PRE → PROD
4. 📊 Observabilidad recolecta métricas → Dashboards
5. 🎯 Argo Rollouts gestiona deployment → Blue/Green o Canary
6. 🔐 External Secrets gestiona configuración → Secrets seguros
```

---

## 🛠️ **Personalización y Extensión**

### Añadir Nuevas Aplicaciones
```yaml
# Crear nueva aplicación en proyectos/tu-proyecto/apps/
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tu-nueva-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://tu-repo.git
    path: manifiestos/tu-app
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: tu-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Configurar Nuevos Clusters
```bash
# Añadir cluster adicional
minikube start -p gitops-test --kubernetes-version=v1.28.0

# Registrar en ArgoCD
argocd cluster add gitops-test
```

### Personalizar Observabilidad
```yaml
# Añadir dashboards custom en componentes/grafana/
# Configurar alertas custom en componentes/monitoring/
# Extender métricas con ServiceMonitor custom
```

---

## 🚨 **Troubleshooting**

### Problemas Comunes

**1. Error: "Repository not found" o "Failed to detect Git repository"**
```bash
# SOLUCIÓN: Verificar que hiciste fork y clonaste TU repositorio
git remote -v  # Debe mostrar tu usuario, no 'andres20980'

# Si clonaste el repo original por error:
git remote set-url origin https://github.com/TU_USUARIO/gh-gitops-infra.git
```

**2. ArgoCD no sincroniza aplicaciones**
```bash
# Verificar estado de ArgoCD
kubectl get pods -n argocd
kubectl logs -n argocd deployment/argocd-application-controller

# Forzar sincronización
argocd app sync NOMBRE_APP
```

**3. Port-forwarding no funciona**
```bash
# Matar procesos zombie
pkill -f "kubectl port-forward"

# Reconfigurar todos los port-forwards
./scripts/configurar-puertos.sh
```

**4. Clusters no responden**
```bash
# Verificar estado de Minikube
minikube status -p gitops-dev
minikube status -p gitops-pre  
minikube status -p gitops-prod

# Reiniciar cluster problemático
minikube stop -p gitops-dev
minikube start -p gitops-dev
```

**5. Problemas de recursos (RAM/CPU insuficiente)**
```bash
# Verificar recursos disponibles
free -h && nproc

# El script se adapta automáticamente, pero si falla:
# - Cierra aplicaciones innecesarias
# - Reinicia Docker: sudo systemctl restart docker
# - Si persiste, el sistema necesita más recursos físicos
```

**6. Docker no está instalado o no funciona**
```bash
# El script instala Docker automáticamente, pero si falla:
sudo apt update && sudo apt install -y docker.io
sudo systemctl start docker
sudo usermod -aG docker $USER
# Reiniciar sesión después del usermod
```

### Logs y Diagnóstico
```bash
# Ver logs de ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Ver logs de Kargo
kubectl logs -n kargo -l app=kargo

# Ver logs de aplicaciones demo
kubectl logs -n demo-project -l app=frontend
kubectl logs -n demo-project -l app=backend
```

---

## 📚 **Recursos y Referencias**

### Documentación Oficial
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kargo Documentation](https://kargo.io/docs/)
- [Prometheus + Grafana](https://prometheus.io/docs/)
- [GitOps Best Practices](https://www.gitops.tech/)

### Arquitecturas de Referencia
- [CNCF Landscape](https://landscape.cncf.io/)
- [GitOps Toolkit](https://toolkit.fluxcd.io/)
- [Kubernetes Multi-Cluster](https://kubernetes.io/docs/concepts/cluster-administration/cluster-administration-overview/)

---

## 🤝 **Contribución y Soporte**

### Estructura del Proyecto
```
gh-gitops-infra/
├── 🚀 instalar-todo.sh           # ★ ÚNICO SCRIPT A EJECUTAR ★
├── 📁 componentes/               # Definiciones de infraestructura GitOps
├── 📱 proyectos/                 # Aplicaciones y proyectos
├── 🎯 manifiestos/               # Manifiestos Kubernetes  
├── 🛠️ scripts/                   # Scripts internos (NO ejecutar manualmente)
│   ├── configurar-entorno.sh    # Generación de configuración
│   ├── arrancar-multi-cluster.sh # Despliegue multi-cluster
│   ├── limpiar-multi-cluster.sh # Limpieza de entorno
│   ├── estado-clusters.sh       # Verificación de estado
│   └── configurar-puertos.sh    # Configuración de acceso UI
├── ⚙️ config/                    # Configuración generada automáticamente
└── 📖 README.md                  # Esta documentación
```

### Reportar Issues
1. 🔍 Verificar issues existentes
2. 📝 Crear issue detallado con logs
3. 🏷️ Etiquetar apropiadamente
4. 📊 Incluir outputs de diagnóstico

### Desarrollo
```bash
# Fork del repositorio (OBLIGATORIO)
# 1. Hacer fork en GitHub: https://github.com/andres20980/gh-gitops-infra
# 2. Clonar TU fork (no el original)

# Crear rama feature  
git checkout -b feature/nueva-funcionalidad

# Desarrollar y testear
./instalar-todo.sh  # Probar instalación completa desde cero

# Commit y PR
git commit -m "feat: nueva funcionalidad increíble"
git push origin feature/nueva-funcionalidad
```

---

## 📈 **Roadmap**

### ✅ **Implementado (v1.0)**
- [x] Instalación automatizada con un comando
- [x] Multi-cluster GitOps con ArgoCD único
- [x] Observabilidad completa (Prometheus + Grafana + Loki + Jaeger)
- [x] Promociones automatizadas con Kargo
- [x] Despliegues progresivos con Argo Rollouts
- [x] Aplicaciones demo funcionales
- [x] Port-forwarding automático para todas las UIs

### 🚧 **En Desarrollo (v1.1)**
- [ ] Integración con Vault para gestión avanzada de secretos
- [ ] Políticas de seguridad con Gatekeeper/OPA
- [ ] Backup automático con Velero
- [ ] Métricas custom y SLIs/SLOs
- [ ] Integración con proveedores cloud (AWS/GCP/Azure)

### 🔮 **Futuro (v2.0)**
- [ ] Service Mesh con Istio
- [ ] Chaos Engineering con Litmus
- [ ] GitOps multitenancy
- [ ] Advanced deployment strategies
- [ ] Cost optimization automático

---

## 🎯 **Conclusión**

Esta plataforma GitOps representa una **implementación completa de clase empresarial** que demuestra las mejores prácticas modernas de DevOps y cloud-native computing.

### 💡 **Valor Empresarial**
- 🚀 **Acelera time-to-market** con deployments automatizados
- 🔒 **Aumenta seguridad** con GitOps declarativo y gestión de secretos  
- 📊 **Mejora observabilidad** con stack completo de monitorización
- 🎯 **Reduce riesgos** con despliegues progresivos y rollbacks automáticos
- 💰 **Optimiza costos** con infraestructura como código y auto-scaling

### 🏆 **Logros Técnicos**
- ✅ Implementación de referencia siguiendo **CNCF best practices**
- ✅ **Single-command installation** para máxima facilidad de uso
- ✅ **18+ componentes integrados** funcionando en armonía
- ✅ **Documentación exhaustiva** para adopción empresarial
- ✅ **Multi-cluster ready** para escalabilidad real

¡Empieza tu viaje GitOps ejecutando `./instalar-todo.sh` ahora mismo! 🚀

---

<div align="center">

**🌟 ¡Estrella este repositorio si te resulta útil! 🌟**

</div>
