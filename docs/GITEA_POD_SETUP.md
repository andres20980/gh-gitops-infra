# 📦 Gitea Pod Configuration

## 🎯 Overview

Gitea is deployed as a **Kubernetes pod** with **persistent storage**, providing a complete Git server inside your cluster.

## 💾 Persistence Configuration

### Storage Structure
```
📁 Gitea Data (Persistent)
├── 📄 gitea.db           # SQLite database
├── 📂 git/repositories/  # Git repositories
├── 📂 conf/              # Configuration files
└── 📂 logs/              # Application logs
```

### PersistentVolumes
- **Primary PVC**: `gitea-shared-storage` (5Gi) - Main application data
- **Data PVC**: `gitea-data-pvc` (10Gi) - Git repositories and database
- **Access Mode**: ReadWriteOnce
- **Reclaim Policy**: Retain (data survives pod deletion)

## 🚀 Deployment Architecture

```yaml
┌─────────────────────────────────────┐
│             Minikube                │
│  ┌─────────────────────────────────┐│
│  │          gitea namespace        ││
│  │  ┌─────────────────────────────┐││
│  │  │        Gitea Pod            │││
│  │  │  ┌─────────────────────────┐│││
│  │  │  │      Gitea App          ││││
│  │  │  │   (Port 3000)           ││││
│  │  │  └─────────────────────────┘│││
│  │  │  ┌─────────────────────────┐│││
│  │  │  │    Persistent Volume    ││││
│  │  │  │   /data (5Gi + 10Gi)    ││││
│  │  │  └─────────────────────────┘│││
│  │  └─────────────────────────────┘││
│  └─────────────────────────────────┘│
│                 │                   │
│    ┌─────────────────────────────┐  │
│    │      Port Forward           │  │
│    │   localhost:3002 → 3000     │  │
│    └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

## 🔧 Configuration Details

### Admin Access
- **URL**: http://localhost:3002
- **Username**: admin  
- **Password**: admin123
- **Email**: admin@gitea.local

### Database
- **Type**: SQLite3
- **Location**: `/data/gitea/gitea.db`
- **Backup**: Automatic with pod lifecycle

### Repository Storage
- **Location**: `/data/git/repositories`
- **Permissions**: Managed by Gitea
- **Backup**: Persistent across pod restarts

## 🛠️ Management Commands

### Setup Gitea
```bash
./scripts/setup-gitea.sh
```

### Access Gitea
```bash
kubectl port-forward -n gitea svc/gitea-http 3002:3000 --address=0.0.0.0
```

### Check Persistence
```bash
kubectl get pvc -n gitea
kubectl describe pv $(kubectl get pvc -n gitea -o jsonpath='{.items[0].spec.volumeName}')
```

### Backup Repositories
```bash
kubectl exec -n gitea deployment/gitea -- tar -czf /tmp/backup.tar.gz /data/git/repositories
kubectl cp gitea/$(kubectl get pods -n gitea -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].metadata.name}'):/tmp/backup.tar.gz ./gitea-backup.tar.gz
```

## 🔄 Migration from External Git

### From GitHub
1. Access Gitea: http://localhost:3002
2. Create new repository: `gitops-infra`
3. Clone your GitHub repository locally
4. Add Gitea remote: `git remote add gitea http://localhost:3002/admin/gitops-infra.git`
5. Push to Gitea: `git push gitea main`

### Update ArgoCD Applications
Update repository URLs in:
- `gitops-infra-apps.yaml`
- `projects/demo-project/app-of-apps.yaml` 
- All application manifests

**New Repository URL**: `http://gitea-http.gitea.svc.cluster.local:3000/admin/gitops-infra.git`

## 📊 Benefits of Pod-based Gitea

### ✅ Advantages
- **Self-contained**: No external dependencies
- **Persistent**: Data survives pod restarts
- **Isolated**: Runs in dedicated namespace
- **Scalable**: Can be moved to different clusters
- **Secure**: Internal cluster communication

### 🎯 Use Cases
- **PoC/Demo**: Perfect for demonstrations
- **Development**: Local GitOps testing
- **Air-gapped**: No internet required
- **Learning**: Understanding GitOps workflows

## 🆘 Troubleshooting

### Pod Won't Start
```bash
kubectl describe pod -n gitea -l app.kubernetes.io/name=gitea
kubectl logs -n gitea -l app.kubernetes.io/name=gitea
```

### Storage Issues
```bash
kubectl get pvc -n gitea
kubectl describe pvc gitea-shared-storage -n gitea
```

### Access Problems
```bash
kubectl get svc -n gitea
kubectl port-forward -n gitea svc/gitea-http 3002:3000 --address=0.0.0.0
```

### Data Recovery
```bash
# List persistent volumes
kubectl get pv | grep gitea

# Access pod filesystem  
kubectl exec -n gitea -it deployment/gitea -- /bin/sh
ls -la /data/git/repositories
```
