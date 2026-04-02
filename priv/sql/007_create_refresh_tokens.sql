-- 007_create_refresh_tokens.sql
-- Hashed refresh tokens for session management.

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id         uuid        PRIMARY KEY,
    tenant_id  uuid        NOT NULL REFERENCES tenants(id),
    user_id    uuid        NOT NULL REFERENCES users(id),
    token_hash text        NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user
    ON refresh_tokens (tenant_id, user_id) WHERE revoked_at IS NULL;
