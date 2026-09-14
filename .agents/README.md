# Durable Agent State Directory

This directory stores durable engineering state for AI agents and human developers working in the CATU repository.

> **CRITICAL POLICY NOTICE:**
> The root `AGENTS.md` is the **only current operating policy** for this repository.
> Nothing in `.agents/` (including historical plans, memory logs, knowledge docs, or skills) may override or weaken the root operating policy.

## Directory Layout

- `codebases.conf` — Single canonical registry of all repository codebases and their quality properties.
- `maintainability/` — Exact shrink-only JSON debt baselines per codebase (closure-only gate).
- `plans/` — Structured milestone plans for substantial multi-step tasks.
- `memory/` — Compact historical worklogs and outcomes.
- `knowledge/` — Validated, reusable engineering facts and architectural decisions.
- `skills/` — Reusable on-demand operational procedures.
- `templates/` — Standard templates for plans, worklogs, knowledge, and skills.
- `scripts/` — Central governance automation (guards, policy, maintainability, workspace validation).
