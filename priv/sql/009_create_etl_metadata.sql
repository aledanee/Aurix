-- 009_create_etl_metadata.sql
-- Watermark tracking for ETL jobs.

CREATE TABLE IF NOT EXISTS etl_metadata (
    id                 varchar(64) PRIMARY KEY,
    last_processed_at  timestamptz NOT NULL DEFAULT '1970-01-01T00:00:00Z',
    updated_at         timestamptz NOT NULL DEFAULT now()
);
