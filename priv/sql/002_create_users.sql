-- 002_create_users.sql
-- Registered accounts, scoped to a tenant.

CREATE TABLE IF NOT EXISTS users (
    id            uuid         PRIMARY KEY,
    tenant_id     uuid         NOT NULL REFERENCES tenants(id),
    email         varchar(255) NOT NULL,
    password_hash text         NOT NULL,
    status        varchar(32)  NOT NULL DEFAULT 'active',
    deleted_at    timestamptz,
    created_at    timestamptz  NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, email)
);

CREATE INDEX IF NOT EXISTS idx_users_tenant_email ON users (tenant_id, email);
