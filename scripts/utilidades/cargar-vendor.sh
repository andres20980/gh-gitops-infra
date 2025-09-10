#!/usr/bin/env bash
set -euo pipefail

# Carga charts vendorizados en charts/vendor/ desde un archivo (zip/tgz) o directorio local.
# Uso:
#   scripts/utilidades/cargar-vendor.sh --from-zip /ruta/vendor-pack.tgz
#   scripts/utilidades/cargar-vendor.sh --from-zip /ruta/vendor-pack.zip
#   scripts/utilidades/cargar-vendor.sh --from-dir /ruta/directorio_con_charts

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
VENDOR_DIR="$ROOT_DIR/charts/vendor"
SRC=""; MODE=""

usage(){
  echo "Uso: $0 --from-zip <archivo.zip|.tgz|.tar.gz> | --from-dir <directorio>" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-zip) MODE="zip"; SRC="$2"; shift 2 ;;
    --from-dir) MODE="dir"; SRC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$MODE" && -n "$SRC" ]] || { usage; exit 1; }

mkdir -p "$VENDOR_DIR"

case "$MODE" in
  zip)
    [[ -f "$SRC" ]] || { echo "❌ Archivo no encontrado: $SRC" >&2; exit 1; }
    case "$SRC" in
      *.zip) unzip -o "$SRC" -d "$VENDOR_DIR" >/dev/null ;;
      *.tgz|*.tar.gz) tar -xzf "$SRC" -C "$VENDOR_DIR" ;;
      *) echo "❌ Formato no soportado: $SRC" >&2; exit 1 ;;
    esac
    ;;
  dir)
    [[ -d "$SRC" ]] || { echo "❌ Directorio no encontrado: $SRC" >&2; exit 1; }
    rsync -a "$SRC/" "$VENDOR_DIR/" >/dev/null 2>&1 || cp -R "$SRC/"* "$VENDOR_DIR/" 2>/dev/null || true
    ;;
esac

# Normalizar estructura y verificar charts requeridos
if [[ -x "$ROOT_DIR/scripts/utilidades/vendor-charts.sh" ]]; then
  "$ROOT_DIR/scripts/utilidades/vendor-charts.sh"
fi

echo "✅ Charts vendorizados cargados en $VENDOR_DIR"

