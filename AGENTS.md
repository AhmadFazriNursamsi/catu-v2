# CATU Operating Policy — Agent & Engineering Governance

This document is the **single current operating policy** for development agents and engineers working in the CATU repository. Historical plans, memory logs, skills, external notes, and blueprints provide context, but must never override this document.

---

## 1. Canonical Agent Lifecycle

Every task must follow this serial execution lifecycle:

1. **Inspect before mutating**: Check `git status` and minimal relevant source/documentation before editing. Never assume repo state.
2. **Consult active plan only when present**: Read an existing task plan in `.agents/plans/` only if one exists for the current work; do not reread unrelated history.
3. **Minimal coherent change**: Make targeted, minimal edits. Never modify, discard, or format unrelated dirty files in the worktree.
4. **Fast, targeted validation**: During implementation, run only targeted checks covering the edit. Do not run broad repo-wide gates or closure checks during trial-and-error.
5. **Durable state hygiene**: Update plans, worklogs, knowledge, or documentation only when behavior, architecture, or policy materially changes.
6. **Clean staging**: Stage only task-owned files. Never use `git add -A` or wildcard staging in a dirty worktree.
7. **Compact reporting**: Report what changed, what was verified, and any genuine remaining risks or blockers.

---

## 2. Working and Safety Boundaries

- **Development boundary**: Agents operate in local development environments only. Production deployments, database migrations against live production, domain/DNS changes, or credential rotations require explicit human direction.
- **Git safety**:
  - Base branch is `main`.
  - Never run destructive Git commands (`git reset --hard`, `git clean -fd`, `git checkout -- .`) without explicit instruction.
  - Never use `git push --force`.
  - Never stage or commit credentials, API keys, private keys, or `.env` files.
  - Pre-commit hook is intentionally cheap/no-op to preserve a fast feedback loop.
  - Pre-push hook enforces serial `full` engineering guards on affected codebases when pushing to `main`.
- **Runtime safety**:
  - Backend authoritative runtime is local Docker Compose (`catu_backend`, `catu_postgres`) on ports 3005 and 5432.
  - Mobile client communicates with local API endpoints (`127.0.0.1:3005`, `10.0.10.92:3005`).
  - Do not introduce arbitrary network restrictions that break legitimate local HTTP/IP development connectivity.

---

## 3. Codebase-Serial Workflow

The repository contains distinct codebases governed through `.agents/codebases.conf`:
1. `backend` (`backend/`, `node-backend`)
2. `mobile` (`mobile/`, `flutter`)
3. `admin-web` (`admin_web/`, `generic`)

**Serial rule**: Work on exactly one codebase at a time in canonical registry order (`backend` → `mobile` → `admin-web`). Never parallelize sibling frontend/backend changes with subagents or background jobs.

---

## 4. Testing Policy (Boundary-First Model)

- **Default rule**: Do not create or restore new permanent **isolated unit tests** with mocked/stubbed boundaries by default.
- **Allowed permanent tests**: Integration, E2E, API contract, smoke, and regression tests that exercise real component/system boundaries are preferred.
- **Legacy tests**: Existing unit tests in the repository are grandfathered and must not be deleted merely to satisfy this policy.
- **Temporary tests**: Disposable unit tests created for local debugging must be deleted before task closure, staging, or committing.

---

## 5. Engineering Guard Lifecycle

Execute quality guards using the single canonical interface:

```bash
./.agents/scripts/engineering-guard.sh <codebase> <fast|full|release>
```

- **`fast`** (Closure/checkpoint verification):
  - Runs structural `codebase-policy.sh <codebase>`.
  - Runs stack static check (TypeScript check for `backend`, Flutter static analysis for `mobile`).
  - Keep fast checks cheap; never include maintainability.
- **`full`** (Pre-push / comprehensive verification):
  - Runs `fast` first, then builds artifacts and runs applicable integration/boundary tests.
- **`release`** (Explicit release validation only):
  - Runs `full` first, then packages production container or mobile distribution bundle.

---

## 6. Maintainability Ratchet (Closure-Only)

Maintainability is a **closure-only** gate executed when implementation is finished:

```bash
python3 .agents/scripts/maintainability.py <codebase>
```

- **Hard limits**:
  - Maximum source file lines: **350**
  - Maximum function/method lines: **120**
  - Maximum code files per directory: **12**
  - New lint/type bypass directives: **0**
- **Shrink-only rule**: Existing legacy debt is recorded in `.agents/maintainability/<codebase>.json`. No new debt or regressions are permitted. When code is improved, the baseline must be lowered accordingly.
- Never run maintainability during routine development or pre-commit.

---

## 7. Explicit Closure Protocol

When a task, PR, or branch is ready for closure:

1. Confirm implementation is complete.
2. For each changed codebase serially in registry order:
   - Run `./.agents/scripts/engineering-guard.sh <codebase> fast`.
   - Remove all temporary tests/scratch files.
   - Run `python3 .agents/scripts/maintainability.py <codebase>` exactly once.
3. Verify agent workspace integrity: `./.agents/scripts/validate.sh`.
4. Stage only task-owned files and commit with Conventional Commits.
5. Report changes, verification evidence, and commit hash.
