#!/bin/bash

# Archived duplicate of 06-aplicaciones.sh. Canonical file is scripts/fases/05-aplicaciones.sh

cat <<'EOF'
This is an archived duplicate of '06-aplicaciones.sh'. Use 'scripts/fases/05-aplicaciones.sh'.
EOF

exit 0
#!/bin/bash

#!/bin/bash

# ============================================================================
# FASE 6: DESPLIEGUE DE APLICACIONES (archived copy)
# ============================================================================
# Preserved copy of the original `06-aplicaciones.sh` before renaming to
# `fase-05-aplicaciones.sh`. Kept for history and manual inspection.
# ============================================================================

set -euo pipefail

readonly APLICACIONES_DIR="${PROJECT_ROOT}/aplicaciones"

main() {
    echo "(archived) FASE 6: Despliegue de Aplicaciones"
    if [[ -f "$APLICACIONES_DIR/conjunto-aplicaciones.yaml" ]]; then
        echo "Would apply: $APLICACIONES_DIR/conjunto-aplicaciones.yaml"
    else
        echo "ApplicationSet not found"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
