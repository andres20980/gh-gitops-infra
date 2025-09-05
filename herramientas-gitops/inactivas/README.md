Esta carpeta contiene las Applications no activas. El App-of-Apps apunta a herramientas-gitops/activas, por lo que ArgoCD solo sincroniza lo que esté aquí activo.

Flujo:
- scripts/herramientas/activar-herramienta.sh <tool> copia desde la raíz a activas/<tool>.yaml y actualiza targetRevision.
- Mantén los values en herramientas-gitops/values-dev y evita valores en línea en las Applications.
