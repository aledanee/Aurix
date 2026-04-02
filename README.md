# Aurix

Multi-tenant fintech backend for digital gold trading with an AI insight layer.

## Tech Stack

- **Backend**: Erlang/OTP 27, Cowboy REST
- **Database**: PostgreSQL 16
- **Cache**: Redis 7
- **Auth**: JWT (HMAC-SHA256) with refresh token rotation
- **Frontend**: React (Node 22)
- **Deployment**: Docker Compose

## Quick Start

```bash
# Clone
git clone https://github.com/aledanee/Aurix.git
cd Aurix

# Copy env template
cp .env.example .env

# Build and start
docker compose build
docker compose up -d

# Verify
curl http://localhost:8080/health
```

## Project Structure

```
├── src/                    # Erlang/OTP source
│   ├── aurix_app.erl      # Application entry
│   ├── aurix_sup.erl      # Top-level supervisor
│   ├── handlers/           # Cowboy REST handlers
│   ├── services/           # Business logic
│   └── repos/              # PostgreSQL repositories
├── priv/
│   └── sql/                # Database migrations
├── test/                   # EUnit tests
│   └── ct/                 # Common Test suites
├── frontend/               # React SPA
├── docs/                   # Design documentation
├── .github/
│   ├── agents/             # AI agent team
│   └── skills/             # Reusable AI skills
├── docker-compose.yml
├── Dockerfile              # Backend
└── Dockerfile.frontend     # Frontend
```

## Architecture

```
Client → Cowboy API → Service Layer → Repository Layer → PostgreSQL
                  ↕                        ↕
                Redis                  Outbox → Kafka
                                       ETL → Insights
```

Three-layer separation:
1. **Handlers** — HTTP parsing, validation, JSON responses
2. **Services** — Business rules, transactions, orchestration
3. **Repositories** — SQL only, no business logic

## Key Design Decisions

- EUR stored as `bigint` cents (never floating-point)
- Gold stored as `numeric(24,8)`
- Multi-tenant via shared schema with `tenant_id` on all tables
- Append-only transaction ledger
- Wallet + ledger + outbox in a single DB transaction
- OTP supervision: crash isolation between HTTP and ETL

## Documentation

| Document | Description |
|----------|-------------|
| [System Design](docs/SYSTEM_DESIGN.md) | Architecture, OTP layout, supervision |
| [API Design](docs/API_DESIGN.md) | Endpoints, errors, pagination |
| [Database Schema](docs/DATABASE_SCHEMA.md) | Tables, indexes, seed data |
| [Security & Auth](docs/SECURITY_AUTH.md) | JWT, passwords, rate limiting |
| [Data Flow & ETL](docs/DATA_FLOW_ETL.md) | Write path, outbox, ETL |
| [Deployment & Ops](docs/DEPLOYMENT_OPS.md) | Docker, CI/CD, env config |
| [Use Cases](docs/USE_CASES.md) | Detailed use case flows |
| [User Stories](docs/USER_STORIES.md) | Acceptance criteria |

## Development

```bash
# Backend
rebar3 compile
rebar3 eunit
rebar3 ct

# Frontend
cd frontend && npm install && npm start

# Docker
docker compose up -d
docker compose logs -f aurix-api
```

## License

Proprietary — All rights reserved.
