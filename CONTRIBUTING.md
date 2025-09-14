# Contributing & Maintenance Guidelines

This document describes repository-level conventions and maintenance rules
for the `gh-gitops-infra` project. It focuses on how to manage installer
phases, external dependencies (like Gitea), and how to keep the repository
clean and auditable.

1. Phases management
  - The installer is organized in `scripts/fases/` with numbered phases.
  - Phases that represent system-level dependencies (e.g. `kind`, `docker`,
    `gitea`) should be treated as external dependencies and *not* managed by
    the automated phase-runner. This keeps the installer idempotent and
    avoids ordering issues during bootstrap.
  - If a phase is moved to external dependency management, preserve the
    implementation in `scripts/fases/obsolete/` instead of deleting it.

2. Archival policy
  - Files removed from active flows must be moved to `scripts/fases/obsolete/`
    or `obsolete/` top-level directories with a short README explaining why.
  - Avoid deleting files permanently without review; prefer archival to
    preserve history and enable rollback.

3. Scripting best practices
  - All scripts must start with a canonical shebang and robust options:
    `#!/usr/bin/env bash` and `set -euo pipefail` (the project uses `#!/bin/bash`
    in most files — follow existing style consistently).
  - Exported functions should be namespaced (e.g. `fase04_install_argocd()`)
    when they are intended for re-use across scripts.
  - Prefer `kubectl --context` and avoid global side-effects when possible.
  - Provide `--help`/usage output for top-level scripts (`instalar.sh`).

4. Documentation
  - Keep `README.md` authoritative and add high-level instructions in
    `CONTRIBUTING.md` for maintainers about dependency decisions.
  - Document any vendored dependencies clearly (why vendored, version,
    and how to refresh).

5. Git best-practices
  - Add small, focused commits. Do not mix formatting/whitespace-only changes
    with functional changes in the same commit.
  - Use branch + PR workflow for non-trivial changes.

6. Rolling back archived items
  - To restore an archived phase, move the file from
    `scripts/fases/obsolete/` back to `scripts/fases/`, update documentation,
    and run the installer in dry-run mode for verification.

If anything in this file should be stricter or more permissive for your
team, propose a change via PR following the standard workflow.
