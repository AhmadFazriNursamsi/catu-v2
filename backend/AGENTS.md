# Backend Component — Local Invariants

Follow `../AGENTS.md` for all workflow, testing, Git, validation, and execution policy.

## Local Technical Invariants

- **Stack**: NestJS 11 + TypeScript + Node 20.
- **Database**: PostgreSQL 16 managed via TypeORM + Docker Compose (`catu_postgres`).
- **Authentication**: Cryptographic HS256 JWT tokens (`@nestjs/jwt`) with strict `bcrypt.compare` password hashing.
- **Runtime Port**: Internal port 3000, mapped to host port 8001.
- **Logging & Errors**: `HttpLoggerMiddleware` logs HTTP requests; `AllExceptionsFilter` masks internal database errors.
- **Operational Scripts**: Place component-specific scripts in `scripts/backend/`, not in product directories.

<!-- gitnexus:start -->
## GitNexus — Code Intelligence

This project is indexed by GitNexus as **backend** (153 symbols, 223 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze`.
<!-- gitnexus:end -->
