# Anti-Patrones de Argo CD en GitOps

Este documento resume los anti-patrones comunes a evitar al implementar Argo CD en un entorno GitOps, basados en las mejores prácticas de la industria.

## 1. No Separar los Repositorios Git

**Descripción:** Mantener el código fuente de las aplicaciones, los manifiestos de Kubernetes y las definiciones de Argo CD (Applications, ApplicationSets) en un único repositorio Git.

**Impacto:**
*   Aumento del tamaño del repositorio, lo que ralentiza las operaciones de clonación y sincronización.
*   Complicaciones en la gestión de permisos granulares.
*   Ejecuciones innecesarias en los pipelines de CI/CD debido a cambios en partes no relacionadas del repositorio.
*   Falta de una clara separación de responsabilidades entre el desarrollo de aplicaciones, la configuración de Kubernetes y la orquestación de GitOps.

**Mejor Práctica:** Utilizar un enfoque de múltiples repositorios, donde:
*   Cada aplicación tiene su propio repositorio para el código fuente y los manifiestos de Kubernetes.
*   La infraestructura y las herramientas tienen un repositorio dedicado.
*   Las configuraciones de Argo CD (Applications, ApplicationSets) residen en un repositorio de "plano de control" o "GitOps" separado.

## 2. Deshabilitar la Sincronización Automática y la Auto-Reparación

**Descripción:** Configurar las aplicaciones de Argo CD para que no sincronicen automáticamente los cambios desde Git o no reparen la deriva de configuración en el clúster.

**Impacto:**
*   Se pierde uno de los principales beneficios de GitOps: la garantía de que el estado del clúster siempre coincide con el estado declarado en Git.
*   Introduce la "deriva de configuración" (configuration drift), donde el estado real del clúster difiere del estado deseado en Git.
*   Requiere intervención manual para aplicar cambios o corregir el estado del clúster.

**Mejor Práctica:** Mantener `automated: prune: true` y `selfHeal: true` habilitados en la `syncPolicy` de las aplicaciones de Argo CD.

## 3. Hardcodear Datos de Helm o Kustomize en Aplicaciones de Argo CD

**Descripción:** Incrustar directamente valores de Helm, parches de Kustomize o configuraciones complejas dentro de las definiciones de `Application` o `ApplicationSet` de Argo CD.

**Impacto:**
*   Mezcla las preocupaciones de la orquestación de Argo CD con la configuración de las aplicaciones, dificultando el mantenimiento y la comprensión.
*   Reduce la reutilización de las definiciones de aplicaciones.
*   Hace que las actualizaciones de valores o parches sean más complejas, ya que requieren modificar las definiciones de Argo CD en lugar de los archivos de configuración de Helm/Kustomize.

**Mejor Práctica:** Mantener los valores de Helm y los parches de Kustomize en sus respectivos archivos de configuración (por ejemplo, `values.yaml`, `kustomization.yaml`) y referenciarlos desde las definiciones de Argo CD.

## 4. Intentar Versionar Aplicaciones o Application Sets

**Descripción:** Tratar las definiciones de `Application` o `ApplicationSet` de Argo CD como entidades que necesitan ser versionadas y modificadas continuamente en Git para cada despliegue o cambio de aplicación.

**Impacto:**
*   Introduce complejidad innecesaria y sobrecarga en la gestión de versiones.
*   Contradice la naturaleza declarativa de Argo CD, donde las definiciones de aplicaciones deben ser estables y reflejar el estado deseado.

**Mejor Práctica:** Las definiciones de `Application` y `ApplicationSet` deben ser estables y declarativas, creadas una vez y solo modificadas cuando la estructura fundamental de la aplicación o su gestión en Argo CD cambie. Los cambios en las aplicaciones subyacentes (versiones de imágenes, configuraciones) deben gestionarse a través de los manifiestos de Kubernetes o los valores de Helm/Kustomize referenciados por Argo CD.

## 5. No Entender la Configuración Declarativa de Argo CD

**Descripción:** Crear o modificar aplicaciones de Argo CD manualmente a través de la UI o la CLI, en lugar de definirlas y gestionarlas exclusivamente en Git.

**Impacto:**
*   Introduce la "deriva de configuración" y rompe el principio fundamental de GitOps de "Git como fuente única de verdad".
*   Dificulta la auditoría, la reversión y la automatización del proceso de despliegue.

**Mejor Práctica:** Todas las definiciones de Argo CD (Applications, ApplicationSets, Projects) deben ser declarativas y residir en un repositorio Git. Cualquier cambio debe realizarse a través de un commit en Git.

## 6. Asumir que los Desarrolladores Necesitan Conocer Argo CD

**Descripción:** Diseñar el flujo de trabajo de tal manera que los desarrolladores necesiten interactuar directamente con Argo CD o entender sus configuraciones internas para desplegar o gestionar sus aplicaciones.

**Impacto:**
*   Aumenta la curva de aprendizaje para los desarrolladores y los distrae de su enfoque principal (el desarrollo de software).
*   Introduce una dependencia innecesaria en la herramienta de CD, en lugar de centrarse en los manifiestos de Kubernetes como la interfaz principal.

**Mejor Práctica:** Separar claramente las configuraciones de Kubernetes (que los desarrolladores gestionan) de las configuraciones de Argo CD (que el equipo de operaciones gestiona). Los desarrolladores deben poder trabajar con sus manifiestos de Kubernetes localmente sin necesidad de Argo CD.

## 7. Abusar de las Características de Argo CD (Multi-Fuente, Sobrescritura de Parámetros)

**Descripción:** Utilizar en exceso o de forma inadecuada características avanzadas de Argo CD como las fuentes múltiples (`multi-source`) para agrupar aplicaciones no relacionadas, o la sobrescritura de parámetros (`parameter overrides`) para gestionar configuraciones que deberían estar en los manifiestos de la aplicación.

**Impacto:**
*   Introduce complejidad innecesaria en las definiciones de Argo CD.
*   Dificulta la depuración y el mantenimiento.
*   Puede llevar a una arquitectura menos clara y más difícil de escalar.

**Mejor Práctica:** Utilizar las características avanzadas de Argo CD con moderación y solo cuando sea estrictamente necesario. Priorizar la claridad y la simplicidad en las definiciones de aplicaciones. Para agrupar aplicaciones relacionadas, el patrón App-of-Apps es generalmente preferible.
