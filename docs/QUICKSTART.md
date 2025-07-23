# 🚀 Quick Start Guide

> **Complete GitOps platform deployment in under 15 minutes**

## ⚡ **Ultra-Fast Installation (Single Command)**

```bash
# Complete installation from scratch
git clone https://github.com/YOUR_USERNAME/gh-gitops-infra.git
cd gh-gitops-infra
./install-everything.sh
```

**That's it!** This single command will:
1. ✅ Install Docker, kubectl, minikube, helm (if missing)
2. ✅ Generate configuration automatically
3. ✅ Create 3 Minikube clusters (DEV/PRE/PROD)
4. ✅ Deploy ArgoCD in DEV cluster
5. ✅ Auto-deploy all infrastructure via GitOps
6. ✅ Setup port-forwarding for access

## 📊 **Expected Timeline**

| Phase | Duration | Description |
|-------|----------|-------------|
| Prerequisites | 2-5 min | Docker, kubectl, minikube, helm installation |
| Configuration | 30 sec | Auto-generate config from Git repository |
| Cluster Creation | 3-8 min | Create 3 Minikube clusters |
| ArgoCD Deployment | 1-2 min | Install GitOps control plane |
| Infrastructure Sync | 5-10 min | ArgoCD deploys all components |
| **Total** | **12-25 min** | **Complete GitOps platform ready** |

## 🎯 **Verification Steps**

### 1. Check Installation Status
```bash
# Verify all clusters are running
kubectl config get-contexts

# Check ArgoCD applications
kubectl get applications -n argocd

# Verify all pods are running
kubectl get pods --all-namespaces | grep -v Running | wc -l  # Should be 0
```

### 2. Access UIs
| Service | URL | Credentials | Status Check |
|---------|-----|-------------|--------------|
| ArgoCD | http://localhost:8080 | admin/[auto-generated] | ✅ GitOps control |
| Grafana | http://localhost:3000 | admin/admin | ✅ Observability |
| Kargo | http://localhost:3002 | admin/admin123 | ✅ Promotions |
| Gitea | http://localhost:3001 | admin/admin123 | ✅ Git server |

### 3. Test Demo Applications
```bash
# Check demo project deployment
kubectl get pods -n demo-project

# Port-forward demo services (optional)
kubectl port-forward -n demo-project svc/demo-frontend 8082:80 &
kubectl port-forward -n demo-project svc/demo-backend 8083:3000 &
```

## 🔧 **Customization (Optional)**

If you want to customize the installation:

```bash
# Interactive configuration
./setup-config.sh --interactive

# Then run bootstrap
./bootstrap-multi-cluster.sh
```

## 🐛 **Troubleshooting**

### Issue: Port forwarding not working
```bash
# Restart port forwards
./scripts/setup-port-forwards.sh
```

### Issue: Applications not syncing
```bash
# Force ArgoCD refresh
kubectl patch application gitops-infra-apps -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Issue: Cluster not starting
```bash
# Check system resources (need 8GB+ RAM, 4+ CPU)
free -h
nproc

# Restart with more resources
minikube delete --profile=gitops-dev
minikube start --profile=gitops-dev --cpus=4 --memory=8192
```

## ✅ **Success Indicators**

You'll know the installation is successful when:

1. **All clusters running**: `kubectl config get-contexts` shows 3 contexts
2. **ArgoCD healthy**: All applications show "Synced" and "Healthy"
3. **UIs accessible**: All 4 web interfaces load without errors
4. **Demo apps running**: All pods in `demo-project` namespace are Running

## 🎯 **Next Steps**

1. **Explore ArgoCD**: Browse applications and see GitOps in action
2. **Check Grafana**: View pre-configured dashboards and metrics
3. **Test Promotions**: Use Kargo to promote between environments
4. **Review Documentation**: Check `docs/` for advanced configurations

**Congratulations! Your enterprise GitOps platform is ready! 🎉**

