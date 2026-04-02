-- 003_create_wallets.sql
-- One wallet per user per tenant. Balance columns for fast reads.

CREATE TABLE IF NOT EXISTS wallets (
    id                     uuid          PRIMARY KEY,
    tenant_id              uuid          NOT NULL REFERENCES tenants(id),
    user_id                uuid          NOT NULL REFERENCES users(id),
    gold_balance_grams     numeric(24,8) NOT NULL DEFAULT 0,
    fiat_balance_eur_cents bigint        NOT NULL DEFAULT 0,
    version                bigint        NOT NULL DEFAULT 0,
    created_at             timestamptz   NOT NULL DEFAULT now(),
    updated_at             timestamptz   NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_wallets_tenant_user ON wallets (tenant_id, user_id);
