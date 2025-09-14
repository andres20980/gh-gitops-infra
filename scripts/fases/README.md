# Arquitectura Modular del Instalador GitOps

## 🏗️ Nueva Estructura (Versión 3.0.0)

El instalador ha sido completamente refactorizado en una arquitectura modular por fases para mejorar la mantenibilidad, claridad y escalabilidad.

# Fases del instalador

Este directorio contiene las fases canónicas del instalador. Los scripts
guardados en `scripts/fases/obsolete/` son copias históricas o duplicadas y no
participan en la ejecución normal.

Fases activas (canónicas):

- `00-reset.sh`         : Reset inicial del entorno
- `01-permisos.sh`      : Gestión de permisos y verificaciones
- `02-dependencias.sh`  : Instalación de dependencias (helm, kubectl, etc.)
- `03-clusters.sh`      : Creación/configuración de clusters
- `04-argocd.sh`        : Instalación y verificación de ArgoCD
- `05-aplicaciones.sh`  : Despliegue de aplicaciones y ApplicationSets
- `06-finalizacion.sh`  : Mensajes finales, accesos y instrucciones

Obsoletos/archivados:

- Cualquier archivo bajo `scripts/fases/obsolete/` contiene versiones
  históricas o duplicadas que fueron movidas para mantener el árbol limpio.

Uso:

Ejecuta el instalador modular con: `./instalar.sh` y selecciona fases por
nombre si necesitas ejecutar pasos parciales.
