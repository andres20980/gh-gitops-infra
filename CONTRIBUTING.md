# Contributing to GitOps Multi-Cluster Infrastructure

Thank you for your interest in contributing to this GitOps infrastructure project! This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Submitting Changes](#submitting-changes)
- [Testing](#testing)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Prerequisites

- Ubuntu/Debian-based system (for development and testing)
- Basic knowledge of Kubernetes, ArgoCD, and GitOps principles
- Git installed and configured

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # Fork via GitHub UI, then clone your fork
   git clone https://github.com/YOUR-USERNAME/gh-gitops-infra.git
   cd gh-gitops-infra
   ```

2. **Set up the development environment**
   ```bash
   # Install the complete GitOps stack
   ./instalar-todo.sh
   
   # Verify installation
   ./scripts/diagnostico-gitops.sh
   ```

3. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Project Structure

- `componentes/` - ArgoCD Applications (App of Apps pattern)
- `aplicaciones/` - Sample business applications
- `scripts/` - Management and utility scripts
- `instalar-todo.sh` - Main installation script
- `app-of-apps-gitops.yaml` - Main App of Apps manifest

### Making Changes

1. **Component Changes**: Modify files in `componentes/` directory
   - Follow existing YAML structure
   - Ensure latest stable versions are used
   - Test with development resources (limited CPU/memory)

2. **Script Changes**: Update scripts in `scripts/` directory
   - Maintain backward compatibility
   - Add proper error handling
   - Update `instalar-todo.sh` if needed

3. **Documentation**: Update relevant documentation
   - README.md for user-facing changes
   - Comments in scripts for technical changes
   - CHANGELOG.md for version tracking

### Testing Your Changes

1. **Test the complete installation**
   ```bash
   # Clean environment
   ./instalar-todo.sh limpiar
   
   # Fresh installation
   ./instalar-todo.sh
   
   # Verify all 14 applications are Synced+Healthy
   argocd app list
   ```

2. **Test specific components**
   ```bash
   # Test individual component sync
   argocd app sync COMPONENT_NAME
   
   # Verify health
   argocd app get COMPONENT_NAME
   ```

3. **Test scripts**
   ```bash
   # Test diagnostic script
   ./scripts/diagnostico-gitops.sh
   
   # Test port-forwarding
   ./scripts/setup-port-forwards.sh
   ```

## Submitting Changes

### Pull Request Process

1. **Ensure your changes work**
   - All applications should be Synced+Healthy
   - Scripts should execute without errors
   - Documentation should be updated

2. **Create a clear commit message**
   ```bash
   git commit -m "feat: add new component for X functionality"
   # or
   git commit -m "fix: resolve Kargo OCI registry issue"
   # or
   git commit -m "docs: update installation instructions"
   ```

3. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   # Create PR via GitHub UI
   ```

### PR Requirements

- [ ] Code follows project conventions
- [ ] Tests pass (complete installation works)
- [ ] Documentation is updated
- [ ] CHANGELOG.md is updated
- [ ] All applications remain Synced+Healthy
- [ ] No breaking changes without version bump

## Testing

### Automated Testing

The project uses the installation script as the primary test:

```bash
# Complete test run
./instalar-todo.sh && ./scripts/diagnostico-gitops.sh
```

### Manual Testing Checklist

- [ ] Clean installation works from scratch
- [ ] All 14 applications deploy successfully
- [ ] All web UIs are accessible
- [ ] Port-forwarding works correctly
- [ ] App of Apps pattern functions properly
- [ ] Kargo promotions work (if applicable)

## Style Guidelines

### YAML Files

- Use 2-space indentation
- Include descriptive comments
- Follow ArgoCD Application structure
- Use latest stable versions
- Include resource limits for development

```yaml
# Good example
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: component-name
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://official-repo.com/charts
    targetRevision: "1.2.3"  # Latest stable
    chart: component-name
    helm:
      parameters:
        - name: resources.requests.memory
          value: "128Mi"  # Development-optimized
```

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include `set -euo pipefail` for safety
- Add descriptive comments
- Use consistent color coding
- Include error handling

```bash
#!/bin/bash
set -euo pipefail

# Color definitions
GREEN='\033[0;32m'
NC='\033[0m'

# Function example
function_name() {
    echo -e "${GREEN}✅ Doing something...${NC}"
    # Implementation here
}
```

### Documentation

- Use clear, concise language
- Include code examples
- Use emojis for visual organization
- Maintain table of contents for long documents
- Include troubleshooting sections

## Questions?

- Open an issue for bugs or feature requests
- Start a discussion for general questions
- Review existing issues before creating new ones

Thank you for contributing! 🚀
