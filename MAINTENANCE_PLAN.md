Repository cleanup and maintenance plan
=====================================

Summary of actions performed
----------------------------
- Phase 05 (Gitea bootstrap) was archived and documented as an external
  dependency. Active script replaced with a small stub that exits early and
  points to `scripts/fases/obsolete/05-gitea-bootstrap.sh`.
- Added `CONTRIBUTING.md` with policy for dependencies and archival procedures.
- Added `scripts/fases/obsolete/README.md` and preserved the original script.
- Updated `scripts/comun/configuracion.sh`, `scripts/comun/helpers/instalador-helper.sh`,
  and `README.md` to remove `fase-05` from active lists and examples.
- Added GitHub Actions workflow to run `shellcheck` on `*.sh` files.

Recommended follow-up items
---------------------------
1. Run `shellcheck` and fix warnings (use the workflow or run locally):

   ```bash
   sudo apt-get install shellcheck
   find . -type f -name '*.sh' -print0 | xargs -0 shellcheck
   ```

2. Review `scripts/fases/00-reset.sh` and other reset helpers for destructive
   commands (`rm -rf /var/lib/docker`, etc.). Document `--deep-nuke` clearly
   in `README.md` and require confirmation before destructive ops.

3. Consider adding a simple `Makefile` target for linting and tests:

   ```makefile
   .PHONY: lint
   lint:
       shellcheck $(shell find . -type f -name '*.sh')
   ```

4. Review `README.md` and `CONTRIBUTING.md` together to ensure the project's
   policy for external dependencies (Gitea) is clear to contributors.

5. If there are vendored charts or large binaries (search for `vendor/`),
   archive them in an external storage or a `vendor/` policy document.

6. Create a PR for these changes and run CI (this will exercise the new
   `shellcheck` workflow).

Conservative cleanup candidates (already acted on):
- `scripts/fases/05-gitea-bootstrap.sh` (archived to `scripts/fases/obsolete/`)

If you want, I can now:
- run `shellcheck` locally and fix common issues,
- further archive other obsolete files (create `obsolete/` top-level),
- or create the commit and push it to `main` (I can push changes if you permit).
