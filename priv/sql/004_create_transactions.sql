-- 004_create_transactions.sql
-- Immutable ledger of all buy/sell operations. Append-only.

CREATE TABLE IF NOT EXISTS transactions (
    id                  uuid          PRIMARY KEY,
    tenant_id           uuid          NOT NULL REFERENCES tenants(id),
    wallet_id           uuid          NOT NULL REFERENCES wallets(id),
    user_id             uuid          NOT NULL REFERENCES users(id),
    type                varchar(16)   NOT NULL CHECK (type IN ('buy', 'sell')),
    gold_grams          numeric(24,8) NOT NULL,
    price_eur_per_gram  numeric(24,8) NOT NULL,
    gross_eur_cents     bigint        NOT NULL,
    fee_eur_cents       bigint        NOT NULL DEFAULT 0,
    status              varchar(16)   NOT NULL DEFAULT 'posted',
    idempotency_key     varchar(128)  NOT NULL,
    metadata            jsonb,
    created_at          timestamptz   NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_transactions_tenant_wallet_time
    ON transactions (tenant_id, wallet_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_transactions_tenant_user_time
    ON transactions (tenant_id, user_id, created_at DESC);
