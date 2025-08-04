# 📋 Guía de Instalación - Infraestructura GitOps

## 🎯 **Objetivo**

Esta guía detalla el proceso de instalación completa de la **Infraestructura GitOps Hipermodular**, desde un sistema Ubuntu limpio hasta un entorno GitOps completamente funcional.

## 📋 **Prerequisitos Detallados**

### **Sistema Operativo**
- Ubuntu 20.04 LTS o superior
- Debian 11+ (Bullseye)
- CentOS 8+ / Rocky Linux 8+
- Fedora 35+

### **Hardware Mínimo**
```yaml
CPU: 4 cores físicos
RAM: 8GB (16GB recomendado para producción)
Disco: 50GB libres (SSD recomendado)
Red: Conexión a internet estable
```

### **Hardware Recomendado para Producción**
```yaml
CPU: 8+ cores
RAM: 32GB
Disco: 100GB+ SSD NVMe
Red: Fibra óptica / banda ancha de alta velocidad
```

### **Permisos Requeridos**
- **sudo**: Para instalación de dependencias del sistema
- **docker group**: El usuario se añade automáticamente al grupo docker
- **kubectl config**: Permisos de escritura en `~/.kube/`

## 🚀 **Proceso de Instalación**

### **Paso 1: Preparación del Sistema**
```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar git si no está disponible
sudo apt install -y git curl wget

# Clonar el repositorio
git clone https://github.com/asanchez-dev/gh-gitops-infra.git
cd gh-gitops-infra
```

### **Paso 2: Verificación de Prerequisitos**
```bash
# El instalador verifica automáticamente:
# - Disponibilidad de sudo
# - Recursos del sistema (RAM, CPU, disco)
# - Conectividad de red
# - Versiones compatibles de dependencias

./instalador.sh --verificar-solo
```

### **Paso 3: Instalación Completa**
```bash
# Instalación autónoma (requiere sudo)
sudo ./instalador.sh

# Con opciones específicas
sudo ./instalador.sh --cluster gitops-dev --metrics-server --verbose
```

## 🔄 **Fases de Instalación Detalladas**

### **FASE 1: Validación del Sistema**
```bash
# Verificaciones realizadas:
- ✅ Permisos de sudo
- ✅ Recursos del sistema (8GB+ RAM, 4+ CPU cores)
- ✅ Espacio en disco (50GB+ libres)
- ✅ Conectividad de red
- ✅ Puertos disponibles (8080, 3000, 9090, etc.)
```

### **FASE 2: Instalación de Dependencias**
```bash
# Dependencias instaladas automáticamente:
- Docker Engine (última versión estable)
- Minikube (compatible con Docker)
- kubectl (versión 'stable' compatible con minikube)
- Helm (v3.12+)
- ArgoCD CLI (última versión)
```

### **FASE 3: Creación del Cluster**
```bash
# Configuración de minikube:
- Perfil: gitops-dev (configurable)
- Driver: docker
- Kubernetes: versión 'stable' (auto-detectada)
- Recursos: 8GB RAM, 4 CPU cores
- Addons: metrics-server (habilitado automáticamente)
```

### **FASE 4: Instalación de ArgoCD**
```bash
# ArgoCD Core:
- Namespace: argocd
- Version: Latest stable
- Configuración: Optimizada para desarrollo
- CLI: Configurado con login automático
```

### **FASE 5: Despliegue de Herramientas GitOps**
```bash
# App-of-Apps estructura:
📦 herramientas-gitops (6 fases ordenadas)
├── FASE 1: cert-manager + ingress-nginx
├── FASE 2: minio (storage S3)
├── FASE 3: prometheus-stack + grafana + loki + jaeger
├── FASE 4: argo-workflows + argo-rollouts + argo-events + kargo
├── FASE 5: gitea (repositorio interno)
└── FASE 6: external-secrets (gestión de secretos)
```

### **FASE 6: Clusters Adicionales (Opcional)**
```bash
# Multi-entorno automático:
- gitops-pre (preproducción)
- gitops-pro (producción)
- Configuración mínima optimizada
```

### **FASE 7: Verificación Final**
```bash
# Verificaciones post-instalación:
- ✅ Estado de todos los pods
- ✅ Conectividad de servicios
- ✅ Dashboards accesibles
- ✅ ArgoCD sincronizado
- ✅ Métricas funcionando
```

## 🔧 **Configuración Post-Instalación**

### **Acceso a Servicios**
```bash
# Port-forwarding automático configurado:
kubectl port-forward -n argocd service/argocd-server 8080:80 &
kubectl port-forward -n monitoring service/grafana 3000:80 &
kubectl port-forward -n monitoring service/prometheus-server 9090:80 &
```

### **Credenciales por Defecto**

| Servicio | Usuario | Contraseña | Comando para obtener |
|----------|---------|------------|---------------------|
| **ArgoCD** | admin | auto-generada | `argocd admin initial-password -n argocd` |
| **Grafana** | admin | admin | Cambiar en primer login |
| **Gitea** | gitea | gitea | Configurar en primer acceso |

### **URLs de Acceso**
```bash
# Una vez configurado el port-forwarding:
ArgoCD:     http://localhost:8080
Grafana:    http://localhost:3000
Prometheus: http://localhost:9090
Jaeger:     http://localhost:16686
```

## 🚨 **Solución de Problemas Comunes**

### **Error: Recursos Insuficientes**
```bash
# Síntoma: Pods en estado Pending
# Solución: Aumentar recursos de minikube
minikube config set memory 8192
minikube config set cpus 4
minikube delete gitops-dev
minikube start -p gitops-dev
```

### **Error: Puerto Ocupado**
```bash
# Síntoma: Error al hacer port-forward
# Solución: Liberar puertos o usar alternativos
sudo netstat -tulpn | grep :8080
sudo kill -9 <PID>
```

### **Error: Permisos Docker**
```bash
# Síntoma: permission denied para docker
# Solución: Añadir usuario al grupo docker
sudo usermod -aG docker $USER
newgrp docker  # O reiniciar sesión
```

### **Error: ArgoCD No Sincroniza**
```bash
# Síntoma: Applications en estado OutOfSync
# Solución: Sincronización manual
kubectl get applications -n argocd
argocd app sync <app-name>
# O sincronizar todas
argocd app sync --all
```

## 📊 **Verificación de la Instalación**

### **Comando de Diagnóstico Completo**
```bash
./scripts/utilidades/diagnosticos.sh --completo
```

### **Verificaciones Manuales**
```bash
# Estado del cluster
kubectl cluster-info
kubectl get nodes

# Estado de ArgoCD
kubectl get applications -n argocd
kubectl get pods -n argocd

# Estado de herramientas
kubectl get pods --all-namespaces
kubectl top pods --all-namespaces
```

### **Métricas de Rendimiento**
```bash
# Uso de recursos
kubectl top nodes
kubectl top pods --all-namespaces

# Estado de almacenamiento
df -h
docker system df
```

## 🔄 **Actualización y Mantenimiento**

### **Actualizar Herramientas**
```bash
# Actualización automática de charts
./scripts/utilidades/mantenimiento.sh --actualizar-charts

# Actualización manual de versiones
helm repo update
argocd app sync --all
```

### **Limpieza del Sistema**
```bash
# Limpieza completa
./scripts/utilidades/mantenimiento.sh --limpiar-completo

# Limpieza de imágenes Docker
docker system prune -a -f
```

## 📞 **Soporte Técnico**

Si encuentras problemas durante la instalación:

1. **Logs del instalador**: Revisa `logs/instalacion-$(date +%Y%m%d).log`
2. **Diagnóstico**: Ejecuta `./scripts/utilidades/diagnosticos.sh`
3. **Issues**: Reporta en [GitHub Issues](https://github.com/asanchez-dev/gh-gitops-infra/issues)

---

> **Nota**: Esta guía se actualiza continuamente. Para la última versión, consulta la [documentación online](https://github.com/asanchez-dev/gh-gitops-infra/docs).
