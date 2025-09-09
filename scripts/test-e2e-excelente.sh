#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[E2E] 1/3 Limpieza del entorno"
"$ROOT_DIR/scripts/reset-entorno.sh"

echo "[E2E] 2/3 Instalación modo 'excelente'"
"$ROOT_DIR/instalar.sh" excelente

echo "[E2E] 3/3 Validación final (fase-07)"
"$ROOT_DIR/instalar.sh" fase-07

echo "[E2E] ✓ Prueba E2E completada"

