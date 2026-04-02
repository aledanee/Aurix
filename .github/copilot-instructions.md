# Aurix — Project Instructions

## Project Overview

Aurix is a multi-tenant fintech backend for digital gold trading with an AI insight layer. Built with Erlang/OTP, Cowboy HTTP server, PostgreSQL, Redis, and JWT authentication.

## Technical Stack

- **Language**: Erlang/OTP 27
- **HTTP**: Cowboy REST
- **Database**: PostgreSQL 16 (pgapp/epgsql pool)
- **Cache/Rate Limiting**: Redis 7 (eredis)
- **Auth**: JWT (HMAC-SHA256) with refresh token rotation
- **Password Hashing**: argon2id (bcrypt fallback)
- **Multi-tenancy**: Shared schema with `tenant_id` on all tables
- **Frontend**: React (Node 22)
- **Deployment**: Docker Compose

## Architecture Layers

1. **Handler Layer** — Parse HTTP, extract auth context, validate request, call services, return JSON
2. **Service Layer** — Business rules, orchestrate repos, manage DB transactions
3. **Repository Layer** — SQL only, no business logic

## Critical Rules

- **Never use floating-point for money.** EUR is stored as `bigint` cents. Gold is `numeric(24,8)`.
- **Every tenant-scoped query MUST include `tenant_id` in the WHERE clause.**
- **JWT claims are the sole source of `tenant_id` for authenticated requests.**
- **Ledger rows (transactions table) are append-only. Never UPDATE or DELETE.**
- **Wallet updates, ledger inserts, and outbox inserts happen in a single DB transaction.**
- **OTP supervision: one_for_one. A crash in ETL must not affect HTTP.**

## Module Naming Convention

All modules use the `aurix_` prefix:
- Handlers: `aurix_*_handler`
- Services: `aurix_*_service`
- Repos: `aurix_repo_*`
- OTP: `aurix_app`, `aurix_sup`, `aurix_*_sup`

## Key Design Documents

- [System Design](docs/SYSTEM_DESIGN.md)
- [API Design](docs/API_DESIGN.md)
- [Database Schema](docs/DATABASE_SCHEMA.md)
- [Security & Auth](docs/SECURITY_AUTH.md)
- [Data Flow & ETL](docs/DATA_FLOW_ETL.md)
- [Deployment & Ops](docs/DEPLOYMENT_OPS.md)
- [Use Cases](docs/USE_CASES.md)
- [User Stories](docs/USER_STORIES.md)
