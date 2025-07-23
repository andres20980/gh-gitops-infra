# 🍴 Fork Setup Guide

¡Gracias por hacer fork de este proyecto GitOps! Esta guía te ayudará a configurar tu propio entorno multi-cluster.

## � Requisitos del Sistema

**Mínimos para PoC Local:**
- 🖥️ **CPU**: 8+ cores (recomendado)
- 🧠 **RAM**: 16GB+ (mínimo 12GB disponible)
- 💾 **Disk**: 60GB+ espacio libre
- 🐳 **Docker**: Instalado y ejecutándose
- ☸️ **Minikube**: v1.25+ instalado

## �🚀 Configuración Rápida

### 1. Clona tu fork
```bash
git clone https://github.com/TU_USUARIO/gh-gitops-infra.git
cd gh-gitops-infra
```

### 2. Ejecuta la configuración automática
```bash
./setup-config.sh --auto
```

### 3. Revisa la configuración generada
```bash
cat config/environment.conf
```

### 4. Despliega tu entorno multi-cluster
```bash
./bootstrap-multi-cluster.sh
```

## 🔧 Configuración Personalizada

Si quieres personalizar completamente tu entorno:

```bash
./setup-config.sh --interactive
```

Esto te guiará paso a paso para configurar:
- Tu repositorio GitHub
- Recursos de hardware (CPU/RAM por cluster)
- Componentes a instalar (Grafana, Jaeger, MinIO, etc.)
- Puertos y configuraciones de red
- Credenciales y configuraciones de seguridad

## 📝 Variables Principales que Debes Cambiar

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `GITHUB_REPO_URL` | URL de tu repositorio fork | `https://github.com/TU_USUARIO/gh-gitops-infra.git` |
| `GITHUB_USERNAME` | Tu usuario de GitHub | `TU_USUARIO` |
| `ORGANIZATION_NAME` | Nombre de tu organización | `TU_USUARIO` |

## 🏢 Arquitectura Resultante

Después de la configuración tendrás:

```
🏢 Tu Organización GitOps (Optimizado para PoC Local)
├── 🚧 DEV Cluster (gitops-dev)   - Puerto 8080 (2 CPUs, 4GB RAM, 20GB disk)
├── 🧪 PRE Cluster (gitops-pre)   - Puerto 8081 (2 CPUs, 3GB RAM, 15GB disk)
└── 🏭 PROD Cluster (gitops-prod) - Puerto 8082 (2 CPUs, 4GB RAM, 20GB disk)
```

**💡 Recursos Totales Requeridos**: ~6 CPUs, ~11GB RAM, ~55GB disk

## 🎯 Flujo de Promociones

1. **DEV**: Despliegue automático desde rama `main`
2. **PRE**: Promoción manual desde DEV usando Kargo
3. **PROD**: Promoción manual desde PRE usando Kargo

## 🛠️ Comandos Útiles

```bash
# Ver configuración actual
./setup-config.sh --show

# Reconfigurar entorno
./setup-config.sh --interactive

# Estado de clusters
./scripts/cluster-status.sh

# Limpiar entorno
./cleanup-multi-cluster.sh soft
```

## 🔐 Seguridad

⚠️ **IMPORTANTE**: Antes de usar en producción:

1. Cambia las contraseñas por defecto en `config/environment.conf`
2. Revisa las configuraciones de red y puertos
3. Habilita solo los componentes que necesites

## 🆘 Resolución de Problemas

### Error: "Repository not found"
- Verifica que `GITHUB_REPO_URL` apunte a tu fork
- Asegúrate de que el repositorio sea público o tengas acceso

### Error: "Insufficient resources"
- **Recomendado**: Ajusta los recursos en `config/environment.conf`
- **CPU**: Reduce a 1 CPU por cluster si tienes <8 cores totales
- **RAM**: Reduce DEV/PROD a 3g y PRE a 2g si tienes <16GB RAM
- **Disk**: Reduce a 10g por cluster si tienes poco espacio

### Rendimiento lento
- Cierra aplicaciones innecesarias antes del despliegue
- Considera desactivar componentes: `ENABLE_GRAFANA="false"`
- Reduce el número de clusters: comienza solo con DEV

### Puertos ocupados
- Cambia los puertos en la sección `NETWORKING` del config
- Verifica que no haya conflictos con otros servicios

## 📞 Soporte

Si tienes problemas:
1. Revisa los logs: `./scripts/cluster-status.sh`
2. Verifica la configuración: `./setup-config.sh --show`
3. Consulta el README principal para más detalles

¡Disfruta tu entorno GitOps multi-cluster! 🎉
