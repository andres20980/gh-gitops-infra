# 🚀 Enterprise GitOps Multi-Cluster Infrastructure

> **Production-ready GitOps platform** with ArgoCD, multi-cluster orchestration, comprehensive observability, and automated promotion workflows following CNCF best practices.

## 🎯 **One-Command Installation**

```bash
# Complete installation from scratch
./install-everything.sh
```

**That's it!** ✨ This single command installs all prerequisites, creates 3 Kubernetes clusters, deploys ArgoCD, and automatically provisions the entire GitOps infrastructure.

---

## 🏗️ **Architecture Overview**

```
🏢 Enterprise Multi-Cluster GitOps Platform
┌─────────────────────────────────────────────────────────────┐
│  🎯 Control Plane (DEV)     🧪 Staging (PRE)   🏭 Production  │
│  ┌─────────────────────┐   ┌─────────────────┐  ┌─────────────┐ │
│  │ 🔄 ArgoCD (Master)  │──▶│   Applications   │─▶│ Applications│ │
│  │ � Kargo Promotions │   │   (GitOps Sync)  │  │(GitOps Sync)│ │
│  │ 📊 Observability    │   └─────────────────┘  └─────────────┘ │
│  │ 🎢 Demo Applications│                                         │
│  └─────────────────────┘                                         │
└─────────────────────────────────────────────────────────────┘

📦 Single ArgoCD manages all clusters (GitOps Best Practice)
🔄 Automated promotions: DEV → PRE → PROD
📊 Centralized observability and monitoring
```

## ✨ **Key Features**

| Feature | Description | Status |
|---------|-------------|---------|
| **🔄 GitOps Native** | Everything as code, declarative infrastructure | ✅ Ready |
| **🌐 Multi-Cluster** | DEV/PRE/PROD simulation on local machine | ✅ Ready |
| **🚀 Auto-Promotions** | Kargo-powered environment promotions | ✅ Ready |
| **📊 Full Observability** | Prometheus + Grafana + Loki + Jaeger | ✅ Ready |
| **🎢 Progressive Delivery** | Canary deployments with Argo Rollouts | ✅ Ready |
| **🔐 Security First** | External Secrets, RBAC, network policies | ✅ Ready |
| **🏥 Self-Healing** | Automatic recovery and health checks | ✅ Ready |

---

## 🚀 **Quick Start**

### Prerequisites
- **OS**: Ubuntu 20.04+, WSL2, or macOS
- **Resources**: 8GB+ RAM, 4+ CPU cores, 50GB+ disk space
- **Network**: Internet connection for downloads

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/gh-gitops-infra.git
cd gh-gitops-infra

# 2. Run the complete installation
./install-everything.sh
```

**What happens:**
1. ✅ **Prerequisites**: Installs Docker, kubectl, minikube, helm
2. ✅ **Configuration**: Auto-generates config from your Git repository
3. ✅ **Clusters**: Creates 3 Minikube clusters (DEV/PRE/PROD)
4. ✅ **ArgoCD**: Deploys GitOps control plane in DEV cluster
5. ✅ **Infrastructure**: ArgoCD automatically deploys all components
6. ✅ **Access**: Sets up port-forwarding for all UIs

### Expected Output
```
🏆================================================
   🎉 COMPLETE INSTALLATION FINISHED!
   📊 Multi-Cluster GitOps Platform Ready!
================================================

🎯 Access URLs:
   ArgoCD UI:    http://localhost:8080 (admin/PASSWORD)
   Grafana:      http://localhost:3000 (admin/admin)
   Kargo UI:     http://localhost:3002 (admin/admin123)
   Gitea:        http://localhost:3001 (admin/admin123)
```

---

## 🌐 **Architecture Deep Dive**

### GitOps Best Practices Implementation

#### 🎯 Single ArgoCD Approach
- **Control Plane**: One ArgoCD instance in DEV cluster
- **Multi-Cluster**: Manages PRE and PROD clusters remotely
- **Benefits**: Centralized control, reduced resource usage, simplified operations

#### 🔄 Automated Promotion Pipeline
```
Development     Staging        Production
    ┌───┐  Auto   ┌───┐  Manual  ┌───┐
    │DEV│ ────────▶│PRE│ ────────▶│PRD│
    └───┘  Deploy  └───┘  Review  └───┘
      ↑                            ↑
   Git Push                   Kargo Approval
```

#### 📊 Observability Stack
- **Metrics**: Prometheus scrapes all clusters
- **Dashboards**: Grafana with pre-configured dashboards
- **Logs**: Loki centralized logging
- **Tracing**: Jaeger distributed tracing
- **Alerts**: AlertManager with Slack/email notifications

---

## 🔧 **Customization**

### For Fork Users
If you forked this repository, customize it for your environment:

```bash
# Interactive configuration
./setup-config.sh --interactive

# Or quick auto-setup
./setup-config.sh --auto
```

### Configuration Options
- **Resource Allocation**: CPU/Memory per cluster
- **Component Selection**: Enable/disable services
- **Repository Settings**: Your GitHub username/org
- **Network Ports**: Customize port assignments

---

## 📚 **Components Deployed**

### 🎯 Core GitOps
| Component | Version | Purpose | Namespace |
|-----------|---------|---------|-----------|
| ArgoCD | v2.12.3 | GitOps Controller | `argocd` |
| Kargo | v0.8.4 | Promotion Engine | `kargo` |
| Argo Rollouts | Latest | Progressive Delivery | `argo-rollouts` |
| Argo Workflows | Latest | CI/CD Pipelines | `argo-workflows` |

### 📊 Observability
| Component | Purpose | Access URL |
|-----------|---------|------------|
| Prometheus | Metrics Collection | Grafana Datasource |
| Grafana | Dashboards & Alerts | http://localhost:3000 |
| Loki | Log Aggregation | Grafana Datasource |
| Jaeger | Distributed Tracing | Embedded in Grafana |

### 🌐 Infrastructure
| Component | Purpose | Notes |
|-----------|---------|--------|
| Ingress NGINX | Traffic Management | Default ingress controller |
| Cert Manager | TLS Certificate Management | Let's Encrypt ready |
| External Secrets | Secret Management | HashiCorp Vault integration |
| MinIO | Object Storage | S3-compatible storage |

### 🎭 Demo Applications
| Application | Technology | Purpose |
|-------------|------------|---------|
| Frontend | React-like | User interface demo |
| Backend | Node.js API | Microservice demo |
| Database | Redis | Data persistence demo |

---

## 🛠️ **Operations**

### Cluster Management
```bash
# Check cluster status
./scripts/cluster-status.sh

# Switch between clusters
kubectl config use-context gitops-dev    # Development
kubectl config use-context gitops-pre    # Staging
kubectl config use-context gitops-prod   # Production

# Setup port forwarding
./scripts/setup-port-forwards.sh
```

### Cleanup
```bash
# Soft cleanup (preserve data)
./cleanup-multi-cluster.sh soft

# Complete cleanup (remove everything)
./cleanup-multi-cluster.sh hard
```

---

## 📖 **Documentation**

| Document | Description |
|----------|-------------|
| [📚 Multi-Cluster Design](docs/MULTI_CLUSTER_DESIGN.md) | Architecture decisions and patterns |
| [🚀 Quick Start Guide](docs/QUICKSTART.md) | Step-by-step installation guide |
| [🔧 Infrastructure Status](docs/INFRASTRUCTURE_STATUS.md) | Component status and health checks |
| [✅ Validation Report](docs/VALIDATION_REPORT.md) | Testing and validation procedures |

---

## 🎯 **Use Cases**

### 🎓 Learning & Development
- **GitOps Principles**: Hands-on experience with GitOps workflows
- **Kubernetes Multi-Cluster**: Local simulation of enterprise environments
- **Observability**: Complete monitoring and logging stack
- **CI/CD Patterns**: Modern deployment and promotion strategies

### 🏢 Enterprise PoC
- **Architecture Validation**: Test GitOps patterns before production
- **Tool Evaluation**: Compare GitOps tools and workflows
- **Team Training**: Onboard teams to GitOps practices
- **Integration Testing**: Validate CI/CD pipeline integration

### 🔬 Experimentation
- **New Technologies**: Test latest CNCF projects
- **Custom Workflows**: Develop organization-specific patterns
- **Performance Testing**: Load test GitOps workflows
- **Security Validation**: Test security policies and practices

---

## 🤝 **Contributing**

1. **Fork** the repository
2. **Create** your feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🌟 **Star the Project**

If this project helped you, please consider giving it a ⭐ on GitHub!

---

**Built with ❤️ for the GitOps community**
