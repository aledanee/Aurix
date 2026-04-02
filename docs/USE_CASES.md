# Aurix — Use Cases

## Use Case Diagram

```mermaid
graph TB
    subgraph Actors
        V[👤 Visitor]
        U[👤 User]
        A[👤 Admin]
        S[⚙️ System]
    end

    subgraph "Authentication"
        UC1[UC-1: Register]
        UC2[UC-2: Login]
        UC3[UC-3: Refresh Token]
        UC4[UC-4: Logout]
        UC21[UC-21: Change Password]
    end

    subgraph "Wallet Operations"
        UC5[UC-5: View Wallet]
        UC6[UC-6: Buy Gold]
        UC7[UC-7: Sell Gold]
        UC8[UC-8: View Transactions]
    end

    subgraph "AI Insights"
        UC9[UC-9: View Insights]
    end

    subgraph "Admin Operations"
        UC10[UC-10: Seed Tenant]
        UC11[UC-11: Configure Fees]
        UC12[UC-12: Update Price]
        UC13[UC-13: Trigger ETL]
        UC14[UC-14: View Health]
        UC15[UC-15: Deactivate Tenant]
    end

    subgraph "System Automations"
        UC16[UC-16: Run ETL]
        UC17[UC-17: Dispatch Outbox]
        UC18[UC-18: Reconcile Balances]
    end

    subgraph "Privacy"
        UC19[UC-19: Export Data]
        UC20[UC-20: Request Erasure]
    end

    V --> UC1
    V --> UC2
    U --> UC3
    U --> UC4
    U --> UC21
    U --> UC5
    U --> UC6
    U --> UC7
    U --> UC8
    U --> UC9
    U --> UC19
    U --> UC20
    A --> UC10
    A --> UC11
    A --> UC12
    A --> UC13
    A --> UC14
    A --> UC15
    S --> UC16
    S --> UC17
    S --> UC18
```

---

## UC-1: Register

| Field | Detail |
|-------|--------|
| **Actor** | Visitor |
| **Precondition** | Tenant exists and is active |
| **Trigger** | Visitor submits registration form |
| **Description** | Create a new user account and wallet under a tenant |

### Main Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Cowboy API
    participant AS as Auth Service
    participant TR as Tenant Repo
    participant UR as User Repo
    participant WR as Wallet Repo
    participant DB as PostgreSQL

    C->>API: POST /auth/register {tenant_code, email, password}
    API->>AS: register(tenant_code, email, password)
    AS->>TR: get_by_code(tenant_code)
    TR->>DB: SELECT * FROM tenants WHERE code = $1
    DB-->>TR: tenant record
    TR-->>AS: {ok, Tenant}
    AS->>UR: check_email_unique(tenant_id, email)
    UR->>DB: SELECT id FROM users WHERE tenant_id=$1 AND email=$2
    DB-->>UR: empty
    UR-->>AS: ok
    AS->>AS: hash_password(password)
    AS->>DB: BEGIN
    AS->>UR: insert_user(tenant_id, email, hash)
    UR->>DB: INSERT INTO users ...
    AS->>WR: create_wallet(tenant_id, user_id, seed_balance)
    WR->>DB: INSERT INTO wallets ...
    AS->>DB: COMMIT
    AS-->>API: {ok, UserId}
    API-->>C: 201 {user_id, email}
```

### Alternative Flows
- **A1**: Tenant not found → 400 `invalid_tenant`
- **A2**: Email already exists → 409 `email_taken`
- **A3**: Password validation fails → 400 `invalid_password`
- **A4**: Tenant is inactive → 403 `tenant_inactive`

---

## UC-2: Login

| Field | Detail |
|-------|--------|
| **Actor** | Visitor |
| **Precondition** | User exists, is active, and tenant is active |
| **Trigger** | User submits login credentials |

### Main Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Cowboy API
    participant AS as Auth Service
    participant TR as Tenant Repo
    participant UR as User Repo
    participant RT as Refresh Token Repo
    participant DB as PostgreSQL

    C->>API: POST /auth/login {tenant_code, email, password}
    API->>AS: login(tenant_code, email, password)
    AS->>TR: get_by_code(tenant_code)
    TR-->>AS: {ok, Tenant}
    AS->>UR: get_by_email(tenant_id, email)
    UR->>DB: SELECT * FROM users WHERE tenant_id=$1 AND email=$2 AND deleted_at IS NULL
    DB-->>UR: user record
    UR-->>AS: {ok, User}
    AS->>AS: verify_password(password, User.password_hash)
    AS->>AS: generate_access_token(User)
    AS->>AS: generate_refresh_token()
    AS->>RT: store_refresh_token(tenant_id, user_id, token_hash, expires_at)
    RT->>DB: INSERT INTO refresh_tokens ...
    AS-->>API: {ok, AccessToken, RefreshToken}
    API-->>C: 200 {access_token, refresh_token, expires_in}
```

### Alternative Flows
- **A1**: Tenant not found → 400 `invalid_tenant`
- **A2**: User not found → 401 `invalid_credentials`
- **A3**: Wrong password → 401 `invalid_credentials`
- **A4**: User soft-deleted → 403 `account_disabled`
- **A5**: Tenant inactive → 403 `tenant_inactive`

---

## UC-3: Refresh Token

| Field | Detail |
|-------|--------|
| **Actor** | User |
| **Precondition** | User has a valid refresh token |
| **Trigger** | Access token expired or near expiry |

### Main Flow

1. Client sends `POST /auth/refresh` with `refresh_token`
2. Server hashes the token and looks up the record
3. Validates: not expired, not revoked, user still active
4. Issues new access token
5. Optionally rotates refresh token (revoke old, issue new)
6. Returns new tokens

### Alternative Flows
- **A1**: Refresh token expired → 401 `token_expired`
- **A2**: Refresh token revoked → 401 `token_revoked`
- **A3**: User deleted/inactive → 403 `account_disabled`

---

## UC-4: Logout

| Field | Detail |
|-------|--------|
| **Actor** | User |
| **Precondition** | User is authenticated with a valid refresh token |
| **Trigger** | User chooses to log out |

### Main Flow

1. Client sends `POST /auth/logout` with `refresh_token`
2. Server revokes the refresh token (sets `revoked_at`)
3. Returns 204 No Content

---

## UC-21: Change Password

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | JWT is valid and user is logged in |
| **Trigger** | User wants to change their password |

### Main Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Cowboy API
    participant AS as Auth Service
    participant UR as User Repo
    participant RT as Refresh Token Repo
    participant DB as PostgreSQL

    C->>API: POST /auth/change-password {current_password, new_password} + Bearer JWT
    API->>AS: change_password(tenant_id, user_id, current_password, new_password)
    AS->>UR: get_by_id(tenant_id, user_id)
    UR->>DB: SELECT * FROM users WHERE tenant_id=$1 AND id=$2
    DB-->>UR: user record
    UR-->>AS: {ok, User}
    AS->>AS: verify_password(current_password, User.password_hash)
    AS->>AS: validate_new_password(new_password)
    AS->>AS: hash_password(new_password)
    AS->>DB: BEGIN
    AS->>UR: update_password(tenant_id, user_id, new_hash)
    UR->>DB: UPDATE users SET password_hash=$1 WHERE tenant_id=$2 AND id=$3
    AS->>RT: revoke_all_for_user(tenant_id, user_id)
    RT->>DB: UPDATE refresh_tokens SET revoked_at=now() WHERE tenant_id=$1 AND user_id=$2 AND revoked_at IS NULL
    AS->>DB: COMMIT
    AS-->>API: ok
    API-->>C: 204 No Content
```

### Alternative Flows
- **A1**: Current password wrong → 401 `invalid_credentials`
- **A2**: New password fails validation → 400 `invalid_password`
- **A3**: New password same as current → 400 `invalid_password`
- **A4**: JWT invalid or expired → 401 `unauthorized`

---

## UC-5: View Wallet

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | JWT is valid and not expired |
| **Trigger** | User navigates to wallet view |

### Main Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Cowboy API
    participant MW as Auth Middleware
    participant WS as Wallet Service
    participant WR as Wallet Repo
    participant DB as PostgreSQL

    C->>API: GET /wallet (Bearer JWT)
    API->>MW: validate_jwt(Token)
    MW-->>API: {ok, Claims{sub, tenant_id}}
    API->>WS: get_wallet(tenant_id, user_id)
    WS->>WR: find_by_user(tenant_id, user_id)
    WR->>DB: SELECT * FROM wallets WHERE tenant_id=$1 AND user_id=$2
    DB-->>WR: wallet record
    WR-->>WS: {ok, Wallet}
    WS-->>API: {ok, WalletView}
    API-->>C: 200 {wallet_id, gold_balance_grams, fiat_balance_eur}
```

---

## UC-6: Buy Gold

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | Wallet exists, sufficient EUR balance |
| **Trigger** | User submits buy order |

### Main Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Cowboy API
    participant WS as Wallet Service
    participant PP as Price Provider
    participant WR as Wallet Repo
    participant TxR as Transaction Repo
    participant OB as Outbox Repo
    participant DB as PostgreSQL

    C->>API: POST /wallet/buy {grams} + Idempotency-Key
    API->>WS: buy_gold(tenant_id, user_id, grams, idempotency_key)
    WS->>DB: BEGIN
    WS->>WR: lock_wallet(tenant_id, user_id)
    WR->>DB: SELECT ... FOR UPDATE
    DB-->>WR: wallet (locked)
    WS->>PP: get_price(gold_eur)
    PP-->>WS: 65.00 EUR/gram
    WS->>WS: compute gross = round(grams * price * 100)
    WS->>WS: compute fee = max(min_fee, round(gross * rate))
    WS->>WS: compute total = gross + fee
    WS->>WS: validate fiat_balance >= total
    WS->>WR: update_balances(debit fiat, credit gold)
    WR->>DB: UPDATE wallets SET ...
    WS->>TxR: insert_transaction(type=buy, grams, gross, fee)
    TxR->>DB: INSERT INTO transactions ...
    WS->>OB: insert_event(wallet.buy.posted)
    OB->>DB: INSERT INTO outbox_events ...
    WS->>DB: COMMIT
    WS-->>API: {ok, Transaction}
    API-->>C: 200 {transaction details}
```

### Alternative Flows
- **A1**: Insufficient fiat balance → 422 `insufficient_balance`
- **A2**: Invalid grams (negative, zero, bad precision) → 400 `invalid_amount`
- **A3**: Duplicate idempotency key → 409 `duplicate_request`
- **A4**: Wallet not found → 404 `wallet_not_found`

---

## UC-7: Sell Gold

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | Wallet exists, sufficient gold balance |
| **Trigger** | User submits sell order |

### Main Flow

Mirrors UC-6 with reversed balances:
1. Lock wallet
2. Get price
3. Compute gross = round(grams * price * 100)
4. Compute fee = max(min_fee, round(gross * rate))
5. Compute net credit = gross - fee
6. Validate gold_balance >= grams
7. Update wallet: debit gold, credit fiat with net amount
8. Insert transaction record
9. Insert outbox event
10. Commit

### Alternative Flows
- **A1**: Insufficient gold → 422 `insufficient_gold`
- **A2**: Invalid grams → 400 `invalid_amount`
- **A3**: Duplicate idempotency key → 409 `duplicate_request`

---

## UC-8: View Transactions

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | JWT is valid |
| **Trigger** | User views transaction history |

### Main Flow

1. Client sends `GET /transactions?cursor=&limit=20`
2. Server queries transactions for (tenant_id, user_id) ordered by created_at DESC
3. Returns paginated list with `next_cursor`

---

## UC-9: View Insights

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | ETL has generated insight snapshots |
| **Trigger** | User checks insights page |

### Main Flow

```mermaid
sequenceDiagram
    participant C as Client
    participant API as Cowboy API
    participant IS as Insight Service
    participant IR as Insight Repo
    participant LLM as LLM Adapter (Mocked)
    participant DB as PostgreSQL

    C->>API: GET /insights?cursor=&limit=10
    API->>IS: get_insights(tenant_id, user_id, cursor, limit)
    IS->>IR: list_snapshots(tenant_id, user_id, cursor, limit)
    IR->>DB: SELECT * FROM insight_snapshots WHERE ...
    DB-->>IR: snapshot records
    IR-->>IS: snapshots
    IS->>LLM: format_insights(snapshot.summary)
    LLM-->>IS: natural language insights
    IS-->>API: {ok, InsightList}
    API-->>C: 200 {items, next_cursor}
```

---

## UC-10: Seed Tenant (Admin)

| Field | Detail |
|-------|--------|
| **Actor** | Admin |
| **Precondition** | Admin has DB access |
| **Trigger** | New organization onboards |

### Main Flow

1. Admin runs seed SQL or admin script
2. Inserts tenant with unique code and name
3. Optionally configures fee schedule

---

## UC-11: Configure Fees (Admin)

| Field | Detail |
|-------|--------|
| **Actor** | Admin |
| **Precondition** | Tenant exists |
| **Trigger** | Admin adjusts pricing for a tenant |

### Main Flow

1. Admin updates fee configuration for the tenant
2. New rates apply to subsequent transactions
3. Change is logged for audit

---

## UC-12: Update Gold Price (Admin)

| Field | Detail |
|-------|--------|
| **Actor** | Admin |
| **Precondition** | Price provider is in fixed mode |
| **Trigger** | Market price changes |

### Main Flow

1. Admin updates price in application config or via admin endpoint
2. Price provider returns new value on next read
3. Change is logged

---

## UC-13: Trigger ETL (Admin)

| Field | Detail |
|-------|--------|
| **Actor** | Admin |
| **Precondition** | None |
| **Trigger** | Admin wants fresh insights |

### Main Flow

1. Admin triggers ETL via endpoint or CLI
2. ETL job runs extract → transform → load cycle
3. Returns count of processed records

---

## UC-14: Health Check

| Field | Detail |
|-------|--------|
| **Actor** | Admin / Load Balancer |
| **Precondition** | None |
| **Trigger** | Periodic health probe |

### Main Flow

1. `GET /health` checks DB connection, Redis connection, app status
2. Returns 200 if all healthy
3. Returns 503 with details if any component is degraded

---

## UC-15: Deactivate Tenant (Admin)

| Field | Detail |
|-------|--------|
| **Actor** | Admin |
| **Precondition** | Tenant exists and is active |
| **Trigger** | Admin decides to suspend a tenant |

### Main Flow

1. Admin sets tenant status to `inactive`
2. All login attempts for that tenant fail
3. Existing sessions expire naturally

---

## UC-16: Run Scheduled ETL (System)

| Field | Detail |
|-------|--------|
| **Actor** | System (timer-based) |
| **Precondition** | Transactions exist since last watermark |
| **Trigger** | Timer fires (hourly/daily) |

### Main Flow

```mermaid
sequenceDiagram
    participant Sched as ETL Scheduler
    participant Job as ETL Job
    participant DB as PostgreSQL

    Sched->>Job: run_etl()
    Job->>DB: SELECT watermark FROM etl_metadata
    DB-->>Job: last_processed_at
    Job->>DB: SELECT transactions WHERE created_at > watermark
    DB-->>Job: batch of transactions
    Job->>Job: group by (tenant_id, user_id, period)
    Job->>Job: compute aggregates (counts, avg prices, signals)
    Job->>DB: UPSERT INTO insight_snapshots ...
    Job->>DB: UPDATE etl_metadata SET watermark = now()
    Job-->>Sched: {ok, processed_count}
```

---

## UC-17: Dispatch Outbox Events (System)

| Field | Detail |
|-------|--------|
| **Actor** | System (background process) |
| **Precondition** | Unpublished outbox events exist |
| **Trigger** | Polling interval |

### Main Flow

1. Dispatcher queries `outbox_events WHERE published_at IS NULL` (batch)
2. For each event, publishes to Kafka (or logs in demo mode)
3. Marks events as published
4. Retries on failure with backoff

---

## UC-18: Reconcile Wallet Balances (System)

| Field | Detail |
|-------|--------|
| **Actor** | System (scheduled job) |
| **Precondition** | None |
| **Trigger** | Daily schedule |

### Main Flow

1. For each wallet, compute expected balance from SUM of transactions
2. Compare to stored wallet balance
3. If mismatch detected, log alert (no auto-correction)
4. Admin reviews and resolves manually

---

## UC-19: Export Personal Data

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | JWT is valid |
| **Trigger** | User requests data export |

### Main Flow

1. Client sends `GET /privacy/export`
2. Server gathers user profile, wallet, transactions, insights
3. Returns JSON export or initiates async generation with download link

---

## UC-20: Request Account Erasure

| Field | Detail |
|-------|--------|
| **Actor** | User (authenticated) |
| **Precondition** | JWT is valid |
| **Trigger** | User requests account deletion |

### Main Flow

1. Client sends `POST /privacy/erasure-request`
2. Server disables account immediately (set `deleted_at`)
3. Queues erasure workflow for non-essential data
4. Retains legally required records
5. Returns 202 Accepted with confirmation
