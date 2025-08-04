# 🛡️ Política de Seguridad

## 🔍 Versiones Soportadas

| Versión | Soporte de Seguridad |
| ------- | ------------------- |
| 2.x.x   | ✅ Soporte completo |
| 1.x.x   | ⚠️ Parches críticos únicamente |
| < 1.0   | ❌ Sin soporte |

## 🚨 Reportar Vulnerabilidades de Seguridad

Si encuentras una vulnerabilidad de seguridad, por favor **NO** la reportes públicamente. En su lugar:

### 📧 Contacto Seguro
- **Email**: security@example.com (reemplazar con email real)
- **Asunto**: `[VULNERABILIDAD] Infraestructura GitOps - Descripción breve`
- **Tiempo de respuesta**: 48 horas máximo

### 📝 Información a Incluir
1. **Descripción detallada** de la vulnerabilidad
2. **Pasos para reproducir** el problema
3. **Impacto potencial** y severidad estimada
4. **Versión afectada** del software
5. **Entorno de prueba** utilizado

### 🕐 Proceso de Resolución
1. **Confirmación** (48h): Confirmamos recepción y validamos la vulnerabilidad
2. **Evaluación** (7 días): Analizamos el impacto y desarrollamos solución
3. **Parche** (14 días): Implementamos y probamos la corrección
4. **Release** (21 días): Publicamos la versión corregida
5. **Divulgación** (30 días): Divulgación pública coordinada

## 🔒 Mejores Prácticas de Seguridad

### Para Usuarios
- ✅ Mantén siempre la **última versión** del software
- ✅ Configura **RBAC** apropiado en tu cluster Kubernetes
- ✅ Usa **secrets** nativos de Kubernetes, nunca hardcodees credenciales
- ✅ Habilita **TLS** en todas las comunicaciones
- ✅ Configura **network policies** restrictivas
- ✅ Revisa regularmente los **logs** de auditoría

### Para Desarrolladores
- ✅ Nunca incluyas **credenciales** en el código fuente
- ✅ Usa **variables de entorno** para configuración sensible
- ✅ Implementa **validación de entrada** en todos los scripts
- ✅ Configura **linting** de seguridad (ShellCheck, etc.)
- ✅ Realiza **revisiones de código** obligatorias
- ✅ Mantén las **dependencias** actualizadas

## 🛠️ Herramientas de Seguridad Incluidas

| Herramienta | Propósito | Estado |
|-------------|-----------|--------|
| **Cert-Manager** | Gestión automática de certificados TLS | ✅ Incluido |
| **External Secrets** | Gestión segura de secretos externos | ✅ Incluido |
| **RBAC** | Control de acceso basado en roles | ✅ Configurado |
| **Network Policies** | Políticas de red de Kubernetes | ⚠️ Manual |
| **Pod Security Standards** | Estándares de seguridad de pods | ⚠️ Manual |

## 🔐 Configuración de Seguridad

### Secrets Management
```bash
# Usar External Secrets para gestión segura
kubectl apply -f herramientas-gitops/external-secrets.yaml

# Verificar configuración RBAC
kubectl auth can-i --list --as=system:serviceaccount:default:argocd-server
```

### TLS Configuration
```bash
# Verificar certificados TLS
kubectl get certificates -n argocd
kubectl describe certificate argocd-server-tls -n argocd
```

## 📞 Contacto

Para cuestiones de seguridad no críticas:
- **Issues**: [GitHub Issues](https://github.com/asanchez-dev/gh-gitops-infra/issues)
- **Discussions**: [GitHub Discussions](https://github.com/asanchez-dev/gh-gitops-infra/discussions)

---

> **Nota**: Esta política de seguridad se actualiza regularmente. Última actualización: Enero 2024.