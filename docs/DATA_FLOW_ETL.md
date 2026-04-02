# Aurix — Data Flow & ETL Pipeline

## 1. Overview

```mermaid
flowchart TB
    subgraph "Write Path (synchronous)"
        Client[Client] -->|POST /wallet/buy or /sell| API[Cowboy API]
        API --> Service[Wallet Service]
        Service -->|single DB transaction| DB[(PostgreSQL)]
        Service -->|writes in same txn| Outbox[outbox_events]
    end

    subgraph "Event Path (asynchronous)"
        Outbox -->|polls unpublished| Dispatcher[Outbox Dispatcher]
        Dispatcher -->|publish| Kafka[(Kafka / Log)]
        Dispatcher -->|mark published| Outbox
    end

    subgraph "ETL Path (scheduled)"
        Scheduler[ETL Scheduler] -->|triggers| Job[ETL Job]
        Job -->|extract| Transactions[(transactions)]
        Job -->|transform| Aggregator[Aggregate Engine]
        Aggregator -->|load| Insights[(insight_snapshots)]
    end

    subgraph "Read Path"
        Client2[Client] -->|GET /insights| API2[Cowboy API]
        API2 --> InsightSvc[Insight Service]
        InsightSvc --> LLM[Mocked LLM Formatter]
        InsightSvc --> Insights
    end
```

## 2. Transaction Write Flow (Detail)

Every buy or sell operation writes **three records** in a single PostgreSQL transaction:

```mermaid
sequenceDiagram
    participant WS as Wallet Service
    participant DB as PostgreSQL

    WS->>DB: BEGIN
    WS->>DB: SELECT * FROM wallets WHERE tenant_id=$1 AND user_id=$2 FOR UPDATE
    Note over DB: Row locked — prevents concurrent modification
    WS->>DB: UPDATE wallets SET gold_balance_grams=..., fiat_balance_eur_cents=..., version=version+1
    WS->>DB: INSERT INTO transactions (id, tenant_id, wallet_id, ...) VALUES (...)
    WS->>DB: INSERT INTO outbox_events (tenant_id, aggregate_type, aggregate_id, event_type, payload) VALUES (...)
    WS->>DB: COMMIT
    Note over DB: All three writes succeed or all roll back
```

### Atomicity Guarantee

```mermaid
flowchart LR
    Wallet[Wallet Update] --> Ledger[Transaction Insert] --> Outbox[Outbox Insert]

    style Wallet fill:#c8e6c9
    style Ledger fill:#c8e6c9
    style Outbox fill:#c8e6c9

    Wallet -.->|same DB transaction| Outbox
```

If any insert fails, the entire transaction rolls back. No partial state.

## 3. Outbox Event Dispatch

### Pattern: Transactional Outbox

The outbox pattern ensures events are never lost, even if the message broker is down.

```mermaid
stateDiagram-v2
    [*] --> Created: INSERT in same txn as wallet update
    Created --> Published: Dispatcher publishes to Kafka
    Published --> [*]: Done

    Created --> RetryPending: Kafka unavailable
    RetryPending --> Published: Next poll succeeds
```

### Dispatcher Process

```mermaid
sequenceDiagram
    participant Disp as Outbox Dispatcher (gen_server)
    participant DB as PostgreSQL
    participant Kafka as Kafka / Logger

    loop Every 5 seconds
        Disp->>DB: SELECT * FROM outbox_events WHERE published_at IS NULL ORDER BY id LIMIT 100
        DB-->>Disp: batch of events
        alt Batch is empty
            Disp->>Disp: sleep until next interval
        else Events found
            loop For each event
                Disp->>Kafka: publish(event)
                alt Success
                    Disp->>DB: UPDATE outbox_events SET published_at=now() WHERE id=$1
                else Failure
                    Disp->>Disp: log error, skip (retry next cycle)
                end
            end
        end
    end
```

### Event Payload Example

```json
{
    "event_type": "wallet.buy.posted",
    "tenant_id": "a0000000-0000-0000-0000-000000000001",
    "aggregate_type": "wallet",
    "aggregate_id": "770e8400-e29b-41d4-a716-446655440000",
    "payload": {
        "transaction_id": "880e8400-e29b-41d4-a716-446655440000",
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "type": "buy",
        "gold_grams": "1.25000000",
        "price_eur_per_gram": "65.00000000",
        "gross_eur_cents": 8125,
        "fee_eur_cents": 50,
        "timestamp": "2026-04-02T10:00:00Z"
    },
    "created_at": "2026-04-02T10:00:00Z"
}
```

## 4. ETL Pipeline

### Flow

```mermaid
flowchart LR
    subgraph "Extract"
        E1[Read watermark from etl_metadata]
        E2[Query transactions since watermark]
        E1 --> E2
    end

    subgraph "Transform"
        T1[Group by tenant_id, user_id, period]
        T2[Compute aggregates per group]
        T3[Generate behavioral signals]
        E2 --> T1 --> T2 --> T3
    end

    subgraph "Load"
        L1[UPSERT into insight_snapshots]
        L2[Update watermark in etl_metadata]
        T3 --> L1 --> L2
    end
```

### Extract Phase

```sql
-- Read watermark
SELECT last_processed_at FROM etl_metadata WHERE id = 'transaction_etl';

-- Extract transactions since watermark
SELECT
    tenant_id,
    user_id,
    wallet_id,
    type,
    gold_grams,
    price_eur_per_gram,
    gross_eur_cents,
    fee_eur_cents,
    created_at
FROM transactions
WHERE created_at > $watermark
  AND status = 'posted'
ORDER BY created_at ASC;
```

### Transform Phase

Group transactions by (tenant_id, user_id) and compute:

| Signal | Computation |
|--------|------------|
| `buy_count` | COUNT WHERE type = 'buy' |
| `sell_count` | COUNT WHERE type = 'sell' |
| `total_gold_bought_grams` | SUM(gold_grams) WHERE type = 'buy' |
| `total_gold_sold_grams` | SUM(gold_grams) WHERE type = 'sell' |
| `average_buy_price_eur_per_gram` | AVG(price_eur_per_gram) WHERE type = 'buy' |
| `average_sell_price_eur_per_gram` | AVG(price_eur_per_gram) WHERE type = 'sell' |
| `total_fees_eur_cents` | SUM(fee_eur_cents) |
| `buy_frequency_per_week` | buy_count / weeks_in_period |
| `sell_after_buy_ratio` | sell_count / buy_count |
| `reference_price_eur_per_gram` | Current price from price provider |

### Load Phase

```sql
-- Upsert insight snapshot
INSERT INTO insight_snapshots (id, tenant_id, user_id, frequency, period_start, period_end, summary)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (tenant_id, user_id, frequency, period_start, period_end)
DO UPDATE SET summary = $7, created_at = now();

-- Update watermark
UPDATE etl_metadata
SET last_processed_at = $new_watermark, updated_at = now()
WHERE id = 'transaction_etl';
```

### Scheduling

```mermaid
sequenceDiagram
    participant Sched as ETL Scheduler (gen_server)
    participant Job as ETL Job
    participant DB as PostgreSQL

    Note over Sched: Timer fires every 1 hour

    Sched->>Job: run_daily_etl()
    Job->>DB: Read watermark
    Job->>DB: Extract transactions
    Job->>Job: Transform (aggregate)
    Job->>DB: Upsert insight_snapshots
    Job->>DB: Update watermark
    Job-->>Sched: {ok, #{processed => 42}}

    Note over Sched: On Sundays or configurable schedule
    Sched->>Job: run_weekly_etl()
    Job->>DB: Extract last 7 days
    Job->>Job: Transform (weekly aggregates)
    Job->>DB: Upsert weekly snapshots
    Job-->>Sched: {ok, #{processed => 15}}
```

### Idempotency

- The `UPSERT` (INSERT ... ON CONFLICT DO UPDATE) ensures re-running the ETL for the same period is safe
- Watermarks prevent reprocessing old data in normal runs
- A manual trigger re-runs from the current watermark

## 5. AI Insight Generation

### Two-Step Architecture

```mermaid
flowchart LR
    subgraph "Step 1: Signal Extraction"
        Snapshot[insight_snapshots.summary] --> Signals[Structured Signals]
    end

    subgraph "Step 2: LLM Formatting"
        Signals --> Adapter[aurix_llm_adapter<br/>Mocked]
        Adapter --> NL[Natural Language Insights]
    end

    subgraph "Response"
        Signals --> Response[API Response]
        NL --> Response
    end
```

### Signal → Insight Mapping Rules

```mermaid
flowchart TD
    S1{buy_freq > 3/week?} -->|Yes| I1[You are buying frequently]
    S2{avg_buy > reference * 1.05?} -->|Yes| I2[Buying above average price]
    S3{sell_after_buy_ratio > 0.5?} -->|Yes| I3[Selling shortly after buying]
    S4{inactivity > 14 days?} -->|Yes| I4[Consider resuming regular purchases]
    S5{buy_freq < 1/week AND gold > 0?} -->|Yes| I5[Consider dollar-cost averaging]
```

### Mocked LLM Adapter

The adapter receives a structured signal map and returns formatted text:

```erlang
%% Input signals:
#{
    buy_frequency_per_week => 4,
    average_buy_price_eur_per_gram => <<"68.12">>,
    reference_price_eur_per_gram => <<"64.90">>,
    sell_after_buy_ratio => 0.25
}

%% Output insights (list of strings):
[
    <<"You are buying frequently at prices above your weekly reference average.">>,
    <<"Consider averaging your purchases across multiple days instead of clustering them.">>
]
```

In production, this adapter could call an external LLM API. The interface remains the same.

## 6. Data Flow Summary

```mermaid
flowchart TB
    subgraph "Real-Time"
        Buy[Buy Gold] --> WalletUpdate[Update Wallet]
        Sell[Sell Gold] --> WalletUpdate
        WalletUpdate --> TxInsert[Insert Transaction]
        TxInsert --> OutboxInsert[Insert Outbox Event]
    end

    subgraph "Near Real-Time (5s)"
        OutboxInsert --> Dispatch[Outbox Dispatcher]
        Dispatch --> EventLog[Kafka / Event Log]
    end

    subgraph "Batch (Hourly/Daily)"
        TxInsert --> ETL[ETL Job]
        ETL --> Snapshots[Insight Snapshots]
    end

    subgraph "On-Demand"
        Snapshots --> LLM[LLM Formatter]
        LLM --> InsightAPI[GET /insights]
    end

    style Buy fill:#e8f5e9
    style Sell fill:#e8f5e9
    style Dispatch fill:#fff3e0
    style ETL fill:#e3f2fd
    style InsightAPI fill:#f3e5f5
```

## 7. Reconciliation Job

A periodic job verifies that wallet balances match the transaction ledger:

```mermaid
sequenceDiagram
    participant Recon as Reconciliation Job
    participant DB as PostgreSQL
    participant Alert as Alert System

    Recon->>DB: SELECT wallet_id, SUM(CASE type WHEN 'buy' THEN gold_grams ELSE -gold_grams END) as expected_gold FROM transactions GROUP BY wallet_id
    Recon->>DB: SELECT id, gold_balance_grams FROM wallets
    Recon->>Recon: Compare expected vs actual for each wallet

    alt All match
        Recon->>Recon: Log success
    else Mismatch found
        Recon->>Alert: Log alert with wallet_id, expected, actual
        Note over Alert: Manual review required<br/>No automatic correction
    end
```
