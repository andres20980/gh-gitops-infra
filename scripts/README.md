# Scripts de Gestión GitOps

Esta carpeta contiene scripts de utilidad para la gestión y mantenimiento de la infraestructura GitOps.

## 📋 Scripts Disponibles

### 🚀 `deploy-with-dependencies.sh`
Despliega aplicaciones respetando las dependencias entre componentes.

**Uso:**
```bash
./scripts/deploy-with-dependencies.sh [aplicacion]
```

**Funcionalidad:**
- Verifica dependencias antes del despliegue
- Garantiza orden correcto de instalación
- Manejo de errores y rollback automático

### 🔍 `diagnostico-gitops.sh`
Ejecuta un diagnóstico completo del estado de la infraestructura GitOps.

**Uso:**
```bash
./scripts/diagnostico-gitops.sh
```

**Verifica:**
- Estado de todas las aplicaciones ArgoCD
- Conectividad entre componentes
- Recursos disponibles en el cluster
- Configuraciones críticas

### 🔧 `fix-chart-versions.sh`
Corrige y actualiza las versiones de los charts Helm automáticamente.

**Uso:**
```bash
./scripts/fix-chart-versions.sh
```

**Funciones:**
- Detecta versiones desactualizadas
- Actualiza a versiones estables más recientes
- Valida compatibilidad entre componentes
- Genera backup antes de cambios

### 🌐 `setup-port-forwards.sh`
Configura port-forwards para acceder a las interfaces web de todos los componentes.

**Uso:**
```bash
./scripts/setup-port-forwards.sh
```

**Puertos configurados:**
- ArgoCD: `http://localhost:8080`
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Kargo: `http://localhost:8081` (SUPER IMPORTANTE)
- Jaeger: `http://localhost:16686`
- Y otros componentes...

### 🔄 `sync-all-apps.sh`
Sincroniza todas las aplicaciones ArgoCD de forma ordenada.

**Uso:**
```bash
./scripts/sync-all-apps.sh [--force]
```

**Opciones:**
- `--force`: Fuerza la sincronización incluso con conflictos
- Sin parámetros: Sincronización estándar respetando políticas

## 🛠️ Uso Común

### Instalación Completa
```bash
# 1. Instalar toda la infraestructura
./instalar-todo.sh

# 2. Verificar estado
./scripts/diagnostico-gitops.sh

# 3. Configurar accesos web
./scripts/setup-port-forwards.sh
```

### Mantenimiento Diario
```bash
# Verificar estado
./scripts/diagnostico-gitops.sh

# Sincronizar si es necesario
./scripts/sync-all-apps.sh

# Actualizar versiones si hay disponibles
./scripts/fix-chart-versions.sh
```

### Resolución de Problemas
```bash
# 1. Diagnóstico completo
./scripts/diagnostico-gitops.sh

# 2. Sincronización forzada si es necesario
./scripts/sync-all-apps.sh --force

# 3. Verificar con port-forwards
./scripts/setup-port-forwards.sh
```

## 📝 Notas Importantes

### Permisos
Todos los scripts requieren permisos de ejecución:
```bash
chmod +x scripts/*.sh
```

### Dependencias
Los scripts asumen que tienes instalado:
- `kubectl` configurado correctamente
- `helm` (para algunos scripts)
- `jq` (para procesamiento JSON)
- `curl` (para verificaciones HTTP)

### Variables de Entorno
Algunos scripts pueden usar estas variables:
```bash
export KUBECONFIG=/path/to/your/kubeconfig
export ARGOCD_NAMESPACE=argocd
export KARGO_NAMESPACE=kargo-system
```

## 🔒 Seguridad

### Credenciales
Los scripts pueden mostrar información sensible. En entornos de producción:
- Revisa logs antes de compartir
- No ejecutes con logging verbose en entornos compartidos
- Usa credenciales específicas por entorno

### Ejecución
- Ejecuta siempre desde la raíz del proyecto
- Verifica el contexto de kubectl antes de ejecutar
- Usa `--dry-run` cuando esté disponible para validar cambios

## 🐛 Resolución de Problemas

### Errores Comunes

**Error: "kubectl not found"**
```bash
# Instalar kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**Error: "No context configured"**
```bash
# Verificar contexto
kubectl config current-context

# Configurar si es necesario
kubectl config use-context [tu-contexto]
```

**Error: "Permission denied"**
```bash
# Dar permisos de ejecución
chmod +x scripts/*.sh
```

### Logs y Debug
Para debug detallado, ejecuta los scripts con:
```bash
bash -x scripts/[script-name].sh
```

## 📚 Documentación Adicional

- [README.md principal](../README.md) - Documentación completa del proyecto
- [STATUS.md](../STATUS.md) - Estado actual de componentes
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Guía de contribución
- [CHANGELOG.md](../CHANGELOG.md) - Historial de cambios

---

**💡 Tip**: Para un uso eficiente, crea aliases para los scripts más usados:
```bash
alias gitops-diag='./scripts/diagnostico-gitops.sh'
alias gitops-sync='./scripts/sync-all-apps.sh'
alias gitops-ports='./scripts/setup-port-forwards.sh'
```
