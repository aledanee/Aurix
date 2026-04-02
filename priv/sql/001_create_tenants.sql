-- 001_create_tenants.sql
-- Platform organizations. Seeded via admin scripts.

CREATE TABLE IF NOT EXISTS tenants (
    id          uuid        PRIMARY KEY,
    code        varchar(64) NOT NULL UNIQUE,
    name        varchar(255) NOT NULL,
    status      varchar(32) NOT NULL DEFAULT 'active',
    created_at  timestamptz NOT NULL DEFAULT now()
);
