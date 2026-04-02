-- 008_create_tenant_fee_config.sql
-- Per-tenant fee schedule for buy and sell operations.

CREATE TABLE IF NOT EXISTS tenant_fee_config (
    id                uuid          PRIMARY KEY,
    tenant_id         uuid          NOT NULL REFERENCES tenants(id) UNIQUE,
    buy_fee_rate      numeric(10,6) NOT NULL DEFAULT 0.005000,
    sell_fee_rate     numeric(10,6) NOT NULL DEFAULT 0.005000,
    min_fee_eur_cents bigint        NOT NULL DEFAULT 50,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tenant_fee_config_tenant ON tenant_fee_config (tenant_id);
