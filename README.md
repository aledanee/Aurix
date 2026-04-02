# Aurix - Internship Evaluation Submission

Aurix is a production-oriented multi-tenant fintech backend for digital gold trading, built to satisfy an internship evaluation focused on backend systems design, reliable financial transaction handling, AI-assisted insight delivery, and deployment readiness. The project combines Erlang/OTP supervision, Cowboy HTTP APIs, PostgreSQL persistence, Redis-backed operational controls, a Dockerized React frontend, and a clear handler/service/repository architecture. The result is not just a feature demo: it is a practical backend design with tenant isolation, append-only ledgering, atomic write paths, structured insight generation, OpenAPI documentation, and automated tests.

## What This Project Delivers

| Evaluation area | Delivery in Aurix |
| --- | --- |
| Core wallet service | JWT-protected wallet APIs, buy and sell flows, transaction history, idempotent trade requests, and balance updates tied to ledger entries |
| Multi-tenant architecture | Shared-schema tenancy with `tenant_id` on tenant-scoped data, tenant-aware repository queries, tenant isolation tests, and JWT-scoped authenticated access |
| AI insights layer | Structured trading signals exposed through an agent service and turned into readable client-facing insight text by a mocked LLM-style formatter |
| ETL pipeline | Scheduled aggregation of transaction activity into persisted insight snapshots for daily and weekly reporting |
| Scaling and design thinking | Stateless API shape, Redis rate limiting and caching, cursor pagination, outbox events, supervision boundaries, and clean API contracts |
| Bonus features | Dockerized backend and frontend, Swagger UI and OpenAPI spec, admin endpoints, privacy endpoints, automated tests, and event logging via the outbox pattern |

## Tech Stack

- Backend: Erlang/OTP 27, Cowboy HTTP server, pgapp with epgsql, PostgreSQL 16, Redis 7
- Authentication and security: JWT access and refresh tokens, refresh rotation, bcrypt password hashing, rate limiting, JWT blacklist support
- Frontend: React 18, Node 22, Dockerized frontend container
- API and documentation: Swagger UI at `/swagger`, OpenAPI spec in `priv/swagger/openapi.json`, endpoint docs in `docs/api/`
- Background processing: OTP workers for price updates, outbox dispatch, ETL scheduling, and reconciliation

## Architecture Summary

```text
React frontend
    |
    v
Cowboy router
    |
    +--> Handlers      -> parse HTTP, validate input, extract auth context, return JSON
            |
            v
        Services       -> business rules, orchestration, DB transaction boundaries
            |
            v
        Repositories   -> tenant-scoped SQL only
            |
            v
        PostgreSQL

Redis                  -> rate limiting, JWT support, insight response cache
Outbox dispatcher      -> processes committed wallet events and provides a Kafka-ready handoff point
ETL scheduler          -> aggregates transaction data into insight snapshots
Agent service          -> loads snapshots and formats signals into readable insights
Mocked LLM adapter     -> converts structured signals into final user-facing insight text
```

Aurix follows a strict handler/service/repository split. Handlers deal with HTTP concerns only. Services hold business rules, token issuance, trade execution, and transaction orchestration. Repositories stay focused on SQL and persistence. This keeps the API readable, the trade path testable, and the tenancy rules enforceable in one place.

At the OTP level, HTTP is supervised separately from Redis, the rate limiter, the outbox dispatcher, the ETL scheduler, and reconciliation workers. The top-level supervision strategy is `one_for_one`, which means a failure in ETL or background processing does not take down the HTTP stack.

## Financial and Tenancy Guarantees

- EUR values are stored as `bigint` cents, so money is not persisted as floating-point values.
- Gold balances and trade quantities are stored as fixed-precision numeric values and exposed through the API as decimal strings.
- Tenant isolation uses a shared schema with `tenant_id` on tenant-scoped tables.
- On authenticated routes, `tenant_id` comes from JWT claims only. Clients do not send tenant context for protected APIs.
- The transaction ledger is append-only. Trade history is written as new rows rather than updated in place.
- A wallet trade updates the wallet, inserts the ledger row, and inserts the outbox event inside one database transaction.
- Wallet writes use `Idempotency-Key` headers, row-level locking, and versioned updates to make retries and concurrent trade requests safe.

## Authentication Model

- `POST /auth/register` requires `tenant_code`, `email`, and `password`.
- `POST /auth/login` supports smart email and password login. If one active tenant matches, login succeeds without `tenant_code`. If multiple matching tenants remain, the API returns `tenant_selection_required` and the client re-submits with the selected `tenant_code`.
- Authenticated sessions use JWT access tokens plus refresh tokens. Refresh tokens are rotated on refresh, and password changes revoke refresh tokens and invalidate existing access tokens.

## Implemented API Surface

| Area | Endpoints |
| --- | --- |
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/change-password` |
| Wallet | `GET /wallet`, `POST /wallet/buy`, `POST /wallet/sell` |
| Transactions | `GET /transactions` |
| Insights | `GET /insights` |
| Privacy | `GET /privacy/export`, `POST /privacy/erasure-request` |
| Admin | `GET /admin/tenants`, `POST /admin/tenants/:tenant_id/deactivate`, `POST /admin/gold-price`, `PUT /admin/tenants/:tenant_id/fees`, `POST /admin/etl/trigger` |
| System | `GET /health`, `GET /swagger`, `GET /swagger/spec` |

Full endpoint writeups live in `docs/api/`, and the machine-readable OpenAPI source is in `priv/swagger/openapi.json`.

## Sample API Requests and Responses

The examples below are aligned with the current handlers and service layer. IDs, tokens, and timestamps will vary at runtime.

### 1. Register

Request:

```http
POST /auth/register
Content-Type: application/json

{
  "tenant_code": "aurix-demo",
  "email": "nora@example.com",
  "password": "StrongPass123"
}
```

Response `201 Created`:

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "nora@example.com",
  "tenant_id": "a0000000-0000-0000-0000-000000000001",
  "wallet_id": "770e8400-e29b-41d4-a716-446655440000",
  "created_at": "2026-04-02T10:00:00Z"
}
```

### 2. Login

Smart login first attempt, without `tenant_code`:

```http
POST /auth/login
Content-Type: application/json

{
  "email": "nora@example.com",
  "password": "StrongPass123"
}
```

Possible response when the same email exists in multiple tenants:

```json
{
  "error": {
    "code": "tenant_selection_required",
    "message": "Multiple tenants found. Please select one."
  },
  "tenants": [
    {
      "tenant_code": "aurix-demo"
    },
    {
      "tenant_code": "partner-co"
    }
  ]
}
```

Re-submit with the selected tenant:

```http
POST /auth/login
Content-Type: application/json

{
  "tenant_code": "aurix-demo",
  "email": "nora@example.com",
  "password": "StrongPass123"
}
```

Response `200 OK`:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "QmFzZTY0UmVmcmVzaFRva2Vu...",
  "token_type": "Bearer",
  "expires_in": 900
}
```

### 3. Wallet

Request:

```http
GET /wallet
Authorization: Bearer <access_token>
```

Response `200 OK`:

```json
{
  "wallet_id": "770e8400-e29b-41d4-a716-446655440000",
  "tenant_id": "a0000000-0000-0000-0000-000000000001",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "gold_balance_grams": "1.25000000",
  "fiat_balance_eur": "9918.25",
  "updated_at": "2026-04-02T10:05:00Z"
}
```

### 4. Buy Gold

Request:

```http
POST /wallet/buy
Authorization: Bearer <access_token>
Idempotency-Key: buy-20260402-0001
Content-Type: application/json

{
  "grams": "1.25000000"
}
```

Response `200 OK`:

```json
{
  "transaction": {
    "id": "880e8400-e29b-41d4-a716-446655440000",
    "type": "buy",
    "gold_grams": "1.25000000",
    "price_eur_per_gram": "65.00000000",
    "gross_eur": "81.25",
    "fee_eur": "0.50",
    "total_eur": "81.75",
    "created_at": "2026-04-02T10:05:00Z"
  },
  "wallet": {
    "gold_balance_grams": "1.25000000",
    "fiat_balance_eur": "9918.25"
  }
}
```

### 5. Insights

Request:

```http
GET /insights?limit=2&frequency=weekly
Authorization: Bearer <access_token>
```

Response `200 OK`:

```json
{
  "items": [
    {
      "id": "aa0e8400-e29b-41d4-a716-446655440000",
      "frequency": "weekly",
      "period_start": "2026-03-27",
      "period_end": "2026-04-02",
      "generated_at": "2026-04-02T14:15:00Z",
      "signals": {
        "buy_count": 4,
        "sell_count": 1,
        "total_gold_bought_grams": 5.25,
        "average_buy_price_eur_per_gram": 68.5,
        "buy_frequency_per_week": 4,
        "sell_after_buy_ratio": 0.25,
        "reference_price_eur_per_gram": 64.9,
        "inactivity_days": 0
      },
      "insights": [
        "You are buying frequently. Consider spacing out your purchases to reduce timing risk.",
        "You are buying at prices above the reference average. Consider waiting for a dip."
      ]
    }
  ],
  "next_cursor": null
}
```

## Quick Start With Docker

```bash
git clone https://github.com/aledanee/Aurix.git
cd Aurix
cp .env.example .env
docker compose up --build
```

Local URLs:

- Frontend: `http://localhost:3000`
- Backend API: `http://localhost:8080`
- Swagger UI: `http://localhost:8080/swagger`
- OpenAPI endpoint: `http://localhost:8080/swagger/spec`

First-use notes:

- Use tenant code `aurix-demo` for registration.
- The repository also seeds `partner-co`, which is useful for testing tenant isolation and the smart login tenant-selection path.
- In local development, wallet seed balance comes from `.env.example`, so the buy flow can be exercised immediately after registration.

Verification commands:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/swagger/spec
```

## Local Development Commands

Backend:

```bash
rebar3 compile
rebar3 eunit
rebar3 ct
```

Frontend:

```bash
cd frontend
npm install
npm start
```

## Testing

Aurix includes both EUnit and Common Test coverage.

- EUnit tests cover JWT behavior, auth middleware behavior, and the mocked LLM adapter.
- Common Test suites cover auth flows, wallet flows, admin routes, privacy routes, and tenant isolation.

Current test locations:

- `test/aurix_jwt_tests.erl`
- `test/aurix_auth_middleware_tests.erl`
- `test/aurix_llm_adapter_tests.erl`
- `test/ct/auth_SUITE.erl`
- `test/ct/wallet_SUITE.erl`
- `test/ct/admin_SUITE.erl`
- `test/ct/privacy_SUITE.erl`
- `test/ct/tenant_isolation_SUITE.erl`

## Project Structure

```text
src/
├── aurix.app.src
├── aurix_app.erl
├── aurix_router.erl
├── aurix_sup.erl
├── etl/
├── handlers/
├── infra/
├── middleware/
├── repos/
└── services/

test/
├── aurix_auth_middleware_tests.erl
├── aurix_jwt_tests.erl
├── aurix_llm_adapter_tests.erl
└── ct/

docs/api/                  # Per-endpoint API docs
priv/swagger/openapi.json  # OpenAPI source
frontend/                  # React client
priv/sql/                  # Schema and seed SQL
```

## Scaling to Millions of Users

Aurix is still a scoped evaluation project, but its design already points in the right direction for large-scale operation:

- API nodes are stateless, so horizontal scaling is straightforward behind a load balancer.
- Redis already supports rate limiting and response caching, which helps absorb high read traffic and operational bursts.
- The outbox pattern creates a clean handoff point for Kafka or another event bus without coupling wallet writes to downstream consumers.
- PostgreSQL can evolve with read replicas for history and insight queries, plus partitioning for large transaction and outbox tables.
- Trade requests already use idempotency keys, row-level locking, and version checks, which are the right primitives for safe concurrency at scale.
- Cursor pagination on list endpoints avoids the cost and instability of offset-based pagination on large datasets.

## Documentation Links

- [System Design](docs/SYSTEM_DESIGN.md)
- [API Design](docs/API_DESIGN.md)
- [API Reference](docs/api/INDEX.md)
- [Database Schema](docs/DATABASE_SCHEMA.md)
- [Security and Auth](docs/SECURITY_AUTH.md)
- [Data Flow and ETL](docs/DATA_FLOW_ETL.md)
- [Deployment and Ops](docs/DEPLOYMENT_OPS.md)
- [Use Cases](docs/USE_CASES.md)
- [User Stories](docs/USER_STORIES.md)
- [OpenAPI Spec](priv/swagger/openapi.json)

## Conclusion

Aurix satisfies the evaluation brief by demonstrating a realistic backend design rather than a minimal prototype. It shows how to build a fintech-style, multi-tenant wallet platform with safe financial storage rules, atomic transaction posting, tenant-aware APIs, AI-assisted insight delivery, Docker-based setup, and test coverage. The current implementation is intentionally practical: the core trade path is reliable, the API surface is documented, and the architecture has clear seams for future scale.
