# Aurix — Digital Gold Trading Platform

## The Story

Erlang came out of Ericsson in the late 1980s to keep telecom switches alive — millions of concurrent connections, zero downtime, hot code reloading mid-call. In my production work I pair it with Java Spring Boot as complementary layers: Spring owns the rich business logic and ecosystem integrations, Erlang owns the pressure — the fault-tolerant, high-throughput runtime core that refuses to go down. Each technology doing what it does best, the whole greater than its parts. When you're building a fintech backend where downtime is measured in lost money, that same telecom DNA fits like it was always meant to.

When the task landed on WhatsApp I put on [Mozart's Symphony No. 40](https://www.youtube.com/watch?v=UBfsS1EGyWc) and started coding — I'd recommend hitting play while you read through the codebase. I'm also an Oud player (the Arabic string instrument), so the thread between music and craftsmanship runs deep for me; building software, like playing an instrument, is about feel, patience, and knowing when to let the structure breathe. That same philosophy shaped what follows.

Aurix is a multi-tenant fintech backend for digital gold trading. Not a demo. Not a prototype. A production-grade system — Erlang/OTP supervision, Cowboy HTTP, PostgreSQL, Redis, a Dockerized React frontend, and a clean handler/service/repository architecture. Tenant isolation, append-only ledgering, atomic write paths, AI-driven insight generation, OpenAPI docs, and real tests. The kind of backend you'd actually deploy.

## What It Delivers

| Area | What I Built |
| --- | --- |
| **Wallet service** | JWT-protected buy/sell flows, transaction history, idempotent trades, balance updates tied to ledger entries |
| **Multi-tenancy** | Shared-schema with `tenant_id` everywhere it matters — tenant-aware queries, isolation tests, JWT-scoped access |
| **AI insights** | Structured trading signals through an agent service, formatted into readable client-facing text by a mocked LLM adapter |
| **ETL pipeline** | Scheduled aggregation of transaction activity into persisted insight snapshots — daily and weekly |
| **Scale thinking** | Stateless APIs, Redis rate limiting + caching, cursor pagination, outbox events, supervision boundaries |
| **Extras** | Docker everything, Swagger UI + OpenAPI spec, admin endpoints, privacy endpoints, automated tests, outbox pattern |

## The Stack

I don't pick tools because they're trendy. I pick them because they fit.

- **Backend**: Erlang/OTP 27, Cowboy, pgapp + epgsql, PostgreSQL 16, Redis 7
- **Auth & security**: JWT access + refresh tokens (rotated), bcrypt, rate limiting, JWT blacklist
- **Frontend**: React 18, Node 22, Dockerized
- **Docs**: Swagger UI at `/swagger`, OpenAPI spec in `priv/swagger/openapi.json`, per-endpoint writeups in `docs/api/`
- **Background workers**: OTP processes for price updates, outbox dispatch, ETL scheduling, reconciliation

## How It's Wired

```text
React frontend
    |
    v
Cowboy router
    |
    +--> Handlers      -> HTTP concerns only — parse, validate, extract auth, return JSON
            |
            v
        Services       -> business rules, orchestration, DB transaction boundaries
            |
            v
        Repositories   -> tenant-scoped SQL, nothing else
            |
            v
        PostgreSQL

Redis                  -> rate limiting, JWT support, insight cache
Outbox dispatcher      -> committed wallet events → Kafka-ready handoff point
ETL scheduler          -> transaction data → insight snapshots
Agent service          -> snapshots → formatted trading signals
Mocked LLM adapter     -> structured signals → readable insight text
```

Strict handler/service/repository split. Handlers know about HTTP. Services know about business logic. Repositories know about SQL. Nobody crosses the line. That discipline is what makes the trade path testable and the tenancy rules enforceable in one place — not scattered across handlers.

OTP supervision keeps things isolated too. HTTP sits in its own supervision tree, separate from Redis, the rate limiter, the outbox dispatcher, ETL, and reconciliation workers. Strategy is `one_for_one` — if ETL crashes, your API doesn't go down with it.

## The Money Rules

In fintech, the details are the product. Here's how I treat money:

- EUR values are `bigint` cents — no floating-point anywhere near money
- Gold balances and trade quantities are fixed-precision numeric, exposed as decimal strings
- Tenant isolation via shared schema with `tenant_id` on every tenant-scoped table
- On authenticated routes, `tenant_id` comes from JWT claims only — clients never send tenant context
- The ledger is append-only. Trades are new rows, not updates. History is sacred.
- A single trade = wallet update + ledger row + outbox event, all inside one DB transaction
- Idempotency keys, row-level locking, versioned updates — retries and concurrency handled

## The AI Layer

The insight engine has three moving parts:

1. **ETL Scheduler** (`src/etl/aurix_etl_scheduler.erl`) — A `gen_server` that fires every hour (or on-demand via `POST /admin/etl/trigger`). It reads new transactions since the last watermark, groups them by tenant + user, computes summary signals (buy count, sell count, average price, frequency, sell-after-buy ratio, inactivity days), and persists the result as `insight_snapshots` in PostgreSQL.

2. **Agent Service** (`src/services/aurix_agent_service.erl`) — When a client hits `GET /insights`, this service loads the user's snapshots from the DB, then passes each snapshot's signals through the LLM adapter to generate readable insight text. Cursor-paginated, frequency-filterable.

3. **Mocked LLM Adapter** (`src/etl/aurix_llm_adapter.erl`) — This is where the "AI" lives. Right now it's four rule-based insight generators:
   - **High buy frequency** — more than 3 buys → "Consider spacing out your purchases"
   - **Buying above average** — avg price > 105% of reference → "Consider waiting for a dip"
   - **Sell-after-buy pattern** — sell/buy ratio > 50% → "Consider holding longer to reduce fee impact"
   - **Low activity with holdings** — no recent buys but holding gold → "Consider dollar-cost averaging"
   - If no rules fire, it returns a neutral "Your trading activity looks balanced" message.

**Why it's mocked**: The architecture is designed for a real LLM, but for an evaluation project, deterministic rules make more sense — they're testable, predictable, and demonstrate the same pipeline without external API dependencies.

**Swapping in a real LLM**: Replace `aurix_llm_adapter:generate_insights/1` with an HTTP call to OpenAI, Anthropic, or any LLM API. The function takes a signals map, returns a list of insight binaries. One function, one contract. The rest of the pipeline — ETL, snapshots, agent service, API handler — stays untouched.

## Authentication

I built a smart login flow that respects multi-tenancy without annoying users:

- **Register** (`POST /auth/register`) — needs `tenant_code`, `email`, `password`
- **Login** (`POST /auth/login`) — if one tenant matches your email, you're in. If multiple tenants exist, the API returns `tenant_selection_required` and the client re-submits with the chosen one. No guessing.
- **Sessions** — JWT access + refresh tokens. Refresh tokens rotate on use. Password changes revoke everything — no stale sessions hanging around.

## API Surface

| Area | Endpoints |
| --- | --- |
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `POST /auth/change-password` |
| Wallet | `GET /wallet`, `POST /wallet/buy`, `POST /wallet/sell` |
| Transactions | `GET /transactions` |
| Insights | `GET /insights` |
| Privacy | `GET /privacy/export`, `POST /privacy/erasure-request` |
| Admin | `GET /admin/tenants`, `POST /admin/tenants/:tenant_id/deactivate`, `POST /admin/gold-price`, `PUT /admin/tenants/:tenant_id/fees`, `POST /admin/etl/trigger` |
| System | `GET /health`, `GET /swagger`, `GET /swagger/spec` |

Full writeups in `docs/api/`. Machine-readable spec in `priv/swagger/openapi.json`.

## See It Work

IDs, tokens, timestamps — all will vary at runtime. These are the real shapes.

### Register

```http
POST /auth/register
Content-Type: application/json

{
  "tenant_code": "aurix-demo",
  "email": "nora@example.com",
  "password": "StrongPass123"
}
```

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "nora@example.com",
  "tenant_id": "a0000000-0000-0000-0000-000000000001",
  "wallet_id": "770e8400-e29b-41d4-a716-446655440000",
  "created_at": "2026-04-02T10:00:00Z"
}
```

### Login (Smart Flow)

First attempt — no `tenant_code`:

```http
POST /auth/login
Content-Type: application/json

{
  "email": "nora@example.com",
  "password": "StrongPass123"
}
```

If the same email lives in multiple tenants, the API asks you to pick:

```json
{
  "error": {
    "code": "tenant_selection_required",
    "message": "Multiple tenants found. Please select one."
  },
  "tenants": [
    { "tenant_code": "aurix-demo" },
    { "tenant_code": "partner-co" }
  ]
}
```

Re-submit with your choice:

```http
POST /auth/login
Content-Type: application/json

{
  "tenant_code": "aurix-demo",
  "email": "nora@example.com",
  "password": "StrongPass123"
}
```

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "QmFzZTY0UmVmcmVzaFRva2Vu...",
  "token_type": "Bearer",
  "expires_in": 900
}
```

### Check Wallet

```http
GET /wallet
Authorization: Bearer <access_token>
```

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

### Buy Gold

```http
POST /wallet/buy
Authorization: Bearer <access_token>
Idempotency-Key: buy-20260402-0001
Content-Type: application/json

{
  "grams": "1.25000000"
}
```

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

### Get Insights

```http
GET /insights?limit=2&frequency=weekly
Authorization: Bearer <access_token>
```

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

## Live Demo

It's running. Go look.

| Resource | URL |
| --- | --- |
| Frontend | [https://hopn.ibrahimihsan.site](https://hopn.ibrahimihsan.site) |
| Backend API | [https://hopn-backend.ibrahimihsan.site](https://hopn-backend.ibrahimihsan.site) |
| Health Check | [https://hopn-backend.ibrahimihsan.site/health](https://hopn-backend.ibrahimihsan.site/health) |
| Swagger UI | [https://hopn-backend.ibrahimihsan.site/swagger](https://hopn-backend.ibrahimihsan.site/swagger) |
| OpenAPI Spec | [https://hopn-backend.ibrahimihsan.site/swagger/spec](https://hopn-backend.ibrahimihsan.site/swagger/spec) |

Demo credentials:

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@Aurix.com` | `P@ssw0rd` |
| User | `user@Aurix.com` | `Password@` |

## Get It Running

```bash
git clone https://github.com/aledanee/Aurix.git
cd Aurix
cp .env.example .env
docker compose up --build
```

That's it. You'll have:

- Frontend at `http://localhost:3000`
- Backend API at `http://localhost:8080`
- Swagger UI at `http://localhost:8080/swagger`
- OpenAPI spec at `http://localhost:8080/swagger/spec`

Use tenant code `aurix-demo` for registration. There's also `partner-co` seeded — useful for testing tenant isolation and the smart login path. Wallet seed balance comes from `.env.example`, so buy flows work immediately after signup.

Quick sanity check:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/swagger/spec
```

## Demo Accounts

Two accounts auto-seed on startup when the `DEMO_*` env vars are set:

| Role | Email | Password | Tenant |
| --- | --- | --- | --- |
| Admin | `admin@Aurix.com` | `P@ssw0rd` | `aurix-demo` |
| User | `user@Aurix.com` | `Password@` | `aurix-demo` |

Idempotent — if they already exist, the seed skips. Safe to re-run.

**Via API:**

```bash
# Admin
curl -s http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@Aurix.com","password":"P@ssw0rd"}'

# User
curl -s http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@Aurix.com","password":"Password@"}'
```

**Via Frontend:** Open `http://localhost:3000`, enter the credentials. Admin gets access to `/admin/*` routes.

**Environment config** (in `.env`):

```
DEMO_ADMIN_EMAIL=admin@Aurix.com
DEMO_ADMIN_PASSWORD=P@ssw0rd
DEMO_USER_EMAIL=user@Aurix.com
DEMO_USER_PASSWORD=Password@
DEMO_TENANT=aurix-demo
SEED_BALANCE_EUR_CENTS=1000000
```

Each account starts with €10,000.00 (1,000,000 cents). Change `SEED_BALANCE_EUR_CENTS` to adjust. If any `DEMO_*` variable is missing, the seed silently skips — safe for production.

## Local Development

**Backend:**

```bash
rebar3 compile
rebar3 eunit
rebar3 ct
```

**Frontend:**

```bash
cd frontend
npm install
npm start
```

## CI/CD

Every push to `main` triggers the full pipeline:

1. EUnit tests in a fresh Erlang container
2. If green — SSH into the production VPS
3. Write `.env` from GitHub secrets
4. Docker Compose rebuild + restart
5. Health check to confirm it's live

Workflow file: `.github/workflows/deploy.yml`.

## Tests

Both EUnit and Common Test. I don't ship what I can't verify.

- **EUnit** — JWT behavior, auth middleware, mocked LLM adapter
- **Common Test** — auth flows, wallet flows, admin routes, privacy routes, tenant isolation

```text
test/aurix_jwt_tests.erl
test/aurix_auth_middleware_tests.erl
test/aurix_llm_adapter_tests.erl
test/ct/auth_SUITE.erl
test/ct/wallet_SUITE.erl
test/ct/admin_SUITE.erl
test/ct/privacy_SUITE.erl
test/ct/tenant_isolation_SUITE.erl
```

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

## Where It Goes From Here

Aurix is a scoped evaluation project, but the architecture doesn't know that. It's already pointing in the right direction:

- **Horizontal scaling** — API nodes are stateless. Put a load balancer in front, spin up more.
- **Traffic absorption** — Redis rate limiting + response caching are already in place for read-heavy bursts.
- **Event-driven growth** — The outbox pattern gives you a clean Kafka handoff point without coupling wallet writes to downstream consumers.
- **Database evolution** — Read replicas for history/insight queries, partitioning for large transaction and outbox tables.
- **Concurrency safety** — Idempotency keys, row-level locking, version checks. The primitives are already there.
- **Pagination** — Cursor-based, not offset-based. No performance cliff on large datasets.

## Documentation

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

---

This isn't a minimal prototype dressed up to pass an evaluation. It's a real backend design — the kind of code I'd stand behind in production. The trade path is reliable, the API surface is documented, the architecture has clean seams for scale, and every design decision was made with intent. Like playing the oud — you don't just hit the notes, you feel where the music wants to go, and you let the structure breathe.
