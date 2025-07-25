# 📊 Estado Actual del Proyecto GitOps Multi-Cluster

**Fecha:** 26 de Julio, 2025  
**Sesión:** Troubleshooting y consolidación de dependencias GitOps  
**Contexto:** Migración de instalar-todo.sh simple a despliegue con dependencias

---

## 🎯 **OBJETIVO DE LA SESIÓN**

Resolver los problemas de **Unknown** y **OutOfSync** en aplicaciones ArgoCD mediante:
1. **Análisis de dependencias** entre herramientas GitOps
2. **Implementación de despliegue secuencial** respetando dependencias
3. **Consolidación en instalar-todo.sh** para futuras instalaciones
4. **Corrección de conflictos** entre ApplicationSets y aplicaciones directas

---

## 📋 **ESTADO ACTUAL**

### ✅ **COMPLETADO**

#### 1. **Reorganización GitOps (Completada)**
- ✅ Manifiestos movidos de `manifiestos/` a `aplicaciones/demo-project/manifests/`
- ✅ Aplicaciones actualizadas para referenciar nuevas rutas
- ✅ Estructura alineada con mejores prácticas GitOps
- ✅ Commit y push realizados

#### 2. **Script de Dependencias (Consolidado)**
- ✅ Creado `scripts/deploy-with-dependencies.sh` con lógica secuencial
- ✅ **Consolidado en instalar-todo.sh** - funciones integradas:
  - `wait_for_app()` - Espera con timeout y health checking
  - `force_sync()` - Refresh Git + auto-sync
  - `sincronizar_aplicaciones()` - Despliegue en 6 fases con dependencias
- ✅ Orden de despliegue definido:
  1. **Base:** cert-manager, ingress-nginx
  2. **Secretos:** external-secrets, monitoring  
  3. **Observabilidad:** loki, grafana, jaeger
  4. **GitOps Avanzado:** argo-rollouts, argo-workflows, argo-events, kargo
  5. **Storage:** minio, gitea
  6. **Complementos:** argocd-notifications, argocd-applicationset

#### 3. **Diagnóstico de Conflictos (En Progreso)**
- ✅ **Problema identificado:** Conflicto entre ApplicationSet y aplicaciones directas
- ✅ **Root Cause encontrado:** ApplicationSet `appset-gitops-infra.yaml` mal configurado
- ✅ **Corrección aplicada:** Agregado `directory.include='*.yaml'` al ApplicationSet
- ✅ ApplicationSet recreado con nueva configuración

---

## 🔍 **PROBLEMA PRINCIPAL IDENTIFICADO**

### **Conflicto ApplicationSet vs Aplicaciones Directas**

**Síntoma:**
```bash
NAME                    SYNC STATUS   HEALTH STATUS
app-demo-project        Synced        Healthy      # ✅ Del ApplicationSet  
demo-project            Unknown       Healthy      # ❌ Duplicada directa
cert-manager            OutOfSync     Healthy      # ❌ Conflicto de fuente
```

**Root Cause:**
- ApplicationSet genera: `app-*` (correctas)
- Aplicaciones directas: `cert-manager`, `demo-project`, etc. (conflictivas)
- **Diff muestra:** ArgoCD espera directorio Git pero manifiesto tiene Helm chart

**Solución Aplicada:**
1. ✅ Corregido `appset-gitops-infra.yaml` con `directory.include='*.yaml'`
2. ✅ ApplicationSet recreado
3. 🔄 **PENDIENTE:** Verificar que aplicaciones se generen correctamente

---

## 📊 **ESTADO DE APLICACIONES (Última verificación)**

| Aplicación | Sync Status | Health Status | Tipo | Notas |
|------------|-------------|---------------|------|-------|
| app-demo-project | Synced | Healthy | ApplicationSet | ✅ Funcionando |
| app-simple-app | Synced | Healthy | ApplicationSet | ✅ Funcionando |
| cert-manager | OutOfSync | Healthy | Directa | ❌ Conflicto fuente |
| demo-project | Unknown | Healthy | Directa | ❌ Duplicada |
| argo-events | OutOfSync | Healthy | ApplicationSet | 🔄 Esperando sync |
| argo-rollouts | OutOfSync | Healthy | ApplicationSet | 🔄 Esperando sync |
| kargo | OutOfSync | Missing | ApplicationSet | ❌ Repo OCI problema |
| monitoring | Synced | Healthy | Directa | ✅ Funcionando |

**Estadísticas:**
- **Total aplicaciones:** ~24
- **Synced+Healthy:** ~5-6 (25-30%)
- **Objetivo para PRE/PRO:** ≥70% funcionando

---

## 🛠️ **FIXES APLICADOS**

### 1. **Kargo OCI Repository (Corregido)**
```yaml
# Antes (problemático)
url: ghcr.io/akuity/kargo-charts

# Después (corregido)  
url: oci://ghcr.io/akuity/kargo-charts/kargo
```

### 2. **Cert-Manager YAML (Corregido)**
- ✅ Eliminada configuración duplicada de `webhook`
- ✅ Consolidados recursos en secciones apropiadas

### 3. **ApplicationSet Infraestructura (Corregido)**
```yaml
# Agregado para leer manifiestos YAML
directory:
  recurse: false
  include: '*.yaml'
```

---

## 🔄 **PRÓXIMOS PASOS (Siguiente Sesión)**

### **Prioridad 1: Resolver Conflictos ApplicationSet**
1. **Verificar** que ApplicationSet genera aplicaciones correctamente tras corrección
2. **Eliminar aplicaciones directas duplicadas:**
   - `cert-manager`, `demo-project`, etc.
3. **Dejar solo aplicaciones generadas por ApplicationSet:** `app-*`

### **Prioridad 2: Ejecutar Sincronización con Dependencias**
1. **Ejecutar:** `./instalar-todo.sh sync`
2. **Monitorear** despliegue secuencial en 6 fases
3. **Validar** que dependencias se respetan correctamente

### **Prioridad 3: Troubleshooting Específico**
1. **Kargo:** Verificar que repo OCI funciona con nueva configuración
2. **External-secrets:** Revisar por qué está OutOfSync
3. **Argo-*:** Verificar versiones de charts son correctas

### **Prioridad 4: Validación Final**
1. **Objetivo:** Alcanzar ≥70% aplicaciones Synced+Healthy
2. **Crear clusters PRE/PRO** cuando validación pase
3. **Documentar** lecciones aprendidas sobre dependencias GitOps

---

## 📁 **ARCHIVOS MODIFICADOS (Esta Sesión)**

### **Nuevos/Modificados:**
- ✅ `scripts/deploy-with-dependencies.sh` (creado, después consolidado)
- ✅ `instalar-todo.sh` (funciones de dependencias integradas)
- ✅ `appset-gitops-infra.yaml` (corregido directory configuration)
- ✅ `componentes/cert-manager/cert-manager.yaml` (duplicados eliminados)
- ✅ `componentes/kargo/kargo.yaml` (password hash escapado)
- ✅ `componentes/kargo/kargo-oci-repo.yaml` (URL OCI corregida)
- ✅ `aplicaciones/demo-project/manifests/` (estructura reorganizada)

### **Pendientes de Verificación:**
- 🔄 ApplicationSet generando aplicaciones correctamente
- 🔄 Conflictos eliminados completamente
- 🔄 Kargo desplegando con repo OCI corregido

---

## 💡 **LECCIONES APRENDIDAS**

### **Dependencias GitOps Críticas:**
1. **cert-manager** debe desplegarse ANTES que ingress, kargo, external-secrets
2. **external-secrets** necesario para aplicaciones con secretos
3. **monitoring** (prometheus) debe estar estable antes de otros componentes
4. **ApplicationSets** pueden generar conflictos con aplicaciones directas

### **Troubleshooting Efectivo:**
1. **Compact diff** de ArgoCD es crucial para entender conflictos reales
2. **ApplicationSets** requieren configuración explícita de `directory`
3. **Repos OCI** necesitan URL completa incluyendo chart específico
4. **Eliminación + recreación** a veces más efectiva que patches

### **Arquitectura GitOps:**
1. **ApplicationSets** deben ser la fuente única de aplicaciones
2. **Aplicaciones directas** solo para casos muy específicos
3. **Dependencias** deben manejarse con esperas y health checks
4. **Git como fuente única** requiere commit+push antes de sync

---

## 🔧 **COMANDOS ÚTILES (Referencia Rápida)**

```bash
# Ver estado general
kubectl get applications -n argocd

# Diagnóstico completo  
./scripts/diagnostico-gitops.sh

# Sincronización con dependencias
./instalar-todo.sh sync

# Forzar refresh de aplicación específica
kubectl annotate application <app> -n argocd argocd.argoproj.io/refresh=now --overwrite

# Ver ApplicationSets
kubectl get applicationset -n argocd

# Eliminar aplicación conflictiva
kubectl delete application <app> -n argocd

# Recrear desde manifiesto
kubectl apply -f componentes/<component>/<component>.yaml
```

---

## 📈 **OBJETIVO FINAL**

**Plataforma GitOps Multi-Cluster completamente funcional:**
- ✅ Cluster DEV con ≥70% aplicaciones Synced+Healthy
- 🔄 Clusters PRE/PRO creados automáticamente tras validación
- 🔄 Despliegue respetando dependencias consolidado en instalar-todo.sh
- 🔄 Kargo funcionando para promociones automáticas dev→pre→pro

**Estado Actual:** ~30% completado → **Objetivo Siguiente Sesión:** 70%+ completado
