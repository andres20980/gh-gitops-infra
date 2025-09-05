# 🚨 Guía de Resolución de Problemas - GitOps España

## 📋 Índice de Problemas Comunes
- [🐳 Problemas de Docker](#-problemas-de-docker)
- [☸️ Problemas de Kubernetes](#️-problemas-de-kubernetes)
- [🎯 Problemas de ArgoCD](#-problemas-de-argocd)
- [📊 Problemas de Monitoreo](#-problemas-de-monitoreo)
- [🔧 Problemas de Scripts](#-problemas-de-scripts)
- [🌐 Problemas de Red](#-problemas-de-red)

## 🐳 Problemas de Docker

### Error: "Demonio de Docker no en ejecución"
```bash
# Síntomas
docker: Cannot connect to the Docker daemon at unix:///var/run/docker.sock

# Solución
sudo systemctl start docker
sudo systemctl enable docker

# Verificación
docker --version
docker ps
```

### Error: "Permiso denegado" con Docker
```bash
# Síntomas
Got permission denied while trying to connect to the Docker daemon socket

# Solución
sudo usermod -aG docker $USER
newgrp docker  # O reiniciar sesión

# Verificación
docker run hello-world
```

### Docker consume mucho espacio
```bash
# Diagnóstico
docker system df
docker images
docker ps -a

# Limpieza
docker system prune -a --volumes
docker builder prune -a
```

## ☸️ Problemas de Kubernetes

### Minikube no inicia
```bash
# Síntomas
😿 minikube start falló

# Diagnóstico
minikube logs
minikube status -p gitops-dev

# Soluciones comunes
minikube delete -p gitops-dev  # Reset completo
minikube start -p gitops-dev --driver=docker --cpus=4 --memory=8192mb

# Verificar recursos del sistema
free -h
df -h
```

### Pods en estado Pending
```bash
# Diagnóstico
kubectl get pods --all-namespaces
kubectl describe pod <pod-name> -n <namespace>

# Verificar recursos
kubectl top nodes
kubectl describe nodes

# Soluciones
# 1. Aumentar recursos del cluster
minikube config set cpus 4
minikube config set memory 8192

# 2. Verificar taints en nodos
kubectl get nodes -o json | jq '.items[].spec.taints'
```

### Pods en CrashLoopBackOff
```bash
# Diagnóstico
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Verificar configuración
kubectl describe pod <pod-name> -n <namespace>

# Verificar recursos
kubectl get pod <pod-name> -n <namespace> -o yaml
```

## 🎯 Problemas de ArgoCD

### ArgoCD Apps atascadas en "En progreso"
```bash
# Diagnóstico
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# Verificar logs del controller
kubectl logs -n argocd deployment/argocd-application-controller

# Forzar refresh
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

### Fallos de sincronización por validación
```bash
# Síntomas
Failed to apply resource: admission webhook denied

# Verificar webhook de validación
kubectl get validatingwebhookconfiguration
kubectl get mutatingwebhookconfiguration

# Bypass temporal (solo para debugging)
kubectl apply --validate=false -f <manifest>
```

### ArgoCD no puede acceder a GitHub
```bash
# Verificar conectividad
kubectl exec -it -n argocd deployment/argocd-repo-server -- wget -qO- https://github.com

# Verificar configuración del repo
kubectl get secret -n argocd argocd-repo-creds-https-github.com
```

## 📊 Problemas de Monitoreo

### Prometheus no recopilando métricas
```bash
# Verificar targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
# Ir a http://localhost:9090/targets

# Verificar ServiceMonitor
kubectl get servicemonitor -n monitoring

# Verificar labels de servicios
kubectl get svc -n <namespace> --show-labels
```

### Paneles de Grafana vacíos
```bash
# Verificar datasource
kubectl logs -n monitoring deployment/grafana

# Verificar conectividad con Prometheus
kubectl exec -it -n monitoring deployment/grafana -- wget -qO- http://prometheus-server/api/v1/query?query=up
```

## 🔧 Problemas de Scripts

### Error: "comando no encontrado"
```bash
# Verificar PATH
echo $PATH
which docker kubectl helm minikube

# Instalar dependencias faltantes
./scripts/fases/fase-02-dependencias.sh
```

### Permisos de ejecución
```bash
# Síntomas
bash: ./instalar.sh: Permiso denegado

# Solución
chmod +x instalar.sh
chmod +x scripts/**/*.sh
```

### Variables de entorno no definidas
```bash
# Síntomas
./instalar.sh: line 45: RUTA_PROYECTO: unbound variable

# Verificar autocontención
source scripts/comun/autocontener.sh
echo $RUTA_PROYECTO
```

## 🌐 Problemas de Red

### Ingress no accesible externamente
```bash
# Verificar ingress controller
kubectl get pods -n ingress-nginx

# Verificar servicios
kubectl get svc -n ingress-nginx

# Para minikube, usar tunnel
minikube tunnel -p gitops-dev

# Verificar reglas de ingress
kubectl get ingress --all-namespaces
kubectl describe ingress <ingress-name> -n <namespace>
```

### Problemas de resolución de DNS
```bash
# Verificar CoreDNS
kubectl get pods -n kube-system | grep coredns

# Test DNS desde pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default
```

## 🔧 Comandos de Diagnóstico Rápido

### Estado General del Sistema
```bash
# Script de diagnóstico rápido
./test-arquitectura.sh

# Estado de todos los componentes
kubectl get all --all-namespaces
kubectl get applications -n argocd
kubectl top nodes
kubectl top pods --all-namespaces
```

### Logs Centralizados
```bash
# ArgoCD
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller

# Ingress
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Prometheus
kubectl logs -n monitoring deployment/prometheus-server
```

### Cleanup en Emergencia
```bash
# Reset completo (CUIDADO: Borra todo)
minikube delete -p gitops-dev
minikube delete -p gitops-pre  
minikube delete -p gitops-pro

# Reinstalación limpia
./instalar.sh --clean
```

---

## 📞 Contacto y Soporte

- **Issues**: https://github.com/andres20980/gh-gitops-infra/issues
- **Documentación**: https://github.com/andres20980/gh-gitops-infra/docs
- **Slack**: #gitops-españa

---

**Versión**: 3.0.0  
**Última actualización**: 2025-08-06
