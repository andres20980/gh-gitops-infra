# Logs Directory

Este directorio contiene todos los logs del instalador GitOps.

## Estructura de Logs

- `instalador-YYYYMMDD-HHMMSS.log` - Logs principales del instalador
- `docker-YYYYMMDD-HHMMSS.log` - Logs específicos de Docker daemon
- `cluster-FASE-YYYYMMDD-HHMMSS.log` - Logs por fase cuando sea necesario

## Rotación de Logs

Los logs se rotan automáticamente por fecha y se mantienen los últimos 30 días.

## Configuración

- Nivel por defecto: INFO
- Formato: `[TIMESTAMP] LEVEL [COMPONENT] MESSAGE`
- Encoding: UTF-8
- Max size: 100MB por archivo
