# Aurix — Deployment & Operations

## 1. Docker Architecture

### Container Topology

```mermaid
flowchart TB
    subgraph "docker-compose.yml"
        subgraph "Frontend"
            React[react-frontend<br/>Node 22 Alpine<br/>:3000]
        end

        subgraph "Backend"
            API[aurix-api<br/>Erlang/OTP 27<br/>:8080]
        end

        subgraph "Data Stores"
            PG[postgres<br/>PostgreSQL 16 Alpine<br/>:5432]
            Redis[redis<br/>Redis 7 Alpine<br/>:6379]
        end

        subgraph "Tooling (optional)"
            Swagger[swagger-ui<br/>:8081]
        end
    end

    React -->|/api proxy| API
    API --> PG
    API --> Redis
    Swagger -.->|reads openapi.yaml| API

    subgraph "Volumes"
        PGVol[(pg_data)]
        RedisVol[(redis_data)]
    end

    PG --- PGVol
    Redis --- RedisVol
```

### Container Details

| Service | Base Image | Build | Exposed Port | Internal Port |
|---------|-----------|-------|-------------|---------------|
| `react-frontend` | node:22-alpine | Multi-stage (build + serve) | 3000 | 3000 |
| `aurix-api` | erlang:27-alpine | Multi-stage (compile + release) | 8080 | 8080 |
| `postgres` | postgres:16-alpine | Official image | 5432 | 5432 |
| `redis` | redis:7-alpine | Official image | 6379 | 6379 |
| `swagger-ui` | swaggerapi/swagger-ui | Official image | 8081 | 8080 |

## 2. Docker Compose

### Service Dependency Graph

```mermaid
flowchart LR
    React[react-frontend] -->|depends_on| API[aurix-api]
    API -->|depends_on| PG[postgres]
    API -->|depends_on| Redis[redis]
    Swagger[swagger-ui] -.->|optional| API
```

### Startup Order

1. `postgres` — starts first, healthcheck waits for `pg_isready`
2. `redis` — starts alongside postgres, healthcheck with `redis-cli ping`
3. `aurix-api` — waits for postgres and redis health, runs migrations on startup
4. `react-frontend` — waits for aurix-api health
5. `swagger-ui` — optional, no strict dependency

### Health Checks

```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U aurix"]
    interval: 5s
    timeout: 5s
    retries: 5

redis:
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 5s
    timeout: 5s
    retries: 5

aurix-api:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval: 10s
    timeout: 5s
    retries: 3
```

## 3. Dockerfile Strategy

### Backend: Multi-Stage Build

```mermaid
flowchart LR
    subgraph "Stage 1: Build"
        ErlImg[erlang:27-alpine]
        Rebar[rebar3 compile]
        Release[rebar3 release]
        ErlImg --> Rebar --> Release
    end

    subgraph "Stage 2: Runtime"
        Alpine[alpine:3.19]
        Deps[openssl + ncurses]
        Copy[Copy release from Stage 1]
        Entrypoint[ENTRYPOINT bin/aurix foreground]
        Alpine --> Deps --> Copy --> Entrypoint
    end

    Release -->|COPY --from=build| Copy
```

**Key principles:**
- Build tools (rebar3, git, gcc) are NOT in the final image
- Final image is minimal Alpine with only runtime dependencies
- Release includes ERTS (Erlang Runtime System)

### Frontend: Multi-Stage Build

```mermaid
flowchart LR
    subgraph "Stage 1: Build"
        NodeImg[node:22-alpine]
        Install[npm ci]
        Build[npm run build]
        NodeImg --> Install --> Build
    end

    subgraph "Stage 2: Serve"
        Serve[node:22-alpine]
        CopyBuild[Copy build output]
        Server[serve or nginx]
        Serve --> CopyBuild --> Server
    end

    Build -->|COPY --from=build| CopyBuild
```

## 4. Environment Configuration

### Environment Variables

| Variable | Service | Example | Description |
|----------|---------|---------|-------------|
| `DATABASE_URL` | aurix-api | `postgres://aurix:secret@postgres:5432/aurix` | PostgreSQL connection |
| `REDIS_URL` | aurix-api | `redis://redis:6379` | Redis connection |
| `JWT_SECRET` | aurix-api | (32+ byte random string) | JWT signing key |
| `GOLD_PRICE_EUR` | aurix-api | `65.00` | Fixed gold price for demo |
| `SEED_BALANCE_EUR_CENTS` | aurix-api | `1000000` | 10,000 EUR initial balance |
| `PORT` | aurix-api | `8080` | HTTP listen port |
| `REACT_APP_API_URL` | react-frontend | `http://localhost:8080` | Backend API URL |
| `POSTGRES_USER` | postgres | `aurix` | DB user |
| `POSTGRES_PASSWORD` | postgres | (secret) | DB password |
| `POSTGRES_DB` | postgres | `aurix` | DB name |

### .env File (Local Development Only)

```env
POSTGRES_USER=aurix
POSTGRES_PASSWORD=aurix_dev_password
POSTGRES_DB=aurix
JWT_SECRET=dev-secret-key-change-in-production-minimum-32-bytes
GOLD_PRICE_EUR=65.00
SEED_BALANCE_EUR_CENTS=1000000
```

## 5. Local Development Workflow

### Quick Start

```mermaid
flowchart LR
    Clone[git clone] --> Build[docker compose build] --> Up[docker compose up] --> Ready[System ready]

    Ready --> FE[Frontend :3000]
    Ready --> API[API :8080]
    Ready --> Swagger[Swagger :8081]
```

### Commands

```bash
# Build all containers
docker compose build

# Start everything
docker compose up -d

# View logs
docker compose logs -f aurix-api

# Run migrations (if not in entrypoint)
docker compose exec aurix-api bin/aurix eval 'aurix_migration:run()'

# Run tests
docker compose exec aurix-api rebar3 eunit
docker compose exec aurix-api rebar3 ct

# Stop everything
docker compose down

# Stop and remove volumes (reset data)
docker compose down -v
```

## 6. CI/CD Pipeline

```mermaid
flowchart LR
    subgraph "CI (on every push)"
        Lint[Erlang Dialyzer<br/>+ format check]
        Unit[EUnit Tests]
        Integ[Common Test<br/>with test DB]
        Lint --> Unit --> Integ
    end

    subgraph "Build (on main/tags)"
        Release[rebar3 release]
        Docker[Docker build<br/>+ push to registry]
        Release --> Docker
    end

    subgraph "Deploy"
        Stage[Deploy to Staging]
        Smoke[Smoke Tests]
        Prod[Deploy to Production]
        Stage --> Smoke --> Prod
    end

    Integ --> Release
    Docker --> Stage
```

### GitHub Actions Pipeline

```mermaid
flowchart TD
    Push[Push / PR] --> Job1[Lint & Compile]
    Job1 --> Job2[EUnit]
    Job2 --> Job3[Common Test<br/>services: postgres, redis]
    Job3 --> Job4{Branch?}
    Job4 -->|main| Job5[Build Docker Image]
    Job4 -->|feature| Done1[Report results]
    Job5 --> Job6[Push to Container Registry]
    Job6 --> Job7[Deploy to Staging]
    Job7 --> Job8[Smoke Tests]
    Job8 --> Job9[Manual Approval Gate]
    Job9 --> Job10[Deploy to Production]
```

## 7. Production Architecture

### Cloud Deployment

```mermaid
flowchart TB
    subgraph "Internet"
        Users[Users]
    end

    subgraph "Cloud (EU Region)"
        subgraph "Edge"
            CDN[CDN<br/>Static Assets]
            LB[Load Balancer<br/>TLS Termination]
        end

        subgraph "Compute (Kubernetes / ECS)"
            API1[Aurix API Pod 1]
            API2[Aurix API Pod 2]
            API3[Aurix API Pod N]

            FE1[React Frontend Pod 1]
            FE2[React Frontend Pod N]
        end

        subgraph "Managed Data"
            PG_Primary[(PostgreSQL Primary<br/>Writes)]
            PG_Replica[(PostgreSQL Replica<br/>Reads)]
            RedisCluster[(Redis Cluster)]
        end

        subgraph "Async"
            Kafka[(Managed Kafka)]
            ETL_Worker[ETL Worker]
        end
    end

    Users --> CDN
    Users --> LB
    LB --> FE1 & FE2
    LB --> API1 & API2 & API3
    API1 & API2 & API3 -->|writes| PG_Primary
    API1 & API2 & API3 -->|reads| PG_Replica
    API1 & API2 & API3 --> RedisCluster
    API1 & API2 & API3 -.-> Kafka
    Kafka --> ETL_Worker
    ETL_Worker --> PG_Primary
```

### Scaling Triggers

| Component | Scale When | Strategy |
|-----------|-----------|----------|
| API nodes | CPU > 70% or response time > 200ms | Horizontal (add pods) |
| PG Primary | Write IOPS limit reached | Vertical first, then shard |
| PG Replicas | Read latency > 50ms | Add replicas |
| Redis | Memory > 80% or connections > 80% | Cluster scaling |
| ETL Workers | Processing lag > 1 hour | Add workers, partition by tenant |

## 8. Observability

### Metrics

```mermaid
flowchart LR
    subgraph "Application Metrics"
        M1[HTTP request rate]
        M2[HTTP latency p50/p95/p99]
        M3[Error rate by status code]
        M4[Active DB connections]
        M5[Transaction volume per minute]
        M6[ETL processing lag]
        M7[Outbox queue depth]
        M8[Rate limit rejections]
    end

    subgraph "Infrastructure Metrics"
        M9[CPU / Memory per container]
        M10[DB connection pool usage]
        M11[Redis memory / connections]
        M12[Disk I/O]
    end

    M1 & M2 & M3 & M4 & M5 & M6 & M7 & M8 --> Dashboard[Grafana Dashboard]
    M9 & M10 & M11 & M12 --> Dashboard
```

### Logging Pipeline

```mermaid
flowchart LR
    App[Application<br/>Structured JSON logs] --> Stdout[stdout/stderr]
    Stdout --> Collector[Log Collector<br/>Fluentd / Vector]
    Collector --> Store[Log Store<br/>Elasticsearch / Loki]
    Store --> UI[Kibana / Grafana]
```

### Log Fields (every request)

```json
{
    "timestamp": "2026-04-02T10:00:00.000Z",
    "level": "info",
    "request_id": "req-abc-123",
    "tenant_id": "a0000000-...",
    "user_id": "550e8400-...",
    "method": "POST",
    "path": "/wallet/buy",
    "status": 200,
    "duration_ms": 42
}
```

### Alerting Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| High error rate | 5xx rate > 1% for 5 min | Critical |
| Slow responses | p95 latency > 500ms for 5 min | Warning |
| DB pool exhausted | Available connections = 0 | Critical |
| ETL lag | Last run > 2 hours ago | Warning |
| Outbox backlog | Unpublished events > 1000 | Warning |
| Reconciliation mismatch | Any wallet balance mismatch | Critical |

## 9. Backup & Recovery

### Backup Strategy

| Data | Method | Frequency | Retention |
|------|--------|-----------|-----------|
| PostgreSQL | pg_dump + WAL archiving | Hourly incremental, daily full | 30 days |
| Redis | RDB snapshots | Every 15 min | 7 days |
| Application config | Version controlled (git) | Every commit | Permanent |

### Recovery Procedures

```mermaid
flowchart TD
    Incident[Incident Detected] --> Assess{Severity?}

    Assess -->|Data loss| Restore[Restore from backup]
    Restore --> Verify[Verify data integrity]
    Verify --> Reconcile[Run reconciliation]
    Reconcile --> Resume[Resume operations]

    Assess -->|Service down| Restart[Restart containers]
    Restart --> Health[Check health endpoints]
    Health --> Resume

    Assess -->|Degraded| Investigate[Check logs + metrics]
    Investigate --> Fix[Apply fix]
    Fix --> Deploy[Deploy hotfix]
    Deploy --> Resume
```

### RTO / RPO Targets

| Metric | Target | Notes |
|--------|--------|-------|
| RPO (Recovery Point Objective) | < 1 hour | WAL archiving provides continuous backup |
| RTO (Recovery Time Objective) | < 30 minutes | Container restart + migration replay |

## 10. Database Migration Strategy

### Migration in Docker

```mermaid
flowchart LR
    Start[Container Start] --> Check{DB reachable?}
    Check -->|No| Wait[Wait + retry]
    Wait --> Check
    Check -->|Yes| Migrate[Run SQL migrations in order]
    Migrate --> Seed{First run?}
    Seed -->|Yes| SeedData[Run seed scripts]
    Seed -->|No| Skip[Skip seed]
    SeedData --> App[Start application]
    Skip --> App
```

### Migration Files

```
priv/sql/
├── 001_create_tenants.sql
├── 002_create_users.sql
├── 003_create_wallets.sql
├── 004_create_transactions.sql
├── 005_create_insight_snapshots.sql
├── 006_create_outbox_events.sql
├── 007_create_refresh_tokens.sql
├── 008_create_tenant_fee_config.sql
├── 009_create_etl_metadata.sql
├── 010_create_indexes.sql
└── 011_seed_demo_data.sql
```

Each migration is idempotent (`CREATE TABLE IF NOT EXISTS`, etc.).

## 11. Network Security

### Docker Network Isolation

```mermaid
flowchart TB
    subgraph "External (host exposed)"
        FE_Port[":3000 React"]
        API_Port[":8080 API"]
        Swagger_Port[":8081 Swagger"]
    end

    subgraph "Internal (aurix-network only)"
        PG_Internal[postgres:5432]
        Redis_Internal[redis:6379]
    end

    FE_Port --> API_Port
    API_Port --> PG_Internal
    API_Port --> Redis_Internal
```

- PostgreSQL and Redis are on an internal Docker network only
- No host port binding for data stores in production
- TLS termination at the load balancer level
- Internal traffic uses plain TCP within the Docker network

## 12. One-Command Setup

```bash
git clone https://github.com/ibrahimihsan/aurix.git
cd aurix
docker compose up --build
```

This single command:
1. Builds the Erlang backend (multi-stage Docker build)
2. Builds the React frontend (multi-stage Docker build)
3. Starts PostgreSQL with health check
4. Starts Redis with health check
5. Runs database migrations
6. Seeds demo data (tenants)
7. Starts the API server on :8080
8. Starts the React frontend on :3000
9. Starts Swagger UI on :8081

**Access points after startup:**
- Frontend: http://localhost:3000
- API: http://localhost:8080
- Swagger: http://localhost:8081
- Health check: http://localhost:8080/health
