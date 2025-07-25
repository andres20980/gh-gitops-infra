# Argo Events - Ejemplos de EventSources y Sensors

Este directorio contiene ejemplos prácticos de cómo usar Argo Events en tu infraestructura GitOps para automatización event-driven.

## 🎯 Casos de Uso Implementados

### 1. **Gitea Webhook → ArgoCD Sync**
- **EventSource**: `gitea-webhook-eventsource.yaml`
- **Sensor**: `gitea-argocd-sync-sensor.yaml`
- **Propósito**: Git push en Gitea → Trigger sync específico de aplicación ArgoCD

### 2. **MinIO Object Events → Processing Workflow**
- **EventSource**: `minio-s3-eventsource.yaml`
- **Sensor**: `minio-processing-sensor.yaml`
- **Propósito**: Nuevo objeto en MinIO → Launch workflow de procesamiento

### 3. **Scheduled Kargo Promotions**
- **EventSource**: `calendar-schedule-eventsource.yaml`
- **Sensor**: `kargo-promotion-sensor.yaml`
- **Propósito**: Promociones programadas dev→pre→pro

### 4. **Health Check Auto-Healing**
- **EventSource**: `webhook-health-eventsource.yaml`
- **Sensor**: `auto-healing-sensor.yaml`
- **Propósito**: Health check fails → Auto-restart deployments

## 🚀 Instalación

1. **Instalar EventSources**:
```bash
kubectl apply -f examples/eventsources/
```

2. **Instalar Sensors**:
```bash
kubectl apply -f examples/sensors/
```

3. **Verificar funcionamiento**:
```bash
kubectl get eventsources -n argo-events
kubectl get sensors -n argo-events
```

## 🔗 Integración con tu Stack

- **ArgoCD**: Sync automático de aplicaciones específicas
- **Kargo**: Promociones event-driven entre entornos
- **Gitea**: Webhooks nativos para Git events
- **MinIO**: S3 bucket notifications
- **Prometheus**: Alerts → Actions automáticas
- **Grafana**: Dashboard events → Automated responses

## 📡 Webhook Endpoints

Una vez desplegado, los webhooks estarán disponibles en:
- **Gitea Webhook**: `http://localhost:8089/gitea`
- **Generic Webhook**: `http://localhost:8089/webhook`
- **Health Check**: `http://localhost:8089/health`

## 💡 Próximos Pasos

1. Configurar webhooks en Gitea apuntando a Argo Events
2. Configurar MinIO bucket notifications
3. Crear sensores personalizados para tu flujo GitOps
4. Integrar con sistema de alerting (Prometheus → Actions)
