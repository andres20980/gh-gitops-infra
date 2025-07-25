# ApplicationSet - Multi-Cluster Application Management

ApplicationSet es una extensión de ArgoCD que permite generar y gestionar múltiples aplicaciones ArgoCD automáticamente usando patrones declarativos.

## 🎯 Beneficios en tu Infraestructura GitOps

### **1. Multi-Cluster at Scale**
- **Una definición** → Apps automáticas en dev/pre/pro
- **DRY principle**: No repetir configuraciones
- **Consistent deployments**: Mismo manifiesto, múltiples clusters

### **2. Generator Patterns** 
- **Cluster Generator**: Deploy en todos los clusters registrados
- **Git Directory Generator**: Nuevos directorios → Apps automáticas
- **Matrix Generator**: Combinar múltiples fuentes (clusters × componentes)

### **3. Template-Driven**
- **Valores dinámicos**: Cluster name, environment, namespaces
- **Conditional logic**: Diferentes configs por cluster
- **Automated naming**: Apps con nombres consistentes

## 📦 Casos de Uso Implementados

### **Demo Project Multi-Cluster**
Archivo: `examples/demo-multicluster-applicationset.yaml`

```yaml
# Un ApplicationSet que despliega:
# - demo-frontend en dev/pre/pro
# - demo-backend en dev/pre/pro  
# - demo-database en dev/pre/pro
# Total: 9 aplicaciones generadas automáticamente
```

**Características:**
- ✅ Deploy automático en todos los clusters con label `environment: gitops`
- ✅ Namespaces dinámicos por componente
- ✅ Values específicos por cluster (`values-dev.yaml`, `values-pre.yaml`, etc.)
- ✅ Ingress hosts dinámicos (`demo-frontend-dev.local`)
- ✅ Sync policies consistentes
- ✅ Health checks personalizados

### **Git Directory Generator (Futuro)**
```yaml
# Automáticamente crear apps para:
# - Cada directorio en manifiestos/
# - Nuevos servicios sin configuración manual
# - Microservicios con estructura estándar
```

### **Environment Promotion Pipeline**
```yaml
# Generator que combina:
# - Clusters por environment (dev/pre/pro)
# - Applications por lifecycle stage
# - Automated promotion triggers
```

## 🚀 Implementación

### **1. Instalación**
ApplicationSet se instala automáticamente con el script principal:
```bash
./instalar-todo.sh  # Incluye ApplicationSet v0.4.5
```

### **2. Deployment del Ejemplo**
```bash
# Aplicar el ApplicationSet de ejemplo
kubectl apply -f componentes/argocd-applicationset/examples/demo-multicluster-applicationset.yaml

# Verificar apps generadas
kubectl get applications -n argocd | grep demo-
```

### **3. Configurar Labels en Clusters**
```bash
# Etiquetar clusters para el selector
kubectl label cluster dev environment=gitops
kubectl label cluster pre environment=gitops  
kubectl label cluster pro environment=gitops
```

## 🔄 Integración con tu Stack

### **Con Kargo**
- ApplicationSet crea apps en todos los clusters
- Kargo maneja promociones dev→pre→pro
- Notifications alertan sobre deployments

### **Con Argo Events**
- Git changes → Trigger ApplicationSet refresh
- New clusters → Auto-deploy standard apps
- Directory changes → Create new applications

### **Con ArgoCD Notifications**
- Success/failure notifications per cluster
- Health degradation alerts
- Promotion readiness notifications

## 💡 Ventajas vs Configuración Manual

| Aspecto | Manual (actual) | ApplicationSet |
|---------|----------------|----------------|
| **Clusters** | 3 apps manuales | 1 ApplicationSet → 9 apps automáticas |
| **Nuevos servicios** | 3 manifiestos manuales | Automático por directorio |
| **Consistencia** | Propenso a errores | Garantizada por template |
| **Mantenimiento** | Alto (3x trabajo) | Bajo (1 definición) |
| **Escalabilidad** | Limitada | Ilimitada |

## 🎯 Próximos Pasos

1. **Validar el ApplicationSet de ejemplo**
2. **Migrar demo-project a ApplicationSet**
3. **Crear ApplicationSets para infraestructura**
4. **Implementar Git Directory Generator**
5. **Integrar con Kargo para promociones automáticas**

¡ApplicationSet transforma tu gestión manual de 3 clusters en automatización escalable!
