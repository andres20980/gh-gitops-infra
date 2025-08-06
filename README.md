# 🚀 Infraestructura GitOps España

> **Plataforma GitOps completa y totalmente autónoma** - Entorno de desarrollo, preproducción y producción con un solo comando desde Ubuntu WSL limpio.

[![Versión](https://img.shields.io/badge/Versión-3.0.0-blue)](https://github.com/andres20980/gh-gitops-infra/releases)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-Última-00D4AA?logo=argo&logoColor=white)](https://argoproj.github.io/cd/)
[![Minikube](https://img.shields.io/badge/Minikube-Compatible-FF6D01?logo=kubernetes&logoColor=white)](https://minikube.sigs.k8s.io/)
[![Licencia](https://img.shields.io/badge/Licencia-MIT-green)](LICENSE)
[![Español](https://img.shields.io/badge/Idioma-Español🇪🇸-red)](README.md)

## 📋 Tabla de Contenidos

- [� Características Principales](#-características-principales)
- [⚡ Instalación Súper Simple](#-instalación-súper-simple)
- [� Instalación por Fases](#-instalación-por-fases)
- [�🏗️ Arquitectura del Sistema](#️-arquitectura-del-sistema)
- [🔧 Componentes Incluidos](#-componentes-incluidos)
- [📊 Monitorización y Observabilidad](#-monitorización-y-observabilidad)
- [🌍 Entornos Multi-Cluster](#-entornos-multi-cluster)
- [📖 Documentación](#-documentación)
- [🤝 Contribuir](#-contribuir)
- [📄 Licencia](#-licencia)

## 🎯 Características Principales

### ✨ **Proceso Totalmente Desatendido**
- **Un solo comando**: `./instalar.sh` y listo
- **Desde Ubuntu WSL limpio**: Verifica/instala todas las dependencias automáticamente
- **Sin interacción humana**: Proceso completamente autónomo
- **Compatible con versiones**: Instala las últimas versiones compatibles

### 🎯 **Instalación Flexible por Fases**
- **Fases individuales**: `./instalar.sh fase-03` para testing específico
- **Rangos de fases**: `./instalar.sh fase-01-04` para procesos parciales
- **Debug granular**: Logging y dry-run por fase individual
- **Desarrollo ágil**: Iteración rápida en componentes específicos

### �️ **Arquitectura Hipermodular v3.0.0**
- **Scripts organizados**: Estructura modular en español con 7 fases especializadas
- **Funciones especializadas**: Cada módulo tiene una responsabilidad específica
- **Código mantenible**: Fácil de entender, modificar y extender
- **Estándares de calidad**: Siguiendo mejores prácticas de Shell scripting modular

### 🔄 **GitOps Nativo Completo**
- **ArgoCD maestro**: Controla los 3 clusters desde gitops-dev
- **App-of-Apps por fases**: Despliegue ordenado y controlado
- **Promoción automática**: Kargo gestiona dev → pre → pro
- **Estado declarativo**: Todo el sistema definido como código

### 🛡️ **Seguridad y Calidad Empresarial**
- **Certificados automáticos**: Cert-Manager con Let's Encrypt
- **Secretos seguros**: External-Secrets con integración completa
- **Observabilidad total**: Prometheus, Grafana, Loki, Jaeger
- **Alta disponibilidad**: Configuración lista para producción

## ⚡ Instalación Súper Simple

### 🚀 **Proceso Autónomo (Recomendado)**

```bash
# 1. Clonar el repositorio
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra

# 2. Ejecutar instalación completa (proceso desatendido)
./instalar.sh
```

**¡Eso es todo!** El script se encarga de:
1. ✅ Verificar/actualizar dependencias del sistema
2. ✅ Instalar minikube + cluster gitops-dev (capacidad completa)
3. ✅ Instalar ArgoCD (última versión)
4. ✅ Actualizar helm-charts y desplegar herramientas GitOps
5. ✅ Verificar que todo esté synced y healthy
6. ✅ Desplegar aplicaciones custom
7. ✅ Crear clusters gitops-pre y gitops-pro
8. ✅ Configurar promoción de entornos con Kargo

### 🔧 **Opciones Avanzadas**

```bash
# Ver todo el proceso sin ejecutar
./instalar.sh --dry-run

# Solo crear cluster de desarrollo (para testing)
./instalar.sh --solo-dev

# Con salida detallada para debugging
./instalar.sh --verbose

# Debug completo con log
./instalar.sh --debug --log-file debug.log
```

## 🎯 Instalación por Fases

### 🎪 **Ejecución de Fases Individuales**

La arquitectura modular v3.0.0 permite ejecutar fases específicas para desarrollo, testing y debugging granular:

```bash
# Fases individuales (ideal para desarrollo)
./instalar.sh fase-01            # Solo gestión de permisos
./instalar.sh fase-02            # Solo dependencias del sistema
./instalar.sh fase-03            # Solo Docker + clusters
./instalar.sh fase-04            # Solo ArgoCD
./instalar.sh fase-05            # Solo herramientas GitOps
./instalar.sh fase-06            # Solo aplicaciones custom
./instalar.sh fase-07            # Solo finalización + accesos

# Rangos de fases (ideal para testing parcial)
./instalar.sh fase-01-03         # Infraestructura base (permisos → clusters)
./instalar.sh fase-04-07         # Plataforma GitOps (ArgoCD → finalización)
```

### 🔍 **Debugging por Fases**

```bash
# Testing específico con dry-run
./instalar.sh fase-03 --dry-run --verbose

# Debug completo de una fase
./instalar.sh fase-05 --debug --log-file herramientas-debug.log

# Rango con logging personalizado
./instalar.sh fase-01-04 --verbose --log-file infraestructura.log
```

### 📋 **Arquitectura de Fases**

| Fase | Descripción | Scripts | Funciones Principales |
|------|-------------|---------|----------------------|
| **01** | Gestión de Permisos | `fase-01-permisos.sh` | Auto-escalation/de-escalation inteligente |
| **02** | Dependencias | `fase-02-dependencias.sh` | Verificación/instalación de herramientas |
| **03** | Docker + Clusters | `fase-03-clusters.sh` | Configuración Docker, creación gitops-dev |
| **04** | ArgoCD | `fase-04-argocd.sh` | Instalación y configuración ArgoCD maestro |
| **05** | Herramientas GitOps | `fase-05-herramientas.sh` | Despliegue Prometheus, Grafana, etc. |
| **06** | Aplicaciones Custom | `fase-06-aplicaciones.sh` | Apps de demostración y ejemplos |
| **07** | Finalización | `fase-07-finalizacion.sh` | Clusters promoción, información accesos |

## 🏗️ Arquitectura del Sistema

### 📁 **Estructura del Repositorio**

```
📁 gh-gitops-infra/
├── 🚀 instalar.sh                    # ← Punto de entrada único
├── 📄 README.md                      # Esta documentación
├── 📄 LICENSE                        # Licencia MIT
│
├── 📁 scripts/                       # Módulos especializados
│   ├── 📁 comun/                     # Funciones base compartidas
│   ├── 📁 instalacion/               # Instaladores de dependencias
│   ├── 📁 cluster/                   # Gestión de clusters Kubernetes
│   └── 📄 orquestador.sh             # Coordinador principal
│
├── 📁 herramientas-gitops/           # Manifiestos GitOps
│   ├── 📄 app-of-apps.yaml          # Aplicación principal ArgoCD
│   ├── 📄 argo-rollouts.yaml        # Despliegues progresivos
│   ├── 📄 cert-manager.yaml         # Gestión de certificados
│   ├── 📄 external-secrets.yaml     # Gestión de secretos
│   ├── 📄 grafana.yaml              # Dashboard de monitorización
│   ├── 📄 ingress-nginx.yaml        # Controlador de ingress
│   ├── 📄 jaeger.yaml               # Trazabilidad distribuida
│   ├── 📄 kargo.yaml                # Promoción de entornos
│   ├── 📄 loki.yaml                 # Agregación de logs
│   ├── 📄 minio.yaml                # Almacenamiento S3-compatible
│   ├── 📄 prometheus-stack.yaml     # Stack de monitorización
│   └── 📄 gitea.yaml                # Git server interno
│
├── 📁 argo-apps/                     # Aplicaciones ArgoCD
│   ├── 📄 app-of-apps.yaml          # Orquestador de aplicaciones
│   ├── � herramientas-gitops.yaml  # Referencia a herramientas
│   └── 📄 aplicaciones-custom.yaml  # Aplicaciones de usuario
│
├── 📁 aplicaciones/                  # Ejemplos de aplicaciones
│   ├── 📄 appset-aplicaciones.yaml  # ApplicationSet principal
│   ├── 📁 demo-project/             # Proyecto de demostración
│   └── 📁 simple-app/               # Aplicación simple de ejemplo
│
└── 📁 docs/                          # Documentación técnica
    ├── 📄 ARQUITECTURA_HIPERMODULAR.md
    ├── 📄 GUIA-INSTALACION.md
    ├── 📄 CONTRIBUTING.md
    └── 📄 CHANGELOG.md
```
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

### 🌐 **Flujo Multi-Cluster**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   gitops-dev    │    │   gitops-pre    │    │   gitops-pro    │
│                 │    │                 │    │                 │
│ • ArgoCD Maestro│───▶│ • Apps Mínimas  │───▶│ • Apps Mínimas  │
│ • Todas las     │    │ • Solo Runtime  │    │ • Solo Runtime  │
│   herramientas  │    │ • Promoción     │    │ • Producción    │
│ • Desarrollo    │    │   automática    │    │   estable       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────── Kargo Promotion ────────────────────┘
```

## 🔧 Componentes Incluidos

### 🔄 **Stack GitOps**
- **ArgoCD**: Gestión declarativa de aplicaciones
- **Kargo**: Promoción automatizada entre entornos
- **Argo Workflows**: Pipeline CI/CD avanzados
- **Argo Rollouts**: Despliegues progresivos (Blue/Green, Canary)
- **Argo Events**: Sistema de eventos y triggers

### 🛡️ **Seguridad y Certificados**
- **Cert-Manager**: Gestión automática de certificados SSL/TLS
- **External-Secrets**: Integración segura con gestores de secretos
- **Ingress-NGINX**: Controlador de ingress con TLS automático
- **RBAC**: Control de acceso basado en roles

### 📊 Monitorización y Observabilidad

#### 📈 **Métricas y Alertas**
- **Prometheus**: Recolección y almacenamiento de métricas
- **Grafana**: Dashboards interactivos y alertas visuales
- **AlertManager**: Gestión inteligente de alertas

#### 📋 **Logs y Trazabilidad**
- **Loki**: Agregación y consulta de logs
- **Jaeger**: Trazabilidad distribuida de microservicios
- **Promtail**: Agente de recolección de logs

### 🗄️ **Almacenamiento y Persistencia**
- **MinIO**: Almacenamiento S3-compatible para artifacts
- **Storage Classes**: Clases de almacenamiento optimizadas
- **Backup automático**: Respaldo de configuraciones críticas

### 🔧 **Herramientas de Desarrollo**
- **Gitea**: Servidor Git interno para el ciclo completo
- **Registry interno**: Registro de imágenes Docker privado
- **Webhooks**: Integración con eventos Git

## 📊 Monitorización y Observabilidad

### 🎯 **Dashboards Incluidos**

| Dashboard | Descripción | Acceso |
|-----------|-------------|--------|
| **Cluster Overview** | Estado general del cluster | Grafana → Dashboards |
| **ArgoCD Metrics** | Métricas de GitOps | Grafana → ArgoCD |
| **Application Health** | Salud de aplicaciones | ArgoCD UI |
| **Resource Usage** | Uso de CPU/Memory/Disk | Grafana → Infrastructure |
| **Network Traffic** | Tráfico de red y latencia | Grafana → Network |
| **Jaeger Traces** | Trazas de microservicios | Jaeger UI |

### 🚨 **Alertas Preconfiguradas**
- CPU/Memory elevado en nodos
- Aplicaciones en estado unhealthy
- Certificados SSL próximos a expirar
- Fallos en sincronización de ArgoCD
- Espacio en disco bajo

## 🌍 Entornos Multi-Cluster

### 🏗️ **Arquitectura de Clusters**

```bash
# Cluster de desarrollo (gitops-dev)
• Capacidad: 4 CPUs, 8GB RAM, 40GB disk
• Propósito: Desarrollo activo, todas las herramientas
• ArgoCD: Maestro que controla todos los clusters
• Estado: Siempre activo

# Cluster de preproducción (gitops-pre)  
• Capacidad: 2 CPUs, 4GB RAM, 20GB disk
• Propósito: Testing y validación
• Aplicaciones: Solo las promovidas desde dev
• Estado: Bajo demanda

# Cluster de producción (gitops-pro)
• Capacidad: 2 CPUs, 4GB RAM, 20GB disk  
• Propósito: Producción estable
• Aplicaciones: Solo las validadas en pre
• Estado: Alta disponibilidad
```

### 🔄 **Promoción Automática con Kargo**

```yaml
# Flujo de promoción automática
dev → pre → pro

# Criterios de promoción:
✅ Tests pasados
✅ Aplicación healthy
✅ Sin alertas críticas
✅ Aprobación manual (pro)
```

## 📖 Documentación

### 📚 **Documentos Técnicos**
- [`ARQUITECTURA_HIPERMODULAR.md`](docs/ARQUITECTURA_HIPERMODULAR.md) - Diseño técnico detallado
- [`GUIA-INSTALACION.md`](docs/GUIA-INSTALACION.md) - Guía paso a paso
- [`CONTRIBUTING.md`](docs/CONTRIBUTING.md) - Cómo contribuir al proyecto
- [`CHANGELOG.md`](docs/CHANGELOG.md) - Historial de cambios

### 🎓 **Tutoriales y Ejemplos**
- Configuración de aplicaciones custom
- Integración con CI/CD externos
- Gestión de secretos y certificados
- Troubleshooting común

### 🔧 **Scripts de Utilidad**

```bash
# Verificar estado del sistema
./scripts/utilidades/verificar-sistema.sh

# Backup de configuraciones
./scripts/utilidades/backup-configs.sh

# Monitorizar recursos
./scripts/utilidades/monitor-recursos.sh

# Limpiar recursos obsoletos
./scripts/utilidades/limpiar-recursos.sh
```

## 🚀 Inicio Rápido

### ⚡ **Instalación Express (1 comando)**

```bash
curl -fsSL https://raw.githubusercontent.com/andres20980/gh-gitops-infra/main/instalacion-rapida.sh | bash
```

### 🔧 **Verificación Post-Instalación**

```bash
# Verificar que todos los componentes están healthy
kubectl get applications -n argocd

# Verificar métricas
kubectl top nodes
kubectl top pods -A

# Acceder a ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acceder a Grafana  
kubectl port-forward svc/grafana -n monitoring 3000:80
```

### 🎯 **Primeros Pasos**

1. **Explorar ArgoCD**: Navega por las aplicaciones desplegadas
2. **Revisar Grafana**: Examina los dashboards de monitorización
3. **Desplegar tu primera app**: Usa los ejemplos en `aplicaciones/`
4. **Configurar promoción**: Configura el flujo dev → pre → pro

## 🤝 Contribuir

### 🔧 **Desarrollo Local**

```bash
# Fork y clone del repositorio
git clone https://github.com/tu-usuario/gh-gitops-infra.git
cd gh-gitops-infra

# Crear rama para nueva feature
git checkout -b feature/mi-nueva-funcionalidad

# Realizar cambios y pruebas
./instalar.sh --dry-run

# Commit y push
git add .
git commit -m "feat: añadir nueva funcionalidad"
git push origin feature/mi-nueva-funcionalidad
```

### 📋 **Guías de Contribución**
- Seguir [Conventional Commits](https://www.conventionalcommits.org/)
- Documentar cambios en español
- Añadir tests para nuevas funcionalidades
- Respetar la arquitectura hipermodular

### 🐛 **Reportar Issues**
- Usar las plantillas de issue
- Incluir logs y versiones
- Describir pasos para reproducir
- Etiquetar correctamente

## 🆘 Soporte y Troubleshooting

### 🔍 **Comandos de Diagnóstico**

```bash
# Estado general del sistema
kubectl get all -A

# Logs de ArgoCD
kubectl logs -n argocd deployment/argocd-server

# Estado de aplicaciones
argocd app list

# Métricas de recursos
kubectl top nodes
kubectl top pods -A

# Verificar conectividad
kubectl get endpoints -A
```

### 🚨 **Problemas Comunes**

| Problema | Solución |
|----------|----------|
| ArgoCD no sincroniza | Verificar conexión Git y permisos |
| Pods en CrashLoopBackOff | Revisar logs y recursos asignados |
| Certificados no válidos | Verificar Cert-Manager y DNS |
| Alta latencia | Revisar límites de recursos |

### 📞 **Canales de Soporte**
- **Issues GitHub**: Problemas técnicos y bugs
- **Discussions**: Preguntas generales y ideas
- **Wiki**: Documentación colaborativa

## 📄 Licencia

Este proyecto está licenciado bajo la **Licencia MIT**. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 🏆 Reconocimientos

### 🙏 **Tecnologías Utilizadas**
- [Kubernetes](https://kubernetes.io/) - Orquestación de contenedores
- [ArgoCD](https://argoproj.github.io/cd/) - GitOps y CD
- [Prometheus](https://prometheus.io/) - Monitorización
- [Grafana](https://grafana.com/) - Visualización
- [Minikube](https://minikube.sigs.k8s.io/) - Cluster local

### 👥 **Contribuidores**
- [@andres20980](https://github.com/andres20980) - Autor principal y mantenedor

### 🌟 **Inspiración**
Este proyecto está inspirado en las mejores prácticas de la comunidad GitOps y la filosofía de "Infrastructure as Code" aplicada a entornos educativos y empresariales en español.

---

<div align="center">

**🚀 ¡Construido con ❤️ para la comunidad GitOps en español! 🇪🇸**

[![GitHub stars](https://img.shields.io/github/stars/andres20980/gh-gitops-infra?style=social)](https://github.com/andres20980/gh-gitops-infra/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/andres20980/gh-gitops-infra?style=social)](https://github.com/andres20980/gh-gitops-infra/network/members)
[![GitHub issues](https://img.shields.io/github/issues/andres20980/gh-gitops-infra)](https://github.com/andres20980/gh-gitops-infra/issues)

[⬆️ Volver al inicio](#-infraestructura-gitops-españa)

</div>
