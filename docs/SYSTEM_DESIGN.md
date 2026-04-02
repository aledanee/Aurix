# Aurix — System Design

## 1. High-Level Architecture

```mermaid
flowchart TB
    subgraph Clients
        Web[React Frontend<br/>:3000]
        Mobile[Mobile / Other Clients]
    end

    subgraph Docker Network
        subgraph API Layer
            LB[Nginx / Load Balancer]
            API1[Cowboy API Node 1<br/>:8080]
            API2[Cowboy API Node 2<br/>:8080]
        end

        subgraph Data Layer
            PG[(PostgreSQL<br/>:5432)]
            Redis[(Redis<br/>:6379)]
        end

        subgraph Async Layer
            Outbox[Outbox Dispatcher]
            ETL[ETL Scheduler]
            Kafka[(Kafka<br/>optional)]
        end
    end

    Web --> LB
    Mobile --> LB
    LB --> API1
    LB --> API2
    API1 --> PG
    API1 --> Redis
    API2 --> PG
    API2 --> Redis
    API1 -.-> Outbox
    API2 -.-> Outbox
    Outbox --> Kafka
    ETL --> PG
```

## 2. Component Architecture

```mermaid
flowchart LR
    subgraph "Cowboy HTTP Layer"
        Router[aurix_router]
        AuthH[aurix_auth_handler]
        WalletH[aurix_wallet_handler]
        TxH[aurix_transaction_handler]
        InsightH[aurix_insight_handler]
        HealthH[aurix_health_handler]
    end

    subgraph "Service Layer"
        AuthS[aurix_auth_service]
        WalletS[aurix_wallet_service]
        TxS[aurix_transaction_service]
        TenantS[aurix_tenant_service]
        AgentS[aurix_agent_service]
        PriceP[aurix_price_provider]
    end

    subgraph "Repository Layer"
        UserR[aurix_repo_user]
        WalletR[aurix_repo_wallet]
        TxR[aurix_repo_transaction]
        TenantR[aurix_repo_tenant]
        InsightR[aurix_repo_insight]
        OutboxR[aurix_repo_outbox]
        RefreshR[aurix_repo_refresh_token]
        FeeConfigR[aurix_repo_fee_config]
    end

    subgraph "Infrastructure"
        DB[(PostgreSQL)]
        Cache[(Redis)]
        MQ[(Kafka)]
    end

    Router --> AuthH & WalletH & TxH & InsightH & HealthH

    AuthH --> AuthS
    WalletH --> WalletS
    TxH --> TxS
    InsightH --> AgentS

    AuthS --> TenantS & UserR & RefreshR
    WalletS --> WalletR & TxR & OutboxR & PriceP & TenantS & FeeConfigR
    TxS --> TxR
    AgentS --> InsightR

    UserR & WalletR & TxR & TenantR & InsightR & OutboxR & RefreshR & FeeConfigR --> DB
    PriceP --> Cache
```

## 3. OTP Supervision Tree

```mermaid
graph TD
    AurixApp[aurix_app]
    AurixSup[aurix_sup<br/>one_for_one]

    AurixApp --> AurixSup

    AurixSup --> DbPool[aurix_db_pool<br/>pgapp / epgsql pool<br/>worker pool]
    AurixSup --> RedisPool[aurix_redis_pool<br/>eredis pool]
    AurixSup --> HttpSup[aurix_http_sup<br/>Cowboy listener<br/>supervisor]
    AurixSup --> PriceProvider[aurix_price_provider<br/>gen_server]
    AurixSup --> OutboxDisp[aurix_outbox_dispatcher<br/>gen_server]
    AurixSup --> EtlSched[aurix_etl_scheduler<br/>gen_server]
    AurixSup --> RateLimiter[aurix_rate_limiter<br/>gen_server]

    HttpSup --> Cowboy[Cowboy Listener<br/>:8080]
```

### Supervision Strategy

| Supervisor | Strategy | Rationale |
|-----------|----------|-----------|
| `aurix_sup` | `one_for_one` | Independent children; crash in ETL must not restart HTTP |
| `aurix_http_sup` | `one_for_one` | Cowboy manages its own connection processes |

### Restart Intensity

- Max restarts: 5 in 60 seconds
- If exceeded, the supervisor itself crashes upward

## 4. Request Lifecycle

```mermaid
sequenceDiagram
    participant C as Client
    participant Cowboy as Cowboy Listener
    participant Router as aurix_router
    participant MW as Middleware Pipeline
    participant Handler as Handler Module
    participant Service as Service Module
    participant Repo as Repository
    participant DB as PostgreSQL

    C->>Cowboy: HTTP Request
    Cowboy->>Router: Match route
    Router->>MW: Apply middleware chain

    Note over MW: 1. Request ID generation<br/>2. CORS headers<br/>3. Rate limit check (Redis)<br/>4. JWT validation (if protected)<br/>5. Tenant context extraction

    MW->>Handler: Dispatch to handler
    Handler->>Handler: Parse & validate request body
    Handler->>Service: Call domain operation
    Service->>Repo: Execute DB queries
    Repo->>DB: SQL
    DB-->>Repo: Result
    Repo-->>Service: Domain data
    Service-->>Handler: Operation result
    Handler->>Handler: Build JSON response
    Handler-->>C: HTTP Response
```

## 5. Multi-Tenant Architecture

```mermaid
flowchart TB
    subgraph "Tenant A (aurix-demo)"
        UA1[User A1] --> WA1[Wallet A1]
        UA2[User A2] --> WA2[Wallet A2]
        WA1 --> TxA[Transactions A]
        WA2 --> TxA
    end

    subgraph "Tenant B (partner-co)"
        UB1[User B1] --> WB1[Wallet B1]
        WB1 --> TxB[Transactions B]
    end

    subgraph "Shared PostgreSQL"
        Users[(users table<br/>tenant_id column)]
        Wallets[(wallets table<br/>tenant_id column)]
        Txns[(transactions table<br/>tenant_id column)]
    end

    UA1 & UA2 & UB1 -.-> Users
    WA1 & WA2 & WB1 -.-> Wallets
    TxA & TxB -.-> Txns

    style Users fill:#e1f5fe
    style Wallets fill:#e1f5fe
    style Txns fill:#e1f5fe
```

### Isolation Rules

1. Every tenant-scoped table has a `tenant_id` column
2. Every query includes `WHERE tenant_id = $tenant_id`
3. JWT claims carry `tenant_id` — no request parameter override
4. Composite indexes start with `tenant_id`
5. No cross-tenant joins in application code

### Future Evolution Path

```mermaid
flowchart LR
    V1[Phase 1<br/>Shared Schema<br/>tenant_id column] --> V2[Phase 2<br/>Row-Level Security<br/>PG policies] --> V3[Phase 3<br/>Schema per Tenant<br/>Dynamic routing]

    style V1 fill:#c8e6c9
    style V2 fill:#fff9c4
    style V3 fill:#ffccbc
```

## 6. Concurrency Model

### Erlang/OTP Process Model

```mermaid
flowchart TB
    subgraph "BEAM VM"
        subgraph "Cowboy Acceptor Pool"
            A1[Acceptor 1]
            A2[Acceptor 2]
            AN[Acceptor N]
        end

        subgraph "Request Handlers (one per connection)"
            H1[Handler Process 1]
            H2[Handler Process 2]
            HN[Handler Process N]
        end

        subgraph "Long-Running Processes"
            PP[Price Provider<br/>gen_server]
            OD[Outbox Dispatcher<br/>gen_server]
            ES[ETL Scheduler<br/>gen_server]
            RL[Rate Limiter<br/>gen_server]
        end

        subgraph "Connection Pools"
            DBP[DB Pool<br/>pgapp workers]
            RP[Redis Pool<br/>eredis workers]
        end
    end

    A1 --> H1
    A2 --> H2
    AN --> HN
    H1 & H2 & HN --> DBP
    H1 & H2 & HN --> RP
    OD --> DBP
    ES --> DBP
    RL --> RP
```

### Database Concurrency

- Wallet writes use `SELECT ... FOR UPDATE` row-level locks
- Each wallet operation is a single PostgreSQL transaction
- No long-held locks — transactions are designed to be fast
- Idempotency keys prevent duplicate execution on retry

## 7. Caching Strategy

```mermaid
flowchart LR
    subgraph "Write Path (no cache)"
        BuySell[Buy/Sell] --> DB_W[(PostgreSQL)]
    end

    subgraph "Read Path (cached)"
        Price[Price Provider] --> RedisC[(Redis Cache)]
        RedisC -.->|miss| PriceSrc[Price Source]
        PriceSrc -.->|fill| RedisC

        Insights[Insights Read] --> RedisI[(Redis Cache)]
        RedisI -.->|miss| DB_R[(PostgreSQL)]
        DB_R -.->|fill| RedisI
    end

    subgraph "Rate Limiting"
        RateCheck[Rate Limiter] --> RedisRL[(Redis Counters)]
    end
```

### Cache Rules

| Data | Cached? | TTL | Invalidation |
|------|---------|-----|-------------|
| Gold price | Yes | 60s | TTL expiry |
| Wallet balance | **No** | — | Always read from DB on writes |
| Insights | Yes | 5 min | TTL or ETL run |
| Rate limit counters | Yes | Window-based | Sliding window expiry |
| JWT | **No** | — | Stateless verification |

## 8. Error Handling Strategy

### Layer-Specific Error Handling

```mermaid
flowchart TD
    Handler[Handler Layer] -->|pattern match| ServiceErr{Service Error?}
    ServiceErr -->|insufficient_balance| R422[422 + error JSON]
    ServiceErr -->|not_found| R404[404 + error JSON]
    ServiceErr -->|duplicate_key| R409[409 + error JSON]
    ServiceErr -->|validation_error| R400[400 + error JSON]
    ServiceErr -->|unexpected| R500[500 + generic message]

    Service[Service Layer] -->|{error, Reason}| Handler
    Service -->|exception| Crash[Crash → Supervisor restart]

    Repo[Repository Layer] -->|DB error| Service
    Repo -->|constraint violation| Service
```

### Standard Error Response Format

```json
{
    "error": {
        "code": "insufficient_balance",
        "message": "Not enough EUR balance to complete this purchase",
        "details": {
            "required_eur_cents": 8125,
            "available_eur_cents": 5000
        }
    }
}
```

## 9. Scaling Architecture (Millions of Users)

```mermaid
flowchart TB
    subgraph "Edge"
        CDN[CDN / Static Assets]
        LB[Load Balancer<br/>Health Check + Routing]
    end

    subgraph "API Tier (Stateless, Horizontal)"
        API1[Cowboy Node 1]
        API2[Cowboy Node 2]
        APIN[Cowboy Node N]
    end

    subgraph "Data Tier"
        PGW[(PG Primary<br/>Writes)]
        PGR1[(PG Replica 1<br/>Reads)]
        PGR2[(PG Replica 2<br/>Reads)]
        Redis1[(Redis Cluster)]
    end

    subgraph "Async Tier"
        Kafka[(Kafka Cluster)]
        ETL1[ETL Worker 1]
        ETL2[ETL Worker 2]
        Notify[Notification Service]
        Analytics[Analytics Consumer]
    end

    CDN --> LB
    LB --> API1 & API2 & APIN
    API1 & API2 & APIN -->|writes| PGW
    API1 & API2 & APIN -->|reads| PGR1 & PGR2
    API1 & API2 & APIN --> Redis1
    API1 & API2 & APIN -->|outbox| Kafka
    Kafka --> ETL1 & ETL2
    Kafka --> Notify
    Kafka --> Analytics
```

### Scaling Strategies by Tier

| Tier | Strategy | Trigger |
|------|----------|---------|
| API | Add more stateless nodes | CPU/connection saturation |
| DB Writes | Vertical scale primary, then shard by tenant | Write IOPS limit |
| DB Reads | Add replicas | Read query volume |
| Cache | Redis Cluster | Memory or connection limits |
| Async | Add Kafka partitions + consumers | Event lag |
| ETL | Parallel workers by tenant | Processing time exceeds window |

## 10. Docker Infrastructure

```mermaid
flowchart TB
    subgraph "docker-compose.yml"
        FE[react-frontend<br/>:3000<br/>Node 22 Alpine]
        API[aurix-api<br/>:8080<br/>Erlang/OTP 27]
        PG[postgres<br/>:5432<br/>PostgreSQL 16]
        Redis[redis<br/>:6379<br/>Redis 7]
        Swagger[swagger-ui<br/>:8081<br/>Optional]
    end

    FE -->|API calls| API
    API --> PG
    API --> Redis
    Swagger -.->|reads| API

    subgraph "Volumes"
        PGData[pg_data]
        RedisData[redis_data]
    end

    PG --> PGData
    Redis --> RedisData
```

### Container Overview

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `aurix-api` | Custom Erlang/OTP release | 8080 | Backend API |
| `react-frontend` | Custom Node.js | 3000 | React SPA |
| `postgres` | postgres:16-alpine | 5432 | Primary database |
| `redis` | redis:7-alpine | 6379 | Cache + rate limiting |
| `swagger-ui` | swaggerapi/swagger-ui | 8081 | API documentation |

## 11. Network & Security Boundaries

```mermaid
flowchart TB
    subgraph "Public Network"
        Browser[Browser :3000]
    end

    subgraph "Internal Docker Network"
        subgraph "DMZ"
            FE[React Frontend]
            API[Cowboy API]
        end

        subgraph "Private"
            PG[(PostgreSQL)]
            Redis[(Redis)]
        end
    end

    Browser -->|HTTPS| FE
    FE -->|HTTP| API
    API -->|TCP :5432| PG
    API -->|TCP :6379| Redis

    style PG fill:#ffcdd2
    style Redis fill:#ffcdd2
```

- PostgreSQL and Redis are **not** exposed to the host by default
- Only the frontend (3000) and API (8080) are accessible externally
- In production: TLS termination at load balancer, internal traffic is plain TCP within the private network
