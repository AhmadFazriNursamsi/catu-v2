# Worklog: Sensio Governance Installation & Hardening

- Date: 2026-09-14
- Scope: repo-wide
- Status: completed

## Objective
Install portable Sensio-equivalent engineering and agent governance into the CATU repository in accordance with `SENSIO_GOVERNANCE_BLUEPRINT.md`.

## Changes
- Replaced outdated root `AGENTS.md` with single canonical operating policy.
- Created nested component invariants `backend/AGENTS.md` and `mobile/AGENTS.md`.
- Created codebase registry `.agents/codebases.conf` declaring `backend`, `mobile`, and `admin-web`.
- Implemented central governance scripts in `.agents/scripts/`:
  - `lib/codebases.sh`: Single registry reader.
  - `engineering-guard.sh`: Component-scoped `fast|full|release` guard dispatcher.
  - `codebase-policy.sh`: Structural policy and sibling script isolation checker.
  - `environment-guard.sh`: Local Docker runtime mutation guard.
  - `maintainability.py`: Closure-only shrink-only maintainability ratchet (350 lines/file, 120 lines/function, 12 files/dir).
  - `validate.sh`: Workspace structure and secret pattern validator.
- Bootstrapped exact shrink-only debt baselines in `.agents/maintainability/` for `backend.json`, `mobile.json`, and `admin-web.json`.
- Configured repository Git hooks under `.githooks/` (`pre-commit` cheap no-op, `pre-push` serial full guards on base branch `main`).

## Behavioral / System Impact
- Routine development remains fast and frictionless with cheap pre-commit and targeted static checks.
- Maintainability debt is locked at current levels and can only shrink going forward.
- Pushes to `main` are protected by automated serial verification across affected components.

## Verification
- Syntax checks passed for all shell and Python governance scripts.
- Workspace validation passed (`validate.sh`).
- Codebase policy passed for all three codebases.
- Maintainability ratchet verified against exact grandfathered baselines.
- Fast engineering guards verified for `backend`, `mobile`, and `admin-web`.
- `git diff --check` passed cleanly with no trailing whitespace or conflicts.

## Decisions
- Grandfathered legacy scripts (`backend/run_stress_test.sh`, `mobile/run_android.sh`, `mobile/run_ios.sh`) to preserve non-destructive adoption.
- Maintained exact grandfathered line counts for legacy files rather than arbitrary blanket allowances.
- Kept GitNexus MCP documentation in `backend/AGENTS.md` alongside Sensio local invariants.

## Documentation Impact
- Root `AGENTS.md` is now the single operating policy for the repository.
- Durable state guidelines documented in `.agents/README.md`.

## Reusable Learnings
- Container-hosted Node modules can be synced cleanly to host via Docker CLI for instant local tooling availability.
- Shrink-only maintainability allows strict enforcement on new code without blocking pre-existing functional legacy code.

## Follow-ups / Known Issues
- Future refactoring tasks should systematically reduce oversized files in `mobile/` and `backend/` to shrink baselines downward.
