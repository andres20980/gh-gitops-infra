Esta carpeta contiene las Applications no activas. El App-of-Apps apunta a herramientas-gitops/active, por lo que ArgoCD solo sincroniza lo que esté aquí activo.

Flujo:
- scripts/tools/activate-tool.sh <tool> copia desde la raíz a active/<tool>.yaml y actualiza targetRevision.
- Mantén los values en herramientas-gitops/values-dev y evita valores inline en las Applications.
