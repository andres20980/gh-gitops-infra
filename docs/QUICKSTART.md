# 🏢 Enterprise GitOps Infrastructure - Quick Start Guide

## 🚀 Super Quick Start (For Impatient People)

```bash
# Clone and run
git clone http://192.168.34.196:3000/andres20980/gitops-infra.git
cd gitops-infra
./bootstrap-gitops.sh
```

Wait 5-10 minutes and access:
- **ArgoCD**: http://localhost:8080 (admin / see terminal output)
- **Kargo**: https://localhost:3000 (admin / admin)  
- **Grafana**: http://localhost:3001 (admin / admin)

## 🛠️ Management Commands

```bash
# Health check everything
./scripts/health-check.sh

# Restart services access
./scripts/setup-port-forwards.sh

# Soft cleanup (preserve data)
./cleanup-gitops.sh soft

# Complete destruction
./cleanup-gitops.sh full
```

## 🎯 Enterprise Features Ready to Use

✅ **17 Applications** fully deployed and synchronized  
✅ **Multi-Environment Promotion** with Kargo  
✅ **Complete Observability** stack (Prometheus + Grafana + Loki + Jaeger)  
✅ **CI/CD Pipelines** with Argo Workflows  
✅ **Progressive Delivery** with Argo Rollouts  
✅ **GitOps Native** everything as code  

## 📊 Current Status

Your infrastructure includes:
- 🎯 **Control Plane**: ArgoCD, Kargo, Gitea
- 📊 **Observability**: Prometheus, Grafana, Loki, Jaeger  
- 🔄 **CI/CD**: Argo Workflows, Argo Rollouts
- 🛠️ **Infrastructure**: Ingress, Cert Manager, External Secrets, MinIO
- 🎮 **Demo App**: 3-tier application ready for promotions

¡Happy Enterprise GitOps! 🎉🚀
