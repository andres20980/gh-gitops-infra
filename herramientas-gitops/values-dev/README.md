# Valores de Desarrollo GitOps

Este directorio contiene las configuraciones optimizadas para el entorno de desarrollo de todas las herramientas GitOps.

## 🎯 Propósito

Los archivos en este directorio definen configuraciones **mínimas y optimizadas** para desarrollo que son:

- ✅ **Persistentes**: Almacenadas en Git, no en `/tmp`
- ✅ **Reproducibles**: Cualquier desarrollador tendrá la misma configuración
- ✅ **Versionadas**: Cambios controlados via Git
- ✅ **Accesibles por ArgoCD**: Desde el repositorio Git

## 📁 Estructura

```
values-dev/
├── README.md                          # Este archivo
├── grafana-dev-values.yaml           # Configuración optimizada Grafana
├── prometheus-stack-dev-values.yaml  # Configuración optimizada Prometheus
├── loki-dev-values.yaml             # Configuración optimizada Loki
├── jaeger-dev-values.yaml           # Configuración optimizada Jaeger
├── ...                              # Otros archivos de herramientas
```

## 🔧 Cómo Funciona

1. **Autodescubrimiento**: El script `gitops-helper.sh` descubre automáticamente las herramientas
2. **Generación de valores**: Crea archivos `*-dev-values.yaml` optimizados para desarrollo
3. **Referencia en YAMLs**: Los archivos principales referencian estos valores via `valueFiles`
4. **Commit automático**: Los cambios se commitean y pushean al repositorio
5. **Lectura por ArgoCD**: ArgoCD lee estos valores desde el repositorio Git

## 📋 Ejemplo de Uso

En `herramientas-gitops/grafana.yaml`:

```yaml
spec:
  source:
    repoURL: https://grafana.github.io/helm-charts
    chart: grafana
    targetRevision: "9.3.1"
    helm:
      valueFiles:
        - values-dev/grafana-dev-values.yaml  # ← Referencia a valores dev
      values: |
        # Configuración específica del cluster
        ...
```

## 🎯 Características de los Valores Dev

- **Recursos mínimos**: CPU/memoria optimizados para desarrollo
- **Credenciales simples**: `admin/admin123` para facilitar pruebas
- **Persistencia básica**: Tamaños pequeños (1-2Gi)
- **Sin autenticación compleja**: Acceso simplificado para desarrollo
- **Monitoreo deshabilitado**: Reduce overhead en entorno dev

## 🔄 Actualización Automática

Los valores se actualizan automáticamente cuando se ejecuta:

```bash
bash scripts/fases/fase-05-herramientas.sh
```

El sistema:
1. Descubre herramientas automáticamente
2. Busca versiones más recientes
3. Genera valores optimizados para desarrollo
4. Commitea y pushea cambios
5. Aplica la configuración via ArgoCD

## 🌐 Multi-Cluster

Esta estructura permite fácilmente crear valores para otros entornos:

```
values-dev/     # Desarrollo
values-pre/     # Pre-producción  
values-pro/     # Producción
```

Cada entorno puede tener configuraciones específicas manteniendo la misma estructura base.
