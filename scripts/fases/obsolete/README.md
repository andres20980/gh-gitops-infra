This directory contains archived and obsolete phase scripts moved during cleanup.

Do not execute these files as part of the normal installer. They are preserved
for historical reference only.

Files archived here are safe to inspect but are not used by `instalar.sh`.
This directory contains archived (obsolete) implementations of installation
phases that were intentionally removed from the active installer flow.

Policy:
- Files here are read-only reference implementations. Do not execute them as
  part of the automated installer.
- To restore a file: move it back to `scripts/fases/`, update
  `scripts/comun/configuracion.sh` `FASES_DISPONIBLES`, and update docs.

Current archived items:
- `05-gitea-bootstrap.sh` — preserved bootstrap implementation for Gitea. Gitea
  is now treated as an external system dependency and installed manually on
  the host or via your preferred package manager/container runtime.
