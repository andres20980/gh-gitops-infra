# Directorio de Registros

Este directorio contiene todos los logs del instalador GitOps.

## Estructura de Registros

- `instalador-YYYYMMDD-HHMMSS.log` - Registros principales del instalador
- `docker-YYYYMMDD-HHMMSS.log` - Registros específicos de Docker demonio
- `cluster-FASE-YYYYMMDD-HHMMSS.log` - Registros por fase cuando sea necesario

## Rotación de Registros

Los registros se rotan automáticamente por fecha y se mantienen los últimos 30 días.

## Configuración

- Nivel por defecto: INFO
- Formato: `[TIMESTAMP] LEVEL [COMPONENT] MESSAGE`
- Codificación: UTF-8
- Tamaño máximo: 100MB por archivo

```markdown
# Directorio de Registros (nota de limpieza)

Los marcadores de ejecución de fases fueron archivados en `obsolete/logs/`.

Si necesitas restaurar los archivos originales, copia los ficheros desde
`obsolete/logs/` de vuelta a este directorio.

```
