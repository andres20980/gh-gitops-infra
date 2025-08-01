# Historial de Cambios

Todos los cambios notables de este proyecto se documentarán en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto se adhiere al [Versionado Semántico](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2025-08-01

### Añadido
- **🎯 bootstrap.sh** - Único script principal con arquitectura modular perfecta
- **📚 Librerías compartidas** - `scripts/lib/` con common.sh, logging.sh, validation.sh
- **🔍 Validación granular** - `scripts/validate-prerequisites.sh`
- **📦 Instalación selectiva** - `--components="argocd,kargo"`
- **🧪 Modo dry-run** - `--dry-run` para testing sin instalación
- **📋 Ayuda completa** - `--help` con documentación detallada

### Cambiado
- **🏗️ Arquitectura completamente modular** - Separación clara de responsabilidades
- **📖 Documentación simplificada** - Un solo punto de entrada: bootstrap.sh
- **� Experiencia de usuario optimizada** - Sin confusión, máxima claridad

### Eliminado
- **🗑️ instalar-todo.sh** - Eliminado completamente (limpieza radical)
- **🧹 Código legacy** - Sin duplicación, arquitectura limpia desde cero

### Beneficios de la Arquitectura Modular
- ✅ **Un solo punto de entrada**: bootstrap.sh
- ✅ **Modular**: Cada componente en su propio módulo
- ✅ **Testeable**: Validación granular por componente
- ✅ **Flexible**: Instalación selectiva, dry-run, validación independiente
- ✅ **Mantenible**: Código limpio, organizado y sin duplicación
- ✅ **CI/CD Ready**: Compatible con pipelines automatizados
- ✅ **Futuro-proof**: Arquitectura moderna que escala

## [2.1.0] - 2025-08-01

### Añadido
- **KARGO v1.6.2** - Automatización completa de promociones GitOps (SUPER IMPORTANTE)
- Configuración oficial con repositorio Git para Kargo (evitando problemas con registry OCI)
- Configuración completa optimizada para desarrollo en los 14 componentes
- Gestión mejorada de errores y documentación de resolución de problemas

### Cambiado
- **BREAKING**: Kargo ahora usa repositorio Git en lugar de registry OCI
- Actualizados todos los componentes a las versiones estables más recientes (Agosto 2025)
- Mejorado README.md con mejor organización y resolución de problemas
- Mejorado STATUS.md con verificación completa de despliegues

### Corregido
- **CRÍTICO**: Resuelto ComparisonError de Kargo con registry OCI
- Nomenclatura de parámetros de cuenta admin de Kargo (`api.adminAccount.*` en lugar de `admin.*`)
- Namespace de Kargo cambiado a `kargo-system` para consistencia
- Estado OutOfSync de Grafana resuelto
- Todas las 14/14 aplicaciones ahora Synced+Healthy

### Detalles Técnicos
- Configuración Kargo: `https://github.com/akuity/kargo.git` + ruta `charts/kargo`
- Credenciales admin: `admin`/`admin123` (sólo para desarrollo)
- Optimización de recursos: Todos los componentes configurados con límites apropiados para desarrollo
- Integración ArgoCD: Integración completa de controlador con namespace `argocd`

## [2.0.0] - 2025-07-31

### Añadido
- Implementación completa del patrón App of Apps
- 14 componentes GitOps con detección automática de versiones
- Gestión centralizada de aplicaciones via App of Apps único
- Script de instalación mejorado con comandos modulares

### Cambiado
- **BREAKING**: Migración de instalaciones individuales al patrón App of Apps
- Todos los componentes ahora gestionados por Aplicaciones ArgoCD
- Proceso de despliegue unificado a través de `app-of-apps-gitops.yaml`

### Eliminado
- Métodos de instalación de componentes individuales
- Despliegues manuales de charts Helm

## [1.5.0] - 2025-07-30

### Added
- Automatic version detection for all components
- Enhanced diagnostic and management scripts
- Port-forwarding automation for all web UIs
- Multi-cluster support (DEV/PRE/PRO)

### Changed
- Improved installation script reliability
- Better error handling and recovery
- Enhanced logging and output formatting

## [1.4.0] - 2025-07-29

### Added
- Argo Events v2.4.8 for event-driven automation
- Argo Workflows v0.45.21 for workflow orchestration
- Argo Rollouts v2.40.2 for progressive delivery
- Complete observability stack integration

### Changed
- Unified component versions across the stack
- Improved resource allocation for development environments

## [1.3.0] - 2025-07-28

### Added
- MinIO v5.2.0 for S3-compatible object storage
- Gitea v12.1.2 for internal Git repository management
- External Secrets v0.18.2 for secure secrets management
- Cert-Manager v1.18.2 for automatic TLS certificates

### Changed
- Enhanced security configuration across all components
- Improved integration between observability tools

## [1.2.0] - 2025-07-27

### Added
- Grafana v9.3.0 with pre-configured dashboards
- Loki v6.8.0 for centralized logging
- Jaeger v3.4.1 for distributed tracing
- Complete observability stack integration

### Changed
- Improved Prometheus configuration with better targets
- Enhanced Grafana dashboard organization

## [1.1.0] - 2025-07-26

### Added
- Prometheus Stack v75.15.1 for metrics collection
- NGINX Ingress v4.13.0 for load balancing
- Enhanced monitoring capabilities

### Changed
- Improved ArgoCD configuration for better performance
- Better resource management for development environments

## [1.0.0] - 2025-07-25

### Added
- Initial release with ArgoCD v3.0.12
- Complete GitOps infrastructure setup
- Automated installation script (`instalar-todo.sh`)
- Basic component structure
- Development environment support

### Features
- Single-command installation
- Multi-cluster architecture support
- Automatic dependency management
- Port-forwarding automation
- Basic troubleshooting tools

---

## Release Notes Format

### Version Numbering
- **Major (X.0.0)**: Breaking changes, architecture changes
- **Minor (X.Y.0)**: New features, component additions
- **Patch (X.Y.Z)**: Bug fixes, minor improvements

### Change Categories
- **Added**: New features, components, or capabilities
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements
