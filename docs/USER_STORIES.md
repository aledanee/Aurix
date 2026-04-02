# Aurix — User Stories

## Actors

| Actor | Description |
|-------|-------------|
| **Visitor** | Unauthenticated person browsing the platform |
| **User** | Registered, authenticated account holder |
| **Admin** | Platform operator with elevated privileges (seeded, not self-registered) |
| **System** | Automated background processes (ETL, outbox dispatcher, reconciliation) |

---

## Epic 1: Registration & Authentication

### US-1.1 — Register a new account
**As a** Visitor  
**I want to** register with my email and password under a specific tenant  
**So that** I can access the gold trading platform  

**Acceptance Criteria:**
- Visitor provides `tenant_code`, `email`, and `password`
- Email must be unique within the tenant
- Password must be >= 10 chars, with uppercase, lowercase, and digit
- A wallet is auto-created with a seeded EUR balance (10,000.00 EUR for demo)
- Returns 201 with user ID on success
- Returns 409 if email is already taken within the tenant
- Returns 400 if validation fails

---

### US-1.2 — Log in
**As a** User  
**I want to** log in with my email and password  
**So that** I receive a JWT to access protected endpoints  

**Acceptance Criteria:**
- User provides `tenant_code`, `email`, `password`
- On success, returns JWT access token (15 min) and refresh token (7 days)
- JWT contains `sub`, `tenant_id`, `email`, `exp`
- Returns 401 if credentials are invalid
- Returns 403 if user account is soft-deleted or inactive

---

### US-1.3 — Refresh access token
**As a** User  
**I want to** exchange a valid refresh token for a new access token  
**So that** I stay authenticated without re-entering credentials  

**Acceptance Criteria:**
- Client sends `refresh_token` to `POST /auth/refresh`
- Server validates the refresh token hash and expiry
- Returns new access token (and optionally rotated refresh token)
- Returns 401 if the refresh token is expired or revoked

---

### US-1.4 — Log out (revoke refresh token)
**As a** User  
**I want to** log out and revoke my refresh token  
**So that** no one can use my session after I leave  

**Acceptance Criteria:**
- Client sends `refresh_token` to `POST /auth/logout`
- Server marks the refresh token as revoked
- Subsequent refresh attempts with that token return 401

---

### US-1.5 — Change password
**As a** User  
**I want to** change my password while logged in  
**So that** I can keep my account secure  

**Acceptance Criteria:**
- `POST /auth/change-password` requires valid JWT
- User provides `current_password` and `new_password`
- Current password must be verified against stored hash
- New password must meet the same validation rules as registration
- New password must differ from current password
- On success, all existing refresh tokens for the user are revoked
- Returns 204 on success
- Returns 401 if current password is wrong
- Returns 400 if new password fails validation

---

## Epic 2: Wallet Management

### US-2.1 — View my wallet
**As a** User  
**I want to** see my current gold balance (grams) and fiat balance (EUR)  
**So that** I know my available funds before trading  

**Acceptance Criteria:**
- `GET /wallet` returns wallet details for the authenticated user
- Gold balance shown as decimal string (8 decimal places)
- EUR balance shown as decimal string (2 decimal places, derived from cents)
- Wallet is scoped to the user's tenant

---

### US-2.2 — Buy gold
**As a** User  
**I want to** buy a specified amount of gold in grams  
**So that** my gold balance increases and my EUR balance decreases  

**Acceptance Criteria:**
- `POST /wallet/buy` with `grams` (decimal string)
- System locks the wallet row, reads current gold price, computes cost + fee
- Validates sufficient fiat balance
- Atomically updates wallet (debit EUR, credit gold) and inserts ledger record
- Inserts outbox event in the same transaction
- Supports `Idempotency-Key` to prevent duplicate execution
- Returns 200 with transaction details on success
- Returns 422 if insufficient balance
- Returns 409 if idempotency key was already used

---

### US-2.3 — Sell gold
**As a** User  
**I want to** sell a specified amount of gold in grams  
**So that** my EUR balance increases and my gold balance decreases  

**Acceptance Criteria:**
- `POST /wallet/sell` with `grams` (decimal string)
- Validates sufficient gold balance
- Atomically updates wallet (debit gold, credit EUR minus fee) and inserts ledger record
- Inserts outbox event in the same transaction
- Supports `Idempotency-Key`
- Returns 200 with transaction details on success
- Returns 422 if insufficient gold
- Returns 409 if idempotency key was already used

---

### US-2.4 — View transaction history
**As a** User  
**I want to** see a paginated list of my past transactions  
**So that** I can track my trading activity  

**Acceptance Criteria:**
- `GET /transactions?cursor=&limit=` returns paginated results
- Each item shows type, grams, price, gross EUR, fee, timestamp
- Results are ordered by `created_at DESC`
- Cursor-based pagination (no offset)
- Results are tenant-scoped

---

## Epic 3: AI Insights

### US-3.1 — View AI-generated insights
**As a** User  
**I want to** see intelligent insights about my trading behavior  
**So that** I can make better buying and selling decisions  

**Acceptance Criteria:**
- `GET /insights?cursor=&limit=` returns paginated insight snapshots
- Each insight contains signals (metrics) and natural-language recommendations
- Insights are generated from ETL aggregates, not computed on request
- Insights are tenant-scoped and user-scoped
- Insights are advisory only — no automated decisions

---

## Epic 4: Admin Operations

### US-4.1 — Seed a new tenant
**As an** Admin  
**I want to** create a new tenant in the database  
**So that** a new organization can use the platform  

**Acceptance Criteria:**
- Admin inserts a tenant record via SQL seed script or admin tool
- Tenant has a unique `code` and `name`
- Tenant starts in `active` status
- No public API endpoint for tenant creation

---

### US-4.2 — View all tenants
**As an** Admin  
**I want to** list all tenants and their statuses  
**So that** I can monitor platform usage  

**Acceptance Criteria:**
- Admin-only endpoint or DB query
- Shows tenant code, name, status, creation date

---

### US-4.3 — Deactivate a tenant
**As an** Admin  
**I want to** deactivate a tenant  
**So that** all users under that tenant are blocked from using the platform  

**Acceptance Criteria:**
- Tenant status set to `inactive`
- Login attempts for that tenant return 403
- Existing JWTs continue to work until expiry (or add tenant status check middleware)

---

### US-4.4 — Configure fee schedule per tenant
**As an** Admin  
**I want to** set buy/sell fee rates and minimum fee for a tenant  
**So that** different tenants can have custom pricing  

**Acceptance Criteria:**
- Fee rate (e.g., 0.5%) and min fee (e.g., 50 cents) stored per tenant
- Changes take effect on the next transaction
- Default values used if no override exists

---

### US-4.5 — Update gold price
**As an** Admin  
**I want to** update the fixed gold price per gram  
**So that** transactions use the current market-representative price  

**Acceptance Criteria:**
- Price is updated via config or admin endpoint
- Price provider interface supports swap to live/cached provider
- Price change is logged for audit

---

### US-4.6 — Trigger ETL manually
**As an** Admin  
**I want to** trigger the ETL aggregation job on demand  
**So that** insights are refreshed without waiting for the next schedule  

**Acceptance Criteria:**
- Admin endpoint or CLI command triggers the ETL batch
- Job is idempotent (safe to re-run)
- Returns summary of processed records

---

### US-4.7 — View system health
**As an** Admin  
**I want to** check the health of the system components  
**So that** I can detect issues early  

**Acceptance Criteria:**
- `GET /health` returns status of: API, DB, Redis
- Returns 200 when all healthy, 503 when degraded

---

## Epic 5: Privacy & Account Management

### US-5.1 — Export my data
**As a** User  
**I want to** download all my personal data in a machine-readable format  
**So that** I can exercise my GDPR right of access  

**Acceptance Criteria:**
- `GET /privacy/export` generates a JSON export
- Includes profile, wallet, transactions, insights
- Export is scoped to the authenticated user
- Large exports are generated asynchronously with an expiring download link

---

### US-5.2 — Request account erasure
**As a** User  
**I want to** request deletion of my account and personal data  
**So that** I can exercise my GDPR right to erasure  

**Acceptance Criteria:**
- `POST /privacy/erasure-request` initiates the workflow
- Account is immediately disabled (no login, no trades)
- Non-essential data is erased after retention obligations expire
- Legally required records (transactions, audit logs) are retained but access-restricted

---

## Epic 6: System Automations

### US-6.1 — ETL aggregation runs on schedule
**As the** System  
**I want to** run daily and weekly aggregation of transaction data  
**So that** insight snapshots are fresh for users  

**Acceptance Criteria:**
- Scheduler triggers ETL at configured intervals
- ETL extracts from watermark, transforms into aggregates, upserts snapshots
- Idempotent on re-run
- Logs processed count and errors

---

### US-6.2 — Outbox events are dispatched
**As the** System  
**I want to** publish pending outbox events to a message broker  
**So that** downstream consumers receive transaction events  

**Acceptance Criteria:**
- Dispatcher polls `outbox_events` where `published_at IS NULL`
- Publishes to Kafka (or logs in demo mode)
- Marks rows as published on success
- Retries on failure without losing events

---

### US-6.3 — Reconciliation check
**As the** System  
**I want to** periodically verify wallet balances match the ledger  
**So that** any data inconsistency is detected early  

**Acceptance Criteria:**
- Recompute each wallet's expected balance from `transactions`
- Compare to the stored `wallets` balance
- Log or alert on any mismatch
- No automatic correction (manual review required)
