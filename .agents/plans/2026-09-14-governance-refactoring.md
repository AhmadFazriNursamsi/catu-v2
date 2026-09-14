# Plan: Governance Alignment & Modular Refactoring

- Created: 2026-09-14
- Status: completed
- Scope: backend, mobile

## Goal
Align codebase implementation with Sensio Governance standards:
1. Hardening backend with production security (Helmet, Throttler rate limiting, Health check probe).
2. Refactor monolith `backend/src/app.controller.ts` (5,385 lines) into clean modular controllers/services.
3. Lower maintainability debt baseline in `.agents/maintainability/backend.json` following shrink-only ratchet.
4. Clean mobile code analysis warnings and oversized files where practical.

## Constraints / Safety Boundaries
- Serial execution: finish `backend` completely before touching `mobile`.
- Non-breaking changes: preserve all existing REST API contracts, routes, and JSON schemas.
- Non-destructive: ensure PostgreSQL database queries and docker container continue running cleanly.
- Verify through `./.agents/scripts/engineering-guard.sh <codebase> fast` and `maintainability.py`.

## Milestones
- [x] Milestone 1 (Backend Quick Wins): Install and enable Helmet, Throttler rate limiting, and `/health` probe.
- [x] Milestone 2 (Backend Modularization): Split `app.controller.ts` into discrete controller files (`auth.controller.ts`, `orders.controller.ts`, `chat.controller.ts`, `notifications.controller.ts`, `assignments.controller.ts`, `test-runner.controller.ts`, `master-data.controller.ts`).
- [x] Milestone 3 (Backend Verification & Baseline Shrink): Re-test endpoints, run fast guard, lower `backend.json` baseline.
- [x] Milestone 4 (Mobile Cleanup): Clean unused imports, deprecations, async gaps, and avoid_print warnings; add real unit/widget tests; satisfy mobile maintainability ratchet.

## Acceptance Criteria
- [x] `curl -s http://127.0.0.1:3005/health` returns `{"status":"ok"}` with DB check.
- [x] Rate limiter configured with ThrottlerGuard on HTTP routes.
- [x] `engineering-guard.sh backend fast` and `full` pass.
- [x] `maintainability.py backend` passes with reduced line counts.
- [x] `engineering-guard.sh mobile fast` and `full` pass.
- [x] `flutter analyze` reports 0 issues (down from 205).
- [x] `flutter test` passes all tests.
- [x] `maintainability.py mobile` passes with shrink-only ratchet locked in.
- [x] Docker container restarts and operates without errors.

## Findings / Checkpoints
- Monolithic `app.controller.ts` was 5,385 lines. Successfully decomposed into 7 dedicated controller modules under `backend/src/modules/` and a 7-line barrel export.
- Mobile static analysis issues dropped from 205 to 0.
- All deprecations (e.g. `scrollCacheExtent`) and potential async runtime bugs (`use_build_context_synchronously`) eliminated.

## Outcome
Refactoring completed and verified under full Sensio governance engineering guards and shrink-only maintainability ratchets across both `backend` and `mobile` codebases.
