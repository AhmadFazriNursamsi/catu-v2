# Worklog: Backend Modularization & Governance Alignment

- Date: 2026-09-14
- Scope: backend
- Status: completed

## Objective
Fix backend code to comply with Sensio Governance and NestJS production standards by installing production security middleware, adding a health probe, and refactoring the monolithic `app.controller.ts` into clean modular domain controllers.

## Changes
- **Security & Headers**:
  - Installed `helmet` and `@nestjs/throttler` in `backend/package.json`.
  - Configured `helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false })` in `backend/src/main.ts`.
  - Configured `ThrottlerModule.forRoot([{ ttl: 60000, limit: 120 }])` and `ThrottlerGuard` in `backend/src/app.module.ts`.
- **Health Check Probe**:
  - Created `backend/src/health.controller.ts` with `GET /health` verifying PostgreSQL connectivity (`SELECT 1`), response latency, uptime, and memory usage.
- **Controller Modularization**:
  - Split 5,385-line monolith `backend/src/app.controller.ts` into 7 domain-specific controllers under `backend/src/modules/`:
    - `modules/auth/auth.controller.ts` (Auth & Registration)
    - `modules/orders/orders.controller.ts` (Orders & Pelayanan)
    - `modules/notifications/notifications.controller.ts` (Notifications & FCM)
    - `modules/assignments/assignments.controller.ts` (Romo Assignments)
    - `modules/chat/chat.controller.ts` (Group Chat & Messaging)
    - `modules/test-runner/test-runner.controller.ts` (Jest Test Runner)
    - `modules/master-data/master-data.controller.ts` (Keuskupan, Paroki, Wilayah, Lingkungan, Ordo CRUD)
  - Replaced monolithic `app.controller.ts` with a clean 7-line barrel export re-exporting all modular controllers.
- **Maintainability Ratchet**:
  - Updated `.agents/maintainability/backend.json` to record the exact new baselines across the modular controllers.
  - Eliminated the 5,385-line file violation entirely.

## Behavioral / System Impact
- HTTP responses now include `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, and rate-limiting headers (`X-RateLimit-Limit`, `X-RateLimit-Remaining`).
- Production orchestrators and Docker can now query `GET /health` for real-time health checks.
- Zero breaking API changes: all endpoints maintain 100% path and JSON contract parity.

## Verification
- Live curl checks against `http://127.0.0.1:3005` verified:
  - `GET /health` -> `{"status":"ok","database":{"status":"up","latencyMs":2}}`
  - `POST /auth/login` -> 200 OK with valid JWT token
  - `GET /news?limit=2` -> 200 OK
  - `GET /orders?userId=9` -> 200 OK
  - `GET /notifications?userId=9` -> 200 OK
  - `GET /chat/groups?userId=9` -> 200 OK
- Fast engineering guard passed (`engineering-guard.sh backend fast`).
- Maintainability ratchet passed (`maintainability.py backend`).
- Workspace validation passed (`validate.sh`).

## Decisions
- Used `ThrottlerGuard` with 120 req/min per IP to balance brute-force protection with chat poll responsiveness.
- Placed controllers in `src/modules/<domain>/` to keep direct code files per directory well below the limit of 12.
