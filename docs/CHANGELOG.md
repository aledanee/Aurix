# Changelog

All notable changes to the Aurix project will be documented in this file.

Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.1.0] - 2026-04-02

### Added

**OTP Application & Supervision**
- `aurix_app` — Application module with env overrides and DB setup
- `aurix_sup` — Root supervisor (one_for_one), manages all child processes
- `aurix_http_sup` — HTTP supervisor, starts Cowboy with full middleware chain

**HTTP Handlers (7)**
- `aurix_auth_handler` — Register, login, refresh, logout, change-password (5 actions)
- `aurix_wallet_handler` — View wallet, buy gold, sell gold (3 actions)
- `aurix_transaction_handler` — Transaction history with cursor-based pagination
- `aurix_insight_handler` — AI insights with Redis caching (5-min TTL)
- `aurix_health_handler` — Health check endpoint (API, DB, Redis components)
- `aurix_privacy_handler` — GDPR data export and erasure request
- `aurix_swagger_handler` — Swagger UI + OpenAPI spec serving

**Services (6)**
- `aurix_auth_service` — Registration (atomic user+wallet), login with argon2id/bcrypt, refresh with rotation, password change
- `aurix_wallet_service` — Buy/sell gold with atomic wallet+ledger+outbox in single DB transaction, idempotency, fee calculation
- `aurix_transaction_service` — Transaction listing with cursor-based pagination
- `aurix_agent_service` — AI insight generation via repo + LLM adapter
- `aurix_tenant_service` — Tenant resolution and status validation
- `aurix_privacy_service` — Erasure workflow: soft-delete + revoke tokens + blacklist JWT

**Repositories (8)**
- `aurix_repo_user` — User CRUD with transactional variant
- `aurix_repo_wallet` — Wallet CRUD with transactional variant, `FOR UPDATE` locking
- `aurix_repo_transaction` — Append-only ledger, idempotency check, cursor pagination
- `aurix_repo_tenant` — Tenant lookup by code
- `aurix_repo_insight` — Insight snapshot listing with cursor pagination
- `aurix_repo_outbox` — Outbox event management (get unpublished, mark published)
- `aurix_repo_refresh_token` — Token CRUD, revocation, expired/revoked distinction via `get_by_hash_any`
- `aurix_repo_fee_config` — Per-tenant fee config with sensible defaults

**Infrastructure (8)**
- `aurix_router` — Cowboy routing with 15 routes
- `aurix_db` — Poolboy-based DB transactions (checkout/checkin pattern)
- `aurix_redis` — 4-connection round-robin eredis pool
- `aurix_jwt` — JWT sign/verify (HMAC-SHA256, 15-min access, 7-day refresh)
- `aurix_jwt_blacklist` — Redis-backed JWT blacklisting
- `aurix_rate_limiter` — Redis-backed sliding window rate limiting
- `aurix_rate_headers` — Rate limit response headers (X-RateLimit-*)
- `aurix_price_provider` — Gold price provider with Redis caching (60s TTL)

**Middleware (3)**
- `aurix_auth_middleware` — JWT extraction/validation with standardized error responses
- `aurix_request_id_middleware` — X-Request-Id generation/propagation for request correlation
- `aurix_cors_middleware` — CORS headers with configurable origin

**Background Processes (3)**
- `aurix_etl_scheduler` — Hourly ETL: daily + weekly transaction aggregation, watermark-based
- `aurix_outbox_dispatcher` — 5s polling, marks events as published
- `aurix_reconciliation` — 6-hour wallet-ledger balance verification

**AI/LLM**
- `aurix_llm_adapter` — Rule-based insight generation from trading signals

**Database (10 SQL migrations)**
- `001_create_tenants` — Multi-tenant root table
- `002_create_users` — Users with `tenant_id`, email uniqueness per tenant
- `003_create_wallets` — Wallet with `gold_balance_grams` (numeric 24,8) and `fiat_balance_eur_cents` (bigint)
- `004_create_transactions` — Append-only ledger with idempotency key
- `005_create_insight_snapshots` — ETL-generated daily/weekly snapshots
- `006_create_outbox_events` — Transactional outbox pattern
- `007_create_refresh_tokens` — Refresh token storage with hash
- `008_create_tenant_fee_config` — Per-tenant fee configuration
- `009_create_etl_metadata` — ETL watermark tracking
- `010_seed_data` — Demo tenant + admin seed data

**API / Swagger**
- OpenAPI 3.0.3 spec (`priv/swagger/openapi.json`) covering all 13 API endpoints
- Swagger UI at `/swagger` (CDN-loaded), spec at `/swagger/spec`

**Tests (6 test files)**
- EUnit: `aurix_jwt_tests`, `aurix_llm_adapter_tests`, `aurix_auth_middleware_tests`
- Common Test: `auth_SUITE`, `wallet_SUITE`, `tenant_isolation_SUITE`

**DevOps**
- `Dockerfile` — Multi-stage Erlang/OTP 27 build
- `Dockerfile.frontend` — Multi-stage React/Node 22 build
- `docker-compose.yml` — Full stack: PostgreSQL, Redis, backend, frontend
- `frontend/nginx.conf` — Nginx frontend config with API proxy

**Documentation**
- System design, API design, database schema, security & auth, data flow & ETL, deployment & ops, use cases, user stories
- AI agent team (10 agents) with coordinator for multi-domain orchestration
- Skills: erlang-otp-patterns, multi-tenant-isolation, financial-calculations, project-documentation
- Changelog, bug/incident/error/decision index files

### Security
- **C1**: argon2id primary password hashing with bcrypt fallback + automatic hash migration on login
- **C2**: Atomic user+wallet registration via `aurix_db:transaction`
- **C3**: Default fee config (0.5% buy/sell, 50 cent minimum) when no tenant override exists
- **C4**: Poolboy-based DB transactions with checkout/checkin pattern
- **C5**: Price precision with `format_price_decimal/1` (decimal string, not float)
- **H1–H7**: Complete error mapping — `password_unchanged`→400, `wallet_not_found`→404, `token_expired`/`token_revoked` distinction, refresh checks user active status, register includes `created_at`, erasure includes `request_id`
- **L1**: Error responses include `details: {}` consistently
- **L2**: argon2 dependency in `app.src` applications list
- **L3**: Reconciliation epsilon comparison accepted
- Every tenant-scoped query includes `tenant_id` in WHERE clause
- JWT claims as sole source of `tenant_id` for authenticated requests
- Append-only ledger — no UPDATE or DELETE on transactions table
- Wallet updates, ledger inserts, and outbox inserts in single DB transaction

### Fixed
- **M1**: ETL `run_now/0` manual trigger for on-demand aggregation
- **M2**: X-Request-Id middleware for request correlation
- **M3**: Structured JSON logging across all modules (maps instead of freeform text)
- **M4**: Redis connection pool (4 connections, round-robin) replacing single connection
- **M5**: Insight caching with 5-min Redis TTL
- **M6**: Price provider Redis caching (60s TTL)
- **M7**: GDPR privacy export with all required fields
- **M8**: Service layer modules extracted (transaction_service, agent_service, tenant_service)
- **M9**: HTTP supervisor (`aurix_http_sup`) for Cowboy process isolation
- **M10**: Outbox events include `price_eur_per_gram` and timestamp
