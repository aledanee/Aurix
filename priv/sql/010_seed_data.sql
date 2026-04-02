-- 010_seed_data.sql
-- Demo tenants, fee config, and ETL watermark.

-- Demo tenant
INSERT INTO tenants (id, code, name, status)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'aurix-demo',
    'Aurix Demo Tenant',
    'active'
) ON CONFLICT (id) DO NOTHING;

-- Second tenant for isolation testing
INSERT INTO tenants (id, code, name, status)
VALUES (
    'b0000000-0000-0000-0000-000000000002',
    'partner-co',
    'Partner Company',
    'active'
) ON CONFLICT (id) DO NOTHING;

-- Default fee config for demo tenant (0.5% rate, 0.50 EUR minimum)
INSERT INTO tenant_fee_config (id, tenant_id, buy_fee_rate, sell_fee_rate, min_fee_eur_cents)
VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    0.005000,
    0.005000,
    50
) ON CONFLICT (id) DO NOTHING;

-- ETL watermark
INSERT INTO etl_metadata (id, last_processed_at)
VALUES ('transaction_etl', '1970-01-01T00:00:00Z')
ON CONFLICT (id) DO NOTHING;
