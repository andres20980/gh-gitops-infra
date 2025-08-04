# 🚀 Infraestructura GitOps Hipermodular

> **Plataforma GitOps completa y autónoma** con arquitectura hipermodular en español para desarrollo, preproducción y producción.

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29+-blue?logo=kubernetes)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-Latest-green?logo=argo)](https://argoproj.github.io/cd/)
[![Minikube](https://img.shields.io/badge/Minikube-Compatible-orange?logo=kubernetes)](https://minikube.sigs.k8s.io/)
[![Español](https://img.shields.io/badge/Idioma-Español-red)](README.md)

## 🌟 **Características Principales**

- **✅ Instalación 100% autónoma**: Un solo comando instala todo
- **🎯 Arquitectura hipermodular**: Scripts organizados por responsabilidades
- **🔄 GitOps nativo**: ArgoCD con App-of-Apps por fases
- **📊 Observabilidad completa**: Prometheus, Grafana, Loki, Jaeger
- **🛡️ Seguridad integrada**: Cert-Manager, External-Secrets
- **🌍 Multi-entorno**: Desarrollo, preproducción y producción
- **📖 Documentación en español**: Consistencia total del proyecto

## 🚀 **Instalación Rápida**

```bash
# Clona el repositorio
git clone https://github.com/asanchez-dev/gh-gitops-infra.git
cd gh-gitops-infra

# Instalación completa autónoma (requiere sudo)
sudo ./instalador.sh

# Para clusters adicionales (preproducción/producción)
./instalador.sh --cluster gitops-pre
./instalador.sh --cluster gitops-pro
```

## 🏗️ **Arquitectura del Sistema**

### **Estructura del Repositorio**
```
📁 gh-gitops-infra/
├── 🚀 instalador.sh                    # Punto de entrada único
├── 📄 README.md                        # Esta documentación
│
├── 📁 argo-apps/                       # Manifiestos ArgoCD principales
│   ├── app-of-apps.yaml                # Aplicación principal (orquestador)
│   ├── herramientas-gitops.yaml        # Referencia a herramientas GitOps
│   └── aplicaciones-custom.yaml        # ApplicationSet para apps de usuario
│
├── 📁 herramientas-gitops/              # Stack GitOps completo
│   ├── app-of-apps.yaml                # Orquestador por fases (1-6)
│   ├── cert-manager.yaml               # FASE 1: Certificados SSL
│   ├── ingress-nginx.yaml              # FASE 1: Ingress Controller
│   ├── minio.yaml                      # FASE 2: Almacenamiento S3
│   ├── prometheus-stack.yaml           # FASE 3: Métricas y alertas
│   ├── grafana.yaml                    # FASE 3: Dashboards
│   ├── loki.yaml                       # FASE 3: Logs centralizados
│   ├── jaeger.yaml                     # FASE 3: Trazabilidad distribuida
│   ├── argo-workflows.yaml             # FASE 4: Workflows CI/CD
│   ├── argo-rollouts.yaml              # FASE 4: Despliegues progresivos
│   ├── argo-events.yaml               # FASE 4: Eventos y triggers
│   ├── kargo.yaml                      # FASE 4: Promoción de entornos
│   ├── gitea.yaml                      # FASE 5: Repositorio Git interno
│   └── external-secrets.yaml           # FASE 6: Gestión de secretos
│
├── 📁 aplicaciones/                     # Aplicaciones de ejemplo
│   ├── demo-project/                   # Proyecto demo completo
│   └── simple-app/                     # Aplicación simple de prueba
│
├── 📁 scripts/                         # Scripts modulares en español
│   ├── bibliotecas/                    # Librerías compartidas
│   ├── nucleo/                         # Orquestador principal
│   ├── instaladores/                   # Instaladores de dependencias
│   ├── argocd/                         # Bootstrap GitOps (ArgoCD)
│   └── utilidades/                     # Utilidades de gestión
│
└── 📁 docs/                            # Documentación técnica detallada
```

### **Fases de Instalación GitOps**

| Fase | Componentes | Descripción |
|------|-------------|-------------|
| **1️⃣ Base** | cert-manager, ingress-nginx | Infraestructura fundamental |
| **2️⃣ Almacenamiento** | minio | Backend S3 para artifacts |
| **3️⃣ Observabilidad** | prometheus, grafana, loki, jaeger | Stack completo de monitorización |
| **4️⃣ GitOps** | argo-workflows, argo-rollouts, argo-events, kargo | Herramientas GitOps avanzadas |
| **5️⃣ Repositorios** | gitea | Git interno para el ciclo completo |
| **6️⃣ Seguridad** | external-secrets | Gestión segura de credenciales |

## 🛠️ **Requisitos del Sistema**

### **Requisitos Mínimos**
- **OS**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **RAM**: 8GB mínimo (16GB recomendado)
- **CPU**: 4 cores mínimo (8 cores recomendado)
- **Disco**: 50GB libres mínimo
- **Permisos**: sudo para instalación de dependencias

### **Dependencias Automatizadas**
El instalador gestiona automáticamente:
- Docker Engine
- Minikube
- kubectl
- Helm
- ArgoCD CLI

## 🎯 **Casos de Uso**

### **Desarrollo Local**
```bash
# Cluster de desarrollo con todas las herramientas
./instalador.sh
```

### **Multi-Entorno**
```bash
# Desarrollo
./instalador.sh --cluster gitops-dev

# Preproducción
./instalador.sh --cluster gitops-pre

# Producción
./instalador.sh --cluster gitops-pro
```

### **Personalización**
```bash
# Solo herramientas específicas
./instalador.sh --componentes prometheus,grafana,argocd

# Con configuración custom
./instalador.sh --config mi-configuracion.yaml
```

## 📊 **Acceso a Servicios**

Una vez instalado, accede a:

| Servicio | URL Local | Credenciales |
|----------|-----------|--------------|
| **ArgoCD** | http://localhost:8080 | admin / Ver logs del pod |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Prometheus** | http://localhost:9090 | - |
| **Jaeger** | http://localhost:16686 | - |
| **Gitea** | http://localhost:3000 | gitea / gitea |
| **Kargo** | http://localhost:31444 | - |

## 🔧 **Scripts de Gestión**

### **Utilidades Principales**
```bash
# Configuración del entorno
./scripts/utilidades/configuracion.sh

# Diagnósticos del sistema
./scripts/utilidades/diagnosticos.sh

# Mantenimiento y limpieza
./scripts/utilidades/mantenimiento.sh
```

### **Comandos Útiles**
```bash
# Estado de todos los componentes
kubectl get applications -n argocd

# Logs del orquestador
kubectl logs -n argocd -l app.kubernetes.io/name=herramientas-gitops

# Sincronizar todas las aplicaciones
argocd app sync --all
```

## 🚨 **Solución de Problemas**

### **Problemas Comunes**

**❌ Error de permisos**
```bash
sudo chown -R $USER:$USER ~/.kube
sudo chmod 644 ~/.kube/config
```

**❌ Recursos insuficientes**
```bash
# Incrementar recursos de minikube
minikube config set memory 8192
minikube config set cpus 4
minikube delete && minikube start
```

**❌ Pods en estado Pending**
```bash
# Verificar recursos del cluster
kubectl top nodes
kubectl describe nodes
```

### **Logs de Diagnóstico**
```bash
# Diagnóstico completo
./scripts/utilidades/diagnosticos.sh --completo

# Logs específicos
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

## 🤝 **Contribución**

¡Contribuciones bienvenidas! Por favor:

1. **Fork** el repositorio
2. **Crea** una rama con tu funcionalidad: `git checkout -b nueva-funcionalidad`
3. **Commitea** tus cambios: `git commit -am 'Añade nueva funcionalidad'`
4. **Push** a la rama: `git push origin nueva-funcionalidad`
5. **Abre** un Pull Request

Ver [CONTRIBUTING.md](docs/CONTRIBUTING.md) para más detalles.

## 📜 **Licencia**

Este proyecto está bajo la licencia MIT. Ver [LICENSE](LICENSE) para más información.

## 📞 **Soporte**

- **Issues**: [GitHub Issues](https://github.com/asanchez-dev/gh-gitops-infra/issues)
- **Documentación**: [docs/](docs/)
- **Wiki**: [GitHub Wiki](https://github.com/asanchez-dev/gh-gitops-infra/wiki)

---

> **Creado con ❤️ para la comunidad GitOps hispanohablante**

[![Estrella en GitHub](https://img.shields.io/github/stars/asanchez-dev/gh-gitops-infra?style=social)](https://github.com/asanchez-dev/gh-gitops-infra)
