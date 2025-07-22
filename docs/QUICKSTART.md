# 🏢 Enterprise GitOps Infrastructure - Quick Start Guide

## 🚀 Super Quick Start (For Impatient People)

```bash
# Clone and run
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra
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

---

## 🪟 WSL (Windows Subsystem for Linux) Setup

### Prerequisites Installation in WSL

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# ⚠️ IMPORTANT: Restart your terminal after this

# 3. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 4. Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# 5. Verify installations
docker --version
kubectl version --client
minikube version
```

### Complete WSL Installation Process

```bash
# 1. Clone the repository
git clone https://github.com/andres20980/gh-gitops-infra.git
cd gh-gitops-infra

# 2. Make scripts executable
chmod +x bootstrap-gitops.sh cleanup-gitops.sh
chmod +x scripts/*.sh

# 3. Run automated bootstrap
./bootstrap-gitops.sh

# 4. Wait 5-10 minutes for complete deployment
# 5. Access services at the URLs shown in terminal output
```

### WSL-Specific Notes

- **Docker**: Must be running in WSL2 mode for best performance
- **Memory**: Ensure WSL has at least 10GB RAM allocated
- **Port Forwarding**: Services will be accessible from Windows browser
- **Performance**: First-time deployment may take longer due to image downloads

### WSL Configuration (.wslconfig)

Create or update `%USERPROFILE%/.wslconfig` on Windows:

```ini
[wsl2]
memory=12GB
processors=4
swap=2GB
```

Restart WSL: `wsl --shutdown` then reopen terminal.

