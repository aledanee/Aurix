-- 005_create_insight_snapshots.sql
-- Pre-computed trading insights from ETL aggregation.

CREATE TABLE IF NOT EXISTS insight_snapshots (
    id           uuid        PRIMARY KEY,
    tenant_id    uuid        NOT NULL REFERENCES tenants(id),
    user_id      uuid        NOT NULL REFERENCES users(id),
    frequency    varchar(16) NOT NULL CHECK (frequency IN ('daily', 'weekly')),
    period_start date        NOT NULL,
    period_end   date        NOT NULL,
    summary      jsonb       NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, user_id, frequency, period_start, period_end)
);

CREATE INDEX IF NOT EXISTS idx_insights_tenant_user_period
    ON insight_snapshots (tenant_id, user_id, frequency, period_end DESC);
