# 🚀 GitOps España - Infraestructura Completa

[![Estado del Pipeline](https://img.shields.io/badge/pipeline-passing-green)](./CHANGELOG.md)
[![Licencia](https://img.shields.io/badge/licencia-MIT-blue.svg)](./LICENSE)
[![Español](https://img.shields.io/badge/idioma-español-red.svg)](./README.md)

## 📋 Descripción

**Bootstrap GitOps España** es una solución completa para desplegar infraestructura GitOps moderna con **14 componentes integrados**. Implementa las mejores prácticas de DevOps con arquitectura modular, completamente localizada en castellano español.

### 🎯 Características Principales

- **✨ Arquitectura Modular**: Scripts especializados y librerías reutilizables
- **🇪🇸 100% en Castellano**: Nomenclatura, interfaz y documentación nativa
- **🔧 Instalación Automatizada**: Bootstrap inteligente con detección de dependencias  
- **📊 Monitorización Completa**: Prometheus + Grafana + Loki + Jaeger
- **🔄 GitOps Nativo**: ArgoCD + Kargo para promociones automáticas
- **🛡️ Seguridad Integrada**: Cert-Manager + External Secrets + RBAC
- **🎮 Modo Interactivo**: Configuración guiada paso a paso
- **🔍 Validación Automatizada**: Diagnósticos pre y post instalación

## 🏗️ Arquitectura

```
bootstrap.sh (orquestador principal)
├── scripts/
│   ├── lib/                    # Librerías compartidas
│   │   ├── comun.sh           # Funciones y variables comunes
│   │   └── registro.sh        # Sistema de logging avanzado
│   ├── modulos/               # Módulos especializados
│   │   ├── argocd.sh         # Instalación ArgoCD
│   │   └── kargo.sh          # Instalación Kargo (SUPER IMPORTANTE)
│   ├── configurar-*.sh       # Scripts de configuración
│   ├── validar-*.sh          # Scripts de validación
│   └── diagnostico-*.sh      # Scripts de diagnóstico
├── componentes/              # Manifiestos de componentes
├── aplicaciones/            # Aplicaciones de ejemplo
└── app-of-apps-gitops.yaml # Configuración principal ArgoCD
```

## 🚀 Inicio Rápido

### Prerequisitos

- **Kubernetes**: v1.28+ (minikube, kind, k3s, AKS, EKS, GKE)
- **kubectl**: configurado y conectado al cluster
- **helm**: v3.12+
- **git**: para clonación del repositorio
- **bash**: v4.0+ (Linux/macOS/WSL)

### Instalación Básica

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/gh-gitops-infra.git
cd gh-gitops-infra

# 2. Instalación completa (14 componentes)
./bootstrap.sh

# 3. Solo componentes críticos (ArgoCD + Kargo)
./bootstrap.sh --solo-criticos

# 4. Instalación interactiva
./bootstrap.sh --interactivo
```

### Ejemplos de Uso Avanzado

```bash
# Validar prerequisitos sin instalar
./bootstrap.sh --validar

# Instalación específica de componentes
./bootstrap.sh --componentes="argocd,kargo,grafana"

# Modo dry-run (simular sin cambios)
./bootstrap.sh --dry-run --componentes="argocd,kargo"

# Configuración de producción
./bootstrap.sh --entorno-produccion --crear-clusters-adicionales

# Debug con logging verbose
./bootstrap.sh --debug --componentes="argocd"
```

## 📦 Componentes Incluidos

| Componente | Versión | Descripción | Crítico |
|------------|---------|-------------|---------|
| **ArgoCD** | v3.0.12 | GitOps Core - Gestión declarativa | ✅ |
| **Kargo** | v1.6.2 | **SUPER IMPORTANTE** - Promociones automáticas | ✅ |
| Prometheus Stack | v75.15.1 | Métricas y alertas | ⚠️ |
| Grafana | v9.3.0 | Dashboards y visualización | ⚠️ |
| Loki | v6.8.0 | Agregación de logs | ⚠️ |
| Jaeger | v3.4.1 | Tracing distribuido | ⚠️ |
| Argo Events | v2.4.8 | Gestión de eventos | ⚠️ |
| Argo Workflows | v0.45.21 | Orquestación de workflows | ⚠️ |
| Argo Rollouts | v2.40.2 | Progressive delivery | ⚠️ |
| NGINX Ingress | v4.13.0 | Load balancer HTTP/HTTPS | ⚠️ |
| Cert-Manager | v1.18.2 | Gestión automática certificados TLS | ⚠️ |
| External Secrets | v0.18.2 | Integración con gestores de secretos | ⚠️ |
| MinIO | v5.2.0 | Object storage compatible S3 | ⚠️ |
| Gitea | v12.1.2 | Repositorio Git auto-hospedado | ⚠️ |

**Leyenda**: ✅ Crítico (requerido) | ⚠️ Opcional (recomendado)

## 🌐 Acceso a Interfaces Web

Después de la instalación, configura port-forwards:

```bash
# Configurar todos los accesos web automáticamente
./scripts/configurar-port-forwards.sh

# O manualmente:
kubectl port-forward -n argocd svc/argocd-server 8080:80 &
kubectl port-forward -n kargo-system svc/kargo-api 8081:80 &
kubectl port-forward -n monitoring svc/grafana 3000:80 &
```

### URLs de Acceso

- **🎯 ArgoCD**: http://localhost:8080 (admin/admin123)
- **🚀 Kargo**: http://localhost:8081 (admin/admin123) - **SUPER IMPORTANTE**
- **📊 Grafana**: http://localhost:3000 (admin/admin123)
- **📈 Prometheus**: http://localhost:9090
- **🔍 Jaeger**: http://localhost:16686

## ⚙️ Variables de Entorno

| Variable | Valores | Default | Descripción |
|----------|---------|---------|-------------|
| `MODO_DESATENDIDO` | true/false | true | Instalación sin prompts interactivos |
| `CREAR_CLUSTERS_ADICIONALES` | true/false | false | Crear clusters PRE y PRO |
| `ENTORNO_DESARROLLO` | true/false | true | Optimizaciones para desarrollo |
| `SOLO_VALIDAR` | true/false | false | Solo validar sin instalar |
| `DRY_RUN` | true/false | false | Simular sin hacer cambios |
| `KUBECONFIG` | path | ~/.kube/config | Ruta al archivo kubeconfig |

## 🔧 Scripts Disponibles

### Scripts Principales

- **`bootstrap.sh`**: Orquestador principal modular
- **`scripts/configurar-port-forwards.sh`**: Configurar accesos web
- **`scripts/validar-prerequisitos.sh`**: Validar requerimientos
- **`scripts/diagnostico-gitops.sh`**: Diagnóstico completo del sistema

### Módulos Especializados

- **`scripts/modulos/argocd.sh`**: Gestión completa de ArgoCD
- **`scripts/modulos/kargo.sh`**: Gestión completa de Kargo

### Librerías Compartidas

- **`scripts/lib/comun.sh`**: Funciones y variables comunes
- **`scripts/lib/registro.sh`**: Sistema de logging profesional

## 🛠️ Gestión de Componentes

### ArgoCD - GitOps Core

```bash
# Instalar ArgoCD
./scripts/modulos/argocd.sh instalar

# Validar instalación
./scripts/modulos/argocd.sh validar

# Obtener información
./scripts/modulos/argocd.sh info

# Configurar aplicaciones iniciales
./scripts/modulos/argocd.sh configurar-apps
```

### Kargo - Promociones (SUPER IMPORTANTE)

```bash
# Instalar Kargo
./scripts/modulos/kargo.sh instalar

# Validar instalación  
./scripts/modulos/kargo.sh validar

# Crear proyecto ejemplo
./scripts/modulos/kargo.sh ejemplo

# Obtener información
./scripts/modulos/kargo.sh info
```

## 🔍 Diagnóstico y Solución de Problemas

### Comandos de Diagnóstico

```bash
# Diagnóstico completo del sistema
./scripts/diagnostico-gitops.sh

# Verificar logs del bootstrap
tail -f /tmp/bootstrap-gitops.log

# Estado de pods críticos
kubectl get pods -n argocd -n kargo-system

# Verificar aplicaciones ArgoCD
kubectl get applications -n argocd
```

### Problemas Comunes

**❌ Error: kubectl no está instalado**
```bash
# Ubuntu/Debian
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl
```

**❌ Error: No hay conectividad al cluster**
```bash
# Verificar configuración
kubectl cluster-info
kubectl config current-context

# Para minikube
minikube start
```

**❌ ArgoCD no responde**
```bash
# Verificar pods
kubectl get pods -n argocd

# Logs del servidor
kubectl logs -n argocd deployment/argocd-server
```

## 📚 Documentación Adicional

- **[CHANGELOG.md](./CHANGELOG.md)**: Historial de cambios detallado
- **[CONTRIBUTING.md](./CONTRIBUTING.md)**: Guía de contribución
- **[SECURITY.md](./SECURITY.md)**: Políticas de seguridad
- **[ANALISIS_ARQUITECTURA.md](./ANALISIS_ARQUITECTURA.md)**: Análisis técnico profundo

## 🤝 Contribuir

1. **Fork** del repositorio
2. **Crear branch** para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. **Commit** de cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. **Push** al branch (`git push origin feature/nueva-funcionalidad`)
5. **Pull Request** con descripción detallada

### Estándares de Código

- **Bash**: Seguir [ShellCheck](https://shellcheck.net/) recommendations
- **YAML**: Indentación 2 espacios, sin tabs
- **Documentación**: En castellano español
- **Commits**: Formato conventional commits

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver [LICENSE](./LICENSE) para más detalles.

## 🏷️ Etiquetas

`gitops` `argocd` `kargo` `kubernetes` `helm` `prometheus` `grafana` `devops` `español` `infraestructura` `automatización` `monitorización`

---

**⭐ Si este proyecto te ayuda, por favor dale una estrella en GitHub**

**🐛 ¿Encontraste un problema?** [Crear issue](https://github.com/tu-usuario/gh-gitops-infra/issues/new)

**💬 ¿Tienes preguntas?** [Crear discussion](https://github.com/tu-usuario/gh-gitops-infra/discussions/new)
