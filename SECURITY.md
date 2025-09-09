# Política de Seguridad

## Versiones Soportadas

Actualmente damos soporte de seguridad a las siguientes versiones de la infraestructura GitOps:

| Versión | Soportada          |
| ------- | ------------------ |
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| 1.5.x   | :x:                |
| < 1.5   | :x:                |

## Componentes Críticos de Seguridad

### 🔒 Componentes con Implicaciones de Seguridad
- **ArgoCD v3.0.12**: Gestión centralizada de despliegues
- **Kargo v1.6.2**: Promoción automatizada entre entornos (SUPER IMPORTANTE)
- **External Secrets v0.18.2**: Gestión de secretos de fuentes externas
- **Cert-Manager v1.18.2**: Gestión automática de certificados TLS
- **NGINX Ingress v4.13.0**: Punto de entrada del tráfico
- **Gitea v12.1.2**: Repositorio Git interno

### ⚠️ Consideraciones de Seguridad por Entorno

#### Entorno de Desarrollo/Pruebas
- **Credenciales por defecto**: Se usan credenciales conocidas (`admin`/`admin123`)
- **Recursos limitados**: Configuración optimizada para desarrollo, no para producción
- **Logs verbosos**: Mayor nivel de logging para depuración
- **Sin cifrado de extremo a extremo**: Configuraciones simplificadas para testing

#### Migración a Producción
Antes de llevar esta configuración a producción, es CRÍTICO:
1. Cambiar todas las credenciales por defecto
2. Implementar secretos seguros con External Secrets
3. Configurar certificados TLS válidos
4. Revisar y endurecer todas las configuraciones de seguridad
5. Implementar políticas de red adecuadas

## Reportar una Vulnerabilidad de Seguridad

### 🚨 Proceso de Reporte

Si descubres una vulnerabilidad de seguridad en esta infraestructura GitOps, por favor:

1. **NO abras un issue público** - Las vulnerabilidades de seguridad deben reportarse de forma privada
2. **Envía un email a**: [andres20980@users.noreply.github.com]
3. **Incluye la siguiente información**:
   - Descripción detallada de la vulnerabilidad
   - Pasos para reproducir el problema
   - Impacto potencial de la vulnerabilidad
   - Componente(s) afectado(s)
   - Versión(es) afectada(s)

### 📋 Información a Incluir

Por favor, incluye tanto detalle como sea posible:

```
Componente: [ArgoCD/Kargo/External-Secrets/etc.]
Versión: [versión específica]
Severidad: [Crítica/Alta/Media/Baja]
Tipo: [Autenticación/Autorización/Inyección/XSS/etc.]

Descripción:
[Descripción detallada del problema]

Pasos para reproducir:
1. [Paso 1]
2. [Paso 2]
3. [Paso 3]

Impacto:
[Qué puede hacer un atacante con esta vulnerabilidad]

Evidencia:
[Screenshots, logs, o evidencia adicional]
```

### ⏱️ Tiempos de Respuesta

Nos comprometemos a responder a los reportes de seguridad según la siguiente tabla:

| Severidad | Tiempo de Respuesta | Tiempo de Resolución |
|-----------|--------------------|--------------------|
| Crítica   | 24 horas           | 7 días             |
| Alta      | 48 horas           | 14 días            |
| Media     | 5 días             | 30 días            |
| Baja      | 10 días            | 60 días            |

### 🏆 Reconocimiento

Si reportas una vulnerabilidad válida:
- Te reconoceremos en el CHANGELOG.md (si lo deseas)
- Incluiremos tu nombre en el apartado de agradecimientos
- Te notificaremos cuando la vulnerabilidad esté resuelta

## Mejores Prácticas de Seguridad

### 🛡️ Para Usuarios del Proyecto

1. **Credenciales**: Cambia TODAS las credenciales por defecto antes de uso en producción
2. **Red**: Implementa políticas de red restrictivas (NetworkPolicies)
3. **Secrets**: Usa External Secrets para gestión segura de secretos
4. **Certificados**: Implementa cert-manager con ACME para certificados automáticos
5. **RBAC**: Revisa y endurece todas las configuraciones RBAC
6. **Registros**: Implementa registro centralizado con Loki para auditoría
7. **Monitorización**: Usa Prometheus/Grafana para detectar anomalías

### 🔧 Configuraciones Recomendadas

#### ArgoCD
```yaml
# Configuración de seguridad recomendada
configs:
  params:
    server.insecure: false
    server.rootpath: /argocd
    server.grpc.web: true
```

#### Kargo (SUPER IMPORTANTE)
```yaml
# Configuración de seguridad para Kargo
api:
  adminAccount:
    passwordHash: [hash-bcrypt-seguro]
    tokenSigningKey: [clave-256-bits-segura]
```

#### NGINX Ingress
```yaml
# Configuraciones de seguridad recomendadas
controller:
  config:
    ssl-redirect: "true"
    force-ssl-redirect: "true"
    hsts: "true"
    hsts-max-age: "31536000"
```

## Vulnerabilidades Conocidas

### 🔍 Estado Actual
- **Sin vulnerabilidades críticas conocidas** en la versión 2.1.0
- Todas las dependencias actualizadas a versiones estables
- Configuraciones de desarrollo no aptas para producción

### 📚 Recursos Adicionales

- [OWASP Kubernetes Security Hoja de Referencia Rápida](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [CIS Kubernetes Evaluación Comparativa](https://www.cisecurity.org/benchmark/kubernetes)
- [Kubernetes Security Mejores Prácticas](https://kubernetes.io/docs/concepts/security/)
- [ArgoCD Documentación de Seguridad](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)

## Contacto

Para cualquier consulta relacionada con seguridad:
- **Email de seguridad**: [andres20980@users.noreply.github.com]
- **Issues generales**: [Repositorio GitHub](https://github.com/andres20980/gh-gitops-infra/issues)
- **Documentación**: Consulta README.md y CONTRIBUTING.md

---

**⚠️ IMPORTANTE**: Este proyecto está configurado para entornos de desarrollo/pruebas. No usar en producción sin las modificaciones de seguridad correspondientes.
