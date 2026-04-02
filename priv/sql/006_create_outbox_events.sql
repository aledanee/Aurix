-- 006_create_outbox_events.sql
-- Transactional outbox for reliable event publishing.

CREATE TABLE IF NOT EXISTS outbox_events (
    id             bigserial   PRIMARY KEY,
    tenant_id      uuid        NOT NULL,
    aggregate_type varchar(64) NOT NULL,
    aggregate_id   uuid        NOT NULL,
    event_type     varchar(64) NOT NULL,
    payload        jsonb       NOT NULL,
    published_at   timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outbox_unpublished
    ON outbox_events (published_at) WHERE published_at IS NULL;
